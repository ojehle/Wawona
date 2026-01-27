#import "renderer_apple.h"
#import "../logging/WawonaLog.h"
#include "../logging/logging.h"
#import "../platform/macos/WawonaCompositor.h"
#import "../platform/macos/WawonaSurfaceManager.h"
#include "../platform/macos/metal_dmabuf.h"
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <IOSurface/IOSurfaceRef.h>
#else
#import <IOSurface/IOSurface.h>
#endif
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>
#include <wayland-server-protocol.h>
#include <wayland-server.h>

@interface WawonaRendererApple ()
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@end

@implementation WawonaRendererApple

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
- (instancetype)initWithView:(UIView *)view {
#else
- (instancetype)initWithView:(NSView *)view {
#endif
  self = [super init];
  if (self) {
    [self setupMetal];
  }
  return self;
}

- (void)setupMetal {
  _device = [[WawonaSurfaceManager sharedManager] metalDevice];
  if (!_device) {
    WLog(@"RENDERER", @"Error: Failed to get shared Metal device");
    return;
  }
  _commandQueue = [_device newCommandQueue];

  // Simple texture pass-through shader with alpha blending support
  NSString *shaderSource =
      @
      "#include <metal_stdlib>\n"
       "using namespace metal;\n"
       "struct VertexOut {\n"
       "    float4 position [[position]];\n"
       "    float2 texCoord;\n"
       "};\n"
       "vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {\n"
       "    const float2 positions[4] = { float2(-1, -1), float2(1, -1), "
       "float2(-1, 1), float2(1, 1) };\n"
       "    const float2 texCoords[4] = { float2(0, 1), float2(1, 1), "
       "float2(0, 0), float2(1, 0) };\n"
       "    VertexOut out;\n"
       "    out.position = float4(positions[vertexID], 0.0, 1.0);\n"
       "    out.texCoord = texCoords[vertexID];\n"
       "    return out;\n"
       "}\n"
       "fragment float4 fragmentShader(VertexOut in [[stage_in]], "
       "texture2d<float> texture [[texture(0)]]) {\n"
       "    constexpr sampler s(mag_filter::linear, min_filter::linear);\n"
       "    return texture.sample(s, in.texCoord);\n"
       "}\n";

  NSError *error = nil;
  id<MTLLibrary> library =
      [_device newLibraryWithSource:shaderSource options:nil error:&error];
  if (!library) {
    WLog(@"RENDERER", @"Error: Failed to compile shaders: %@", error);
    return;
  }

  MTLRenderPipelineDescriptor *pDesc =
      [[MTLRenderPipelineDescriptor alloc] init];
  pDesc.vertexFunction = [library newFunctionWithName:@"vertexShader"];
  pDesc.fragmentFunction = [library newFunctionWithName:@"fragmentShader"];
  pDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  pDesc.colorAttachments[0].blendingEnabled = YES;
  pDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
  pDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
  pDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
  pDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
  pDesc.colorAttachments[0].destinationRGBBlendFactor =
      MTLBlendFactorOneMinusSourceAlpha;
  pDesc.colorAttachments[0].destinationAlphaBlendFactor =
      MTLBlendFactorOneMinusSourceAlpha;

  _pipelineState =
      [_device newRenderPipelineStateWithDescriptor:pDesc error:&error];
  if (!_pipelineState)
    WLog(@"RENDERER", @"Error: Failed to create pipeline state: %@", error);
}

- (void)renderSurface:(struct wl_surface_impl *)surface {
  log_printf("RENDERER", "renderSurface called for surface=%p\n", surface);
  if (!surface) {
    log_printf("RENDERER", "Error: surface is NULL\n");
    return;
  }
  if (!surface->buffer_resource) {
    log_printf("RENDERER", "Error: surface %p has no buffer_resource\n",
               surface);
    return;
  }

  log_printf("RENDERER", "surface=%p buffer_resource=%p\n", surface,
             surface->buffer_resource);

  // Retrieve the layer specifically for this surface
  WawonaSurfaceLayer *surfaceLayer =
      [[WawonaSurfaceManager sharedManager] layerForSurface:surface];
  log_printf("RENDERER", "surfaceLayer=%p\n", surfaceLayer);
  if (!surfaceLayer) {
    log_printf("RENDERER", "Error: no surfaceLayer for surface %p\n", surface);
    return;
  }
  if (!surfaceLayer.contentLayer) {
    log_printf("RENDERER", "Error: surfaceLayer.contentLayer is nil\n");
    return;
  }

  CAMetalLayer *metalLayer = surfaceLayer.contentLayer;
  log_printf("RENDERER", "metalLayer=%p\n", metalLayer);

  // 1. Convert Buffer to IOSurface
  IOSurfaceRef iosurface = NULL;
  struct wl_shm_buffer *shm_buffer =
      wl_shm_buffer_get(surface->buffer_resource);
  int32_t width = 0, height = 0;

  log_printf("RENDERER", "shm_buffer=%p\n", shm_buffer);

  if (shm_buffer) {
    wl_shm_buffer_begin_access(shm_buffer);
    void *data = wl_shm_buffer_get_data(shm_buffer);
    width = wl_shm_buffer_get_width(shm_buffer);
    height = wl_shm_buffer_get_height(shm_buffer);
    int32_t stride = wl_shm_buffer_get_stride(shm_buffer);
    uint32_t format = wl_shm_buffer_get_format(shm_buffer);

    log_printf("RENDERER",
               "SHM buffer: data=%p, %dx%d, stride=%d, format=0x%x\n", data,
               width, height, stride, format);

    // Create IOSurface from SHM data (zero-copy if possible, or copy)
    iosurface = metal_dmabuf_create_iosurface_from_data(data, width, height,
                                                        stride, format);

    wl_shm_buffer_end_access(shm_buffer);
    log_printf("RENDERER", "Created iosurface=%p from SHM\n", iosurface);
  } else {
    log_printf("RENDERER",
               "Warning: buffer is not SHM (may be dmabuf or unsupported)\n");
  }
  /*else if (is_dmabuf_buffer(surface->buffer_resource)) {
    struct metal_dmabuf_buffer *dmabuf =
        dmabuf_buffer_get(surface->buffer_resource);
    if (dmabuf) {
      iosurface = dmabuf->iosurface;
      if (iosurface)
        CFRetain(iosurface);
      width = dmabuf->width;
      height = dmabuf->height;
    }
  }*/

  if (!iosurface) {
    log_printf("RENDERER", "Error: could not create IOSurface for surface %p\n",
               surface);
    return;
  }

  // 2. Render to CAMetalLayer
  // IMPORTANT: Ensure drawable size matches buffer size exactly
  metalLayer.drawableSize = CGSizeMake(width, height);
  log_printf("RENDERER", "Set metalLayer.drawableSize to %dx%d\n", width,
             height);

  id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
  log_printf("RENDERER", "drawable=%p\n", drawable);
  if (drawable) {
    MTLTextureDescriptor *texDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                     width:width
                                    height:height
                                 mipmapped:NO];
    id<MTLTexture> sourceTexture =
        [_device newTextureWithDescriptor:texDesc iosurface:iosurface plane:0];
    log_printf("RENDERER", "sourceTexture=%p\n", sourceTexture);

    if (sourceTexture) {
      id<MTLCommandBuffer> cmd = [_commandQueue commandBuffer];
      MTLRenderPassDescriptor *pass =
          [MTLRenderPassDescriptor renderPassDescriptor];
      pass.colorAttachments[0].texture = drawable.texture;
      pass.colorAttachments[0].loadAction = MTLLoadActionClear;
      pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
      pass.colorAttachments[0].storeAction = MTLStoreActionStore;

      id<MTLRenderCommandEncoder> enc =
          [cmd renderCommandEncoderWithDescriptor:pass];
      [enc setRenderPipelineState:_pipelineState];
      [enc setFragmentTexture:sourceTexture atIndex:0];
      [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip
              vertexStart:0
              vertexCount:4];
      [enc endEncoding];
      [cmd presentDrawable:drawable];
      [cmd commit];
      log_printf("RENDERER",
                 "Success: rendered surface %p (%dx%d) to drawable\n", surface,
                 width, height);
    } else {
      log_printf("RENDERER",
                 "Error: could not create Metal texture from IOSurface\n");
    }
  } else {
    log_printf("RENDERER", "Error: no drawable available from metalLayer\n");
  }

  // Clean up
  if (iosurface) {
    CFRelease(iosurface);
  }
}

- (void)removeSurface:(struct wl_surface_impl *)surface {
  // Managed entirely by WawonaSurfaceManager lifecycle
}

- (void)setNeedsDisplay {
  // Handled by layer updates
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
- (void)drawSurfacesInRect:(NSRect)dirtyRect {
  // No-op - we are layer based
}
#endif

@end
