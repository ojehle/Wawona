#import "renderer_macos.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <IOSurface/IOSurface.h>
#import <QuartzCore/CAMetalLayer.h>
#include "WawonaCompositor.h"
#include "metal_dmabuf.h"
#include "logging.h"
#include <wayland-server-core.h>
#include <wayland-server-protocol.h>
#include <wayland-server.h>
#include <sys/socket.h>

// Forward declarations for external symbols
extern struct xdg_toplevel_impl *xdg_surface_get_toplevel_from_wl_surface(struct wl_surface_impl * wl_surface);
extern WawonaCompositor *g_wl_compositor_instance;

// Forward declaration for CompositorView (defined in WawonaCompositor.m)
@interface CompositorView : NSView
@property(nonatomic, strong) id<RenderingBackend> renderer;
@end

// --- DMA-BUF / IOSurface Helpers ---

static IOSurfaceRef create_iosurface_from_shm(void *data, int32_t width, int32_t height, int32_t stride, uint32_t format) {
    if (!data || width <= 0 || height <= 0) return NULL;
    
    // Align stride to 16 bytes for Metal compatibility
    uint32_t alignedStride = (stride + 15) & ~15;
    
    NSDictionary *properties = @{
        (NSString *)kIOSurfaceWidth: @(width),
        (NSString *)kIOSurfaceHeight: @(height),
        (NSString *)kIOSurfacePixelFormat: @(kCVPixelFormatType_32BGRA),
        (NSString *)kIOSurfaceBytesPerRow: @(alignedStride),
        (NSString *)kIOSurfaceAllocSize: @(alignedStride * height)
    };
    
    IOSurfaceRef iosurface = IOSurfaceCreate((__bridge CFDictionaryRef)properties);
    if (!iosurface) return NULL;
    
    if (IOSurfaceLock(iosurface, 0, NULL) != kIOReturnSuccess) {
        CFRelease(iosurface);
        return NULL;
    }
    
    void *surfaceBase = IOSurfaceGetBaseAddress(iosurface);
    size_t surfaceStride = IOSurfaceGetBytesPerRow(iosurface);
    
    uint8_t *src = (uint8_t *)data;
    uint8_t *dst = (uint8_t *)surfaceBase;
    uint32_t copyWidth = (stride < surfaceStride) ? stride : (uint32_t)surfaceStride;
    
    for (int32_t y = 0; y < height; y++) {
        memcpy(dst, src, copyWidth);
        src += stride;
        dst += surfaceStride;
    }
    
    IOSurfaceUnlock(iosurface, 0, NULL);
    return iosurface;
}

// --- CompositorMTKView ---

@interface NSWindow (Private)
- (void)performWindowResizeWithEdge:(NSInteger)edge event:(NSEvent *)event;
@end

@interface CompositorMTKView : MTKView
@end

@implementation CompositorMTKView
{
    NSTrackingArea *_trackingArea;
    NSInteger _resizeEdge;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
    }
    
    NSTrackingAreaOptions options = NSTrackingActiveAlways |
                                    NSTrackingMouseEnteredAndExited |
                                    NSTrackingMouseMoved |
                                    NSTrackingInVisibleRect;
                                    
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                 options:options
                                                   owner:self
                                                userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)mouseDownCanMoveWindow {
    if (_resizeEdge > 0) return NO;
    return YES;
}

- (NSView *)hitTest:(NSPoint)point {
    NSPoint localPoint = [self convertPoint:point fromView:self.superview];
    WawonaCompositor *compositor = (WawonaCompositor *)g_wl_compositor_instance;
    
    if (compositor && compositor.inputHandler) {
        struct wl_surface_impl *surface = [compositor.inputHandler pickSurfaceAt:localPoint];
        if (!surface) return nil;
        
        struct xdg_toplevel_impl *toplevel = xdg_surface_get_toplevel_from_wl_surface(surface);
        if (toplevel && toplevel->decoration_mode == 1) { // Client Side
             if (toplevel->xdg_surface->has_geometry) {
                 CGRect geo = CGRectMake(toplevel->xdg_surface->geometry_x,
                                         toplevel->xdg_surface->geometry_y,
                                         toplevel->xdg_surface->geometry_width,
                                         toplevel->xdg_surface->geometry_height);
                 
                 float resizeMargin = 8.0;
                 CGRect resizeRect = CGRectInset(geo, -resizeMargin, -resizeMargin);
                 if (CGRectContainsPoint(resizeRect, localPoint)) {
                     return self;
                 } else {
                     return nil;
                 }
             }
        }
    }
    return [super hitTest:point];
}

- (BOOL)acceptsMouseMovedEvents { return YES; }

- (void)mouseMoved:(NSEvent *)event {
    WawonaCompositor *compositor = (WawonaCompositor *)g_wl_compositor_instance;
    NSPoint localPoint = [self convertPoint:event.locationInWindow fromView:nil];
    _resizeEdge = -1;
    [[NSCursor arrowCursor] set];
    
    if (compositor && compositor.inputHandler) {
        struct wl_surface_impl *surface = [compositor.inputHandler pickSurfaceAt:localPoint];
        if (surface) {
            struct xdg_toplevel_impl *toplevel = xdg_surface_get_toplevel_from_wl_surface(surface);
            if (toplevel && toplevel->decoration_mode == 1 && toplevel->xdg_surface->has_geometry) {
                 CGRect geo = CGRectMake(toplevel->xdg_surface->geometry_x,
                                         toplevel->xdg_surface->geometry_y,
                                         toplevel->xdg_surface->geometry_width,
                                         toplevel->xdg_surface->geometry_height);
                 
                 float margin = 8.0; 
                 BOOL left = (localPoint.x >= geo.origin.x - margin && localPoint.x <= geo.origin.x + margin);
                 BOOL right = (localPoint.x >= geo.origin.x + geo.size.width - margin && localPoint.x <= geo.origin.x + geo.size.width + margin);
                 BOOL top = (localPoint.y >= geo.origin.y - margin && localPoint.y <= geo.origin.y + margin);
                 BOOL bottom = (localPoint.y >= geo.origin.y + geo.size.height - margin && localPoint.y <= geo.origin.y + geo.size.height + margin);
                 
                 if (left) _resizeEdge = 1;
                 else if (right) _resizeEdge = 2;
                 
                 if (top) _resizeEdge = (_resizeEdge == -1) ? 8 : (_resizeEdge | 8);
                 else if (bottom) _resizeEdge = (_resizeEdge == -1) ? 4 : (_resizeEdge | 4);
                 
                 if (_resizeEdge != -1) {
                     if (_resizeEdge == 1 || _resizeEdge == 2) [[NSCursor resizeLeftRightCursor] set];
                     else if (_resizeEdge == 4 || _resizeEdge == 8) [[NSCursor resizeUpDownCursor] set];
                     else [[NSCursor arrowCursor] set]; 
                 }
            }
        }
        [compositor.inputHandler handleMouseEvent:event];
    }
}

- (void)mouseDown:(NSEvent *)event {
    if (_resizeEdge >= 0) {
        [self.window performWindowResizeWithEdge:_resizeEdge event:event];
        return;
    }
    WawonaCompositor *compositor = (WawonaCompositor *)g_wl_compositor_instance;
    if (compositor && compositor.inputHandler) {
        [compositor.inputHandler handleMouseEvent:event];
    }
}

- (void)mouseUp:(NSEvent *)event {
    WawonaCompositor *compositor = (WawonaCompositor *)g_wl_compositor_instance;
    if (compositor && compositor.inputHandler) {
        [compositor.inputHandler handleMouseEvent:event];
    }
}

- (void)mouseDragged:(NSEvent *)event {
    WawonaCompositor *compositor = (WawonaCompositor *)g_wl_compositor_instance;
    if (compositor && compositor.inputHandler) {
        [compositor.inputHandler handleMouseEvent:event];
    }
}
@end

// --- WawonaShadowLayer ---

@interface WawonaShadowLayer : CALayer
@end

@implementation WawonaShadowLayer
- (CALayer *)hitTest:(CGPoint)p {
    return nil; // Pass through
}
@end

// --- SurfaceState ---

@interface SurfaceState : NSObject
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) CALayer *windowLayer;
@property (nonatomic, strong) WawonaShadowLayer *shadowLayer;
@property (nonatomic, assign) struct wl_surface_impl *surface;
@end

@implementation SurfaceState
@end

// --- WawonaRendererMacOS ---

@interface WawonaRendererMacOS () <CALayerDelegate>
@property (nonatomic, weak) NSView *compositorView;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, SurfaceState *> *surfaces;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@end

@implementation WawonaRendererMacOS

- (instancetype)initWithView:(NSView *)view {
    self = [super init];
    if (self) {
        _compositorView = view;
        _surfaces = [NSMutableDictionary dictionary];
        [self setupMetal];
    }
    return self;
}

- (void)setupMetal {
    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        NSLog(@"❌ Failed to create Metal device");
        return;
    }
    _commandQueue = [_device newCommandQueue];
    
    // Shader source
    NSString *shaderSource = @
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "struct VertexIn {\n"
    "    float2 position [[attribute(0)]];\n"
    "    float2 texCoord [[attribute(1)]];\n"
    "};\n"
    "struct VertexOut {\n"
    "    float4 position [[position]];\n"
    "    float2 texCoord;\n"
    "};\n"
    "vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {\n"
    "    const float2 positions[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };\n"
    "    const float2 texCoords[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };\n"
    "    VertexOut out;\n"
    "    out.position = float4(positions[vertexID], 0.0, 1.0);\n"
    "    out.texCoord = texCoords[vertexID];\n"
    "    return out;\n"
    "}\n"
    "fragment float4 fragmentShader(VertexOut in [[stage_in]], texture2d<float> texture [[texture(0)]]) {\n"
    "    constexpr sampler s(mag_filter::linear, min_filter::linear);\n"
    "    return texture.sample(s, in.texCoord);\n"
    "}\n";

    NSError *error = nil;
    id<MTLLibrary> library = [_device newLibraryWithSource:shaderSource options:nil error:&error];
    if (!library) {
        NSLog(@"❌ Failed to compile shaders: %@", error);
        return;
    }
    
    MTLRenderPipelineDescriptor *pDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pDesc.vertexFunction = [library newFunctionWithName:@"vertexShader"];
    pDesc.fragmentFunction = [library newFunctionWithName:@"fragmentShader"];
    pDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pDesc.colorAttachments[0].blendingEnabled = YES;
    pDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    pDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    pDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pDesc error:&error];
    if (!_pipelineState) NSLog(@"❌ Failed to create pipeline state: %@", error);
    
    // Ensure parent view is layer-backed
    if (!_compositorView.layer) {
        _compositorView.wantsLayer = YES;
    }
}

- (void)renderSurface:(struct wl_surface_impl *)surface {
    if (!surface || !surface->resource) return;
    
    // Check buffer
    if (!surface->buffer_resource) return;

    NSNumber *key = @((uintptr_t)surface);
    SurfaceState *state = _surfaces[key];
    if (!state) {
        state = [[SurfaceState alloc] init];
        state.surface = surface;
        _surfaces[key] = state;
    }

    // 1. Get/Create Buffer as IOSurface
    IOSurfaceRef iosurface = NULL;
    struct wl_shm_buffer *shm_buffer = wl_shm_buffer_get(surface->buffer_resource);
    int32_t width = 0, height = 0;

    if (shm_buffer) {
        wl_shm_buffer_begin_access(shm_buffer);
        void *data = wl_shm_buffer_get_data(shm_buffer);
        width = wl_shm_buffer_get_width(shm_buffer);
        height = wl_shm_buffer_get_height(shm_buffer);
        int32_t stride = wl_shm_buffer_get_stride(shm_buffer);
        uint32_t format = wl_shm_buffer_get_format(shm_buffer);
        
        iosurface = metal_dmabuf_create_iosurface_from_data(data, width, height, stride, format);
        wl_shm_buffer_end_access(shm_buffer);
    }

    if (!iosurface) return;

    // 2. Ensure Layers
    struct xdg_toplevel_impl *toplevel = xdg_surface_get_toplevel_from_wl_surface(surface);
    [self ensureLayersForState:state toplevel:toplevel];

    // 3. Render to CAMetalLayer
    if (state.metalLayer) {
        state.metalLayer.drawableSize = CGSizeMake(width, height);
        id<CAMetalDrawable> drawable = [state.metalLayer nextDrawable];
        if (drawable) {
            MTLTextureDescriptor *texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
            id<MTLTexture> texture = [_device newTextureWithDescriptor:texDesc iosurface:iosurface plane:0];
            
            if (texture) {
                id<MTLCommandBuffer> cmd = [_commandQueue commandBuffer];
                MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
                pass.colorAttachments[0].texture = drawable.texture;
                pass.colorAttachments[0].loadAction = MTLLoadActionClear;
                pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
                pass.colorAttachments[0].storeAction = MTLStoreActionStore;
                
                id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];
                [enc setRenderPipelineState:_pipelineState];
                [enc setFragmentTexture:texture atIndex:0];
                [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
                [enc endEncoding];
                [cmd presentDrawable:drawable];
                [cmd commit];
            }
        }
    }
    
    CFRelease(iosurface);

    // 4. Update Window Geometry (SSD/CSD)
    [self updateWindowGeometryForState:state toplevel:toplevel width:width height:height];
}

- (void)ensureLayersForState:(SurfaceState *)state toplevel:(struct xdg_toplevel_impl *)toplevel {
    if (!state.windowLayer) {
        state.windowLayer = [CALayer layer];
        state.windowLayer.name = [NSString stringWithFormat:@"WindowLayer-%p", state.surface];
        state.windowLayer.masksToBounds = NO;
        state.windowLayer.backgroundColor = [NSColor clearColor].CGColor;
        
        if (state.surface->parent == NULL) {
             [_compositorView.layer addSublayer:state.windowLayer];
        } else {
             NSNumber *parentKey = @((uintptr_t)state.surface->parent);
             SurfaceState *parentState = _surfaces[parentKey];
             if (parentState && parentState.windowLayer) {
                 [parentState.windowLayer addSublayer:state.windowLayer];
             } else {
                 [_compositorView.layer addSublayer:state.windowLayer];
             }
        }
    }

    if (!state.metalLayer) {
        state.metalLayer = [CAMetalLayer layer];
        state.metalLayer.device = _device;
        state.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        state.metalLayer.framebufferOnly = YES;
        state.metalLayer.opaque = NO;
        state.metalLayer.allowsNextDrawableTimeout = NO;
        [state.windowLayer addSublayer:state.metalLayer];
    }
    
    if (state.surface->parent == NULL && toplevel && toplevel->decoration_mode == 1) { // CSD
        if (!state.shadowLayer) {
            state.shadowLayer = [WawonaShadowLayer layer];
            state.shadowLayer.shadowOpacity = 0.5;
            state.shadowLayer.shadowRadius = 20;
            state.shadowLayer.shadowOffset = CGSizeZero;
            state.shadowLayer.masksToBounds = NO;
            [_compositorView.layer insertSublayer:state.shadowLayer below:state.windowLayer];
        }
    } else {
        if (state.shadowLayer) {
            [state.shadowLayer removeFromSuperlayer];
            state.shadowLayer = nil;
        }
    }
}

- (void)updateWindowGeometryForState:(SurfaceState *)state toplevel:(struct xdg_toplevel_impl *)toplevel width:(int32_t)width height:(int32_t)height {
    if (!toplevel || !toplevel->native_window) {
        state.windowLayer.frame = CGRectMake(0, 0, width, height);
        state.metalLayer.frame = state.windowLayer.bounds;
        return;
    }
    
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    int32_t gx = 0, gy = 0, gw = width, gh = height;
    if (toplevel->xdg_surface && toplevel->xdg_surface->has_geometry) {
        gx = toplevel->xdg_surface->geometry_x;
        gy = toplevel->xdg_surface->geometry_y;
        gw = toplevel->xdg_surface->geometry_width;
        gh = toplevel->xdg_surface->geometry_height;
    }
    
    // Set the layer bounds to the full surface size
    state.windowLayer.bounds = CGRectMake(0, 0, width, height);
    
    // For SSD (server-side decorations), offset the layer position to align content with window
    // The geometry offset (gx, gy) tells us where the "real" content starts within the surface
    // We need to shift the layer by -gx, -gy so the content area aligns with (0,0) of the window
    BOOL isSSD = (toplevel->decoration_mode == 2); // 2 = SERVER_SIDE
    
    if (isSSD && (gx != 0 || gy != 0)) {
        // For SSD: position layer so that geometry area starts at (0,0)
        // Layer anchor point is at (0,0), so position directly offsets
        state.windowLayer.anchorPoint = CGPointMake(0, 0);
        state.windowLayer.position = CGPointMake(-gx, -gy);
    } else {
        // For CSD or no geometry offset: position at origin
        state.windowLayer.anchorPoint = CGPointMake(0, 0);
        state.windowLayer.position = CGPointMake(0, 0);
    }
    
    state.metalLayer.frame = state.windowLayer.bounds;
    
    if (state.shadowLayer) {
        // CSD mode - update window frame to match geometry size on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if (g_wl_compositor_instance.isLiveResizing) return;
            NSRect currentFrame = window.frame;
            if (window.contentView.frame.size.width != gw || window.contentView.frame.size.height != gh) {
                NSRect contentRect = NSMakeRect(0, 0, gw, gh);
                NSRect newFrame = [window frameRectForContentRect:contentRect];
                newFrame.origin = currentFrame.origin;
                newFrame.origin.y -= (newFrame.size.height - currentFrame.size.height);
                [window setFrame:newFrame display:YES animate:NO];
            }
        });
    }
}

- (void)removeSurface:(struct wl_surface_impl *)surface {
    NSNumber *key = @((uintptr_t)surface);
    SurfaceState *state = _surfaces[key];
    if (state) {
        [state.metalLayer removeFromSuperlayer];
        [state.windowLayer removeFromSuperlayer];
        [state.shadowLayer removeFromSuperlayer];
        [_surfaces removeObjectForKey:key];
    }
}

- (void)setNeedsDisplay {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_compositorView setNeedsDisplay:YES];
    });
}

- (void)drawSurfacesInRect:(NSRect)dirtyRect {
    // No-op for layer-based rendering
}

@end
