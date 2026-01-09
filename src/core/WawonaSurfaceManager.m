// WawonaSurfaceManager.m - CALayer-based Wayland Surface Management Implementation

#import "WawonaSurfaceManager.h"
#import "RenderingBackend.h"
#import "metal_dmabuf.h"
#import "../logging/WawonaLog.h"
#import "../compositor_implementations/xdg_shell.h"
#import "../compositor_implementations/wayland_compositor.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>

// Constants for CSD resize detection
static const CGFloat kResizeEdgeInset = 8.0; // pixels from edge
static const CGFloat kResizeCornerSize = 20.0; // corner region size

//==============================================================================
// MARK: - WawonaSurfaceLayer Implementation
//==============================================================================

@implementation WawonaSurfaceLayer

- (instancetype)initWithSurface:(struct wl_surface_impl *)surface {
    self = [super init];
    if (self) {
        _surface = surface;
        _isMapped = NO;
        _needsDisplay = YES;
        _subsurfaceLayers = [NSMutableArray array];
        
        // Create root layer (container for everything)
        _rootLayer = [CALayer layer];
        _rootLayer.masksToBounds = NO; // Allow shadow to extend beyond bounds
        _rootLayer.anchorPoint = CGPointMake(0, 0);
        
        // Create content layer (GPU-accelerated Metal layer)
        _contentLayer = [CAMetalLayer layer];
        _contentLayer.device = MTLCreateSystemDefaultDevice();
        _contentLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        _contentLayer.framebufferOnly = NO; // Allow reading for waypipe/screenshots
        _contentLayer.presentsWithTransaction = NO; // Manual presentation
        _contentLayer.anchorPoint = CGPointMake(0, 0);
        
        [_rootLayer addSublayer:_contentLayer];
        
        WLog(@"SURFACE", @"Created surface layer for surface %p", surface);
    }
    return self;
}

- (void)updateContentWithSize:(CGSize)size {
    self.contentLayer.bounds = CGRectMake(0, 0, size.width, size.height);
    self.contentLayer.drawableSize = size;
    self.rootLayer.bounds = CGRectMake(0, 0, size.width, size.height);
    self.needsDisplay = YES;
}

- (void)addSubsurfaceLayer:(CALayer *)sublayer atIndex:(NSInteger)index {
    [self.subsurfaceLayers insertObject:sublayer atIndex:index];
    [self.rootLayer addSublayer:sublayer];
    WLog(@"SURFACE", @"Added subsurface layer at index %ld", (long)index);
}

- (void)removeSubsurfaceLayer:(CALayer *)sublayer {
    [self.subsurfaceLayers removeObject:sublayer];
    [sublayer removeFromSuperlayer];
    WLog(@"SURFACE", @"Removed subsurface layer");
}

- (void)setNeedsRedisplay {
    self.needsDisplay = YES;
    [self.contentLayer setNeedsDisplay];
}

- (void)dealloc {
    WLog(@"SURFACE", @"Deallocating surface layer for surface %p", _surface);
}

@end

//==============================================================================
// MARK: - WawonaWindowContainer Implementation
//==============================================================================

@interface WawonaWindowContainer () <NSWindowDelegate>
@property (nonatomic, strong) NSView *contentView;
@end

@implementation WawonaWindowContainer

- (instancetype)initWithToplevel:(struct xdg_toplevel_impl *)toplevel
                  decorationMode:(WawonaDecorationMode)mode
                            size:(CGSize)size {
    self = [super init];
    if (self) {
        _toplevel = toplevel;
        _decorationMode = mode;
        _isResizing = NO;
        
        [self createWindowWithSize:size];
    }
    return self;
}

- (void)createWindowWithSize:(CGSize)size {
    NSRect contentRect = NSMakeRect(100, 100, size.width, size.height);
    NSWindowStyleMask styleMask;
    
    if (self.decorationMode == WawonaDecorationModeCSD) {
        // CSD: Borderless window (no macOS chrome)
        styleMask = NSWindowStyleMaskBorderless |
                    NSWindowStyleMaskResizable |
                    NSWindowStyleMaskMiniaturizable |
                    NSWindowStyleMaskClosable;
        
        WLog(@"WINDOW", @"Creating CSD (borderless) window for toplevel %p", _toplevel);
    } else {
        // SSD: Standard macOS window with chrome
        styleMask = NSWindowStyleMaskTitled |
                    NSWindowStyleMaskClosable |
                    NSWindowStyleMaskMiniaturizable |
                    NSWindowStyleMaskResizable;
        
        WLog(@"WINDOW", @"Creating SSD (titled) window for toplevel %p", _toplevel);
    }
    
    self.window = [[NSWindow alloc] initWithContentRect:contentRect
                                               styleMask:styleMask
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
    
    self.window.delegate = self;
    self.window.acceptsMouseMovedEvents = YES;
    self.window.releasedWhenClosed = NO;
    
    if (self.decorationMode == WawonaDecorationModeCSD) {
        // CSD-specific window setup
        self.window.backgroundColor = [NSColor clearColor];
        self.window.opaque = NO;
        self.window.hasShadow = NO; // We'll draw our own shadow layer
        self.window.movableByWindowBackground = NO; // Client handles move
    } else {
        // SSD-specific window setup
        self.window.backgroundColor = [NSColor windowBackgroundColor];
        self.window.opaque = YES;
        self.window.hasShadow = YES; // Native macOS shadow
    }
    
    // Create content view (layer-backed)
    NSRect viewFrame = [self.window contentRectForFrameRect:self.window.frame];
    self.contentView = [[NSView alloc] initWithFrame:viewFrame];
    self.contentView.wantsLayer = YES;
    self.contentView.layer.masksToBounds = NO; // Allow shadow overflow for CSD
    
    self.window.contentView = self.contentView;
    
    // Store window reference in toplevel
    _toplevel->native_window = (__bridge void *)self.window;
}

- (void)setSurfaceLayer:(WawonaSurfaceLayer *)surfaceLayer {
    _surfaceLayer = surfaceLayer;
    
    if (surfaceLayer) {
        // Add surface's root layer to window's content view
        [self.contentView.layer addSublayer:surfaceLayer.rootLayer];
        
        // For CSD, add shadow layer if needed
        if (self.decorationMode == WawonaDecorationModeCSD && !surfaceLayer.shadowLayer) {
            [self setupCSDShadowLayer];
        }
    }
}

- (void)setupCSDShadowLayer {
    if (!self.surfaceLayer) return;
    
    // Create shadow layer (click-through, below content)
    CALayer *shadowLayer = [CALayer layer];
    shadowLayer.backgroundColor = [[NSColor clearColor] CGColor];
    shadowLayer.shadowOpacity = 0.5;
    shadowLayer.shadowRadius = 20.0;
    shadowLayer.shadowOffset = CGSizeMake(0, -5);
    shadowLayer.shadowColor = [[NSColor blackColor] CGColor];
    shadowLayer.masksToBounds = NO;
    
    // CRITICAL: Make shadow click-through
    // In AppKit, we achieve this by ensuring the layer doesn't participate in hit testing
    shadowLayer.hidden = NO; // Visible but non-interactive
    
    // Insert shadow layer below content layer
    [self.surfaceLayer.rootLayer insertSublayer:shadowLayer atIndex:0];
    self.surfaceLayer.shadowLayer = shadowLayer;
    
    // Update shadow path to match content bounds
    CGRect contentBounds = self.surfaceLayer.contentLayer.bounds;
    shadowLayer.bounds = contentBounds;
    shadowLayer.position = CGPointMake(CGRectGetMidX(contentBounds), CGRectGetMidY(contentBounds));
    shadowLayer.shadowPath = [NSBezierPath bezierPathWithRect:contentBounds].CGPath;
    
    WLog(@"WINDOW", @"Created CSD shadow layer for window %p", (__bridge void *)self.window);
}

- (void)show {
    [self.window makeKeyAndOrderFront:nil];
    WLog(@"WINDOW", @"Showed window %p", (__bridge void *)self.window);
}

- (void)hide {
    [self.window orderOut:nil];
    WLog(@"WINDOW", @"Hid window %p", (__bridge void *)self.window);
}

- (void)close {
    WLog(@"WINDOW", @"Closing window %p", (__bridge void *)self.window);
    
    // Send close event to Wayland client
    if (self.toplevel && self.toplevel->resource) {
        extern void xdg_toplevel_send_close(struct wl_resource *resource);
        xdg_toplevel_send_close(self.toplevel->resource);
    }
}

- (void)minimize {
    WLog(@"WINDOW", @"Minimizing window %p (macOS API)", (__bridge void *)self.window);
    [self.window miniaturize:nil];
    
    // Notify Wayland client of minimized state
    // This would typically be done through xdg_toplevel.configure with minimized state
}

- (void)maximize {
    WLog(@"WINDOW", @"Maximizing window %p (macOS zoom API)", (__bridge void *)self.window);
    [self.window zoom:nil];
    
    // Notify Wayland client of maximized state
    // This would be done through xdg_toplevel.configure with maximized state
}

- (void)updateDecorationMode:(WawonaDecorationMode)mode {
    if (self.decorationMode == mode) return;
    
    WLog(@"WINDOW", @"Updating decoration mode from %d to %d", (int)self.decorationMode, (int)mode);
    
    // Save current content rect to maintain size
    NSRect contentRect = [self.window contentRectForFrameRect:self.window.frame];
    
    self.decorationMode = mode;
    
    // Recreate window with new style
    NSWindow *oldWindow = self.window;
    [self createWindowWithSize:contentRect.size];
    
    // Transfer surface layer to new window
    if (self.surfaceLayer) {
        [self.surfaceLayer.rootLayer removeFromSuperlayer];
        [self.contentView.layer addSublayer:self.surfaceLayer.rootLayer];
        
        if (mode == WawonaDecorationModeCSD) {
            [self setupCSDShadowLayer];
        } else {
            // Remove shadow layer for SSD
            if (self.surfaceLayer.shadowLayer) {
                [self.surfaceLayer.shadowLayer removeFromSuperlayer];
                self.surfaceLayer.shadowLayer = nil;
            }
        }
    }
    
    // Show new window and close old one
    [self.window setFrame:[oldWindow frame] display:YES];
    [self show];
    [oldWindow close];
}

- (void)setTitle:(NSString *)title {
    self.window.title = title ?: @"Wawona Client";
}

- (void)resize:(CGSize)newSize {
    NSRect currentFrame = self.window.frame;
    NSRect newContentRect = NSMakeRect(currentFrame.origin.x,
                                       currentFrame.origin.y,
                                       newSize.width,
                                       newSize.height);
    NSRect newFrame = [self.window frameRectForContentRect:newContentRect];
    
    [self.window setFrame:newFrame display:YES animate:NO];
    
    // Update surface layer
    if (self.surfaceLayer) {
        [self.surfaceLayer updateContentWithSize:newSize];
        
        // Update shadow layer bounds for CSD
        if (self.decorationMode == WawonaDecorationModeCSD && self.surfaceLayer.shadowLayer) {
            CGRect contentBounds = self.surfaceLayer.contentLayer.bounds;
            self.surfaceLayer.shadowLayer.bounds = contentBounds;
            self.surfaceLayer.shadowLayer.shadowPath = [NSBezierPath bezierPathWithRect:contentBounds].CGPath;
        }
    }
}

//==============================================================================
// MARK: - CSD Resize Detection and Handling
//==============================================================================

- (NSRectEdge)detectResizeEdgeAtPoint:(CGPoint)point {
    if (self.decorationMode != WawonaDecorationModeCSD) {
        return (NSRectEdge)-1; // Not CSD, no custom resize
    }
    
    NSRect bounds = self.contentView.bounds;
    BOOL nearLeft = point.x < kResizeEdgeInset;
    BOOL nearRight = point.x > bounds.size.width - kResizeEdgeInset;
    BOOL nearTop = point.y > bounds.size.height - kResizeEdgeInset;
    BOOL nearBottom = point.y < kResizeEdgeInset;
    
    // Check corners first (priority over edges)
    if (nearLeft && nearBottom) return NSMinXEdge; // Bottom-left
    if (nearRight && nearBottom) return NSMaxXEdge; // Bottom-right
    if (nearLeft && nearTop) return NSMinXEdge; // Top-left
    if (nearRight && nearTop) return NSMaxXEdge; // Top-right
    
    // Check edges
    if (nearLeft) return NSMinXEdge;
    if (nearRight) return NSMaxXEdge;
    if (nearTop) return NSMaxYEdge;
    if (nearBottom) return NSMinYEdge;
    
    return (NSRectEdge)-1; // Not near any edge
}

- (void)beginResizeWithEdge:(NSRectEdge)edge atPoint:(CGPoint)point {
    self.isResizing = YES;
    self.resizeEdge = edge;
    self.resizeStartPoint = [self.window convertPointToScreen:point];
    self.resizeStartFrame = self.window.frame;
    
    WLog(@"WINDOW", @"Begin CSD resize: edge=%ld", (long)edge);
}

- (void)continueResizeToPoint:(CGPoint)screenPoint {
    if (!self.isResizing) return;
    
    CGFloat deltaX = screenPoint.x - self.resizeStartPoint.x;
    CGFloat deltaY = screenPoint.y - self.resizeStartPoint.y;
    
    NSRect newFrame = self.resizeStartFrame;
    
    // Apply deltas based on resize edge
    switch (self.resizeEdge) {
        case NSMinXEdge: // Left edge
            newFrame.origin.x += deltaX;
            newFrame.size.width -= deltaX;
            break;
        case NSMaxXEdge: // Right edge
            newFrame.size.width += deltaX;
            break;
        case NSMinYEdge: // Bottom edge
            newFrame.origin.y += deltaY;
            newFrame.size.height -= deltaY;
            break;
        case NSMaxYEdge: // Top edge
            newFrame.size.height += deltaY;
            break;
    }
    
    // Enforce minimum size
    if (newFrame.size.width < 100) newFrame.size.width = 100;
    if (newFrame.size.height < 100) newFrame.size.height = 100;
    
    [self.window setFrame:newFrame display:YES animate:NO];
    
    // Send configure event to Wayland client (CSD: full frame size)
    if (self.toplevel && self.toplevel->resource && self.toplevel->xdg_surface) {
        extern void xdg_toplevel_send_configure(struct wl_resource *resource,
                                               int32_t width, int32_t height,
                                               struct wl_array *states);
        extern void xdg_surface_send_configure(struct wl_resource *resource, uint32_t serial);
        
        struct wl_array states;
        wl_array_init(&states);
        
        // Add resizing state
        uint32_t *state = wl_array_add(&states, sizeof(uint32_t));
        if (state) {
            *state = 8; // XDG_TOPLEVEL_STATE_RESIZING
        }
        // Add activated state
        state = wl_array_add(&states, sizeof(uint32_t));
        if (state) {
            *state = 4; // XDG_TOPLEVEL_STATE_ACTIVATED
        }
        
        // For CSD, send full window size (client draws decorations)
        NSRect contentRect = [self.window contentRectForFrameRect:newFrame];
        xdg_toplevel_send_configure(self.toplevel->resource,
                                   (int32_t)contentRect.size.width,
                                   (int32_t)contentRect.size.height,
                                   &states);
        
        uint32_t serial = ++self.toplevel->xdg_surface->configure_serial;
        xdg_surface_send_configure(self.toplevel->xdg_surface->resource, serial);
        
        self.toplevel->width = (int32_t)contentRect.size.width;
        self.toplevel->height = (int32_t)contentRect.size.height;
        
        wl_array_release(&states);
    }
}

- (void)endResize {
    self.isResizing = NO;
    WLog(@"WINDOW", @"End CSD resize");
}

//==============================================================================
// MARK: - NSWindowDelegate Methods
//==============================================================================

- (void)windowDidResize:(NSNotification *)notification {
    if (self.isResizing) return; // Already handling in continueResizeToPoint
    
    // Window resized by user (SSD) or programmatically
    NSRect contentRect = [self.window contentRectForFrameRect:self.window.frame];
    
    WLog(@"WINDOW", @"Window resized to %.0fx%.0f (mode=%d)", 
         contentRect.size.width, contentRect.size.height, (int)self.decorationMode);
    
    // Send configure to Wayland client
    if (self.toplevel && self.toplevel->resource && self.toplevel->xdg_surface) {
        extern void xdg_toplevel_send_configure(struct wl_resource *resource,
                                               int32_t width, int32_t height,
                                               struct wl_array *states);
        extern void xdg_surface_send_configure(struct wl_resource *resource, uint32_t serial);
        
        // Build states array (activated, resizing if applicable)
        struct wl_array states;
        wl_array_init(&states);
        
        // Add activated state (window is active)
        uint32_t *state = wl_array_add(&states, sizeof(uint32_t));
        if (state) {
            *state = 4; // XDG_TOPLEVEL_STATE_ACTIVATED
        }
        
        // For SSD: Send content rect size (client should NOT render decorations)
        // For CSD: Send full window size (client renders everything)
        int32_t configureWidth = (int32_t)contentRect.size.width;
        int32_t configureHeight = (int32_t)contentRect.size.height;
        
        // Send xdg_toplevel.configure with new size
        xdg_toplevel_send_configure(self.toplevel->resource,
                                   configureWidth,
                                   configureHeight,
                                   &states);
        
        // CRITICAL: Must send xdg_surface.configure to complete the transaction
        uint32_t serial = ++self.toplevel->xdg_surface->configure_serial;
        xdg_surface_send_configure(self.toplevel->xdg_surface->resource, serial);
        
        // Update toplevel size tracking
        self.toplevel->width = configureWidth;
        self.toplevel->height = configureHeight;
        
        wl_array_release(&states);
        
        WLog(@"WINDOW", @"Sent configure: %dx%d serial=%u", configureWidth, configureHeight, serial);
    }
    
    // Update surface layer
    if (self.surfaceLayer) {
        [self.surfaceLayer updateContentWithSize:contentRect.size];
    }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [self close];
    return NO; // We handle close via Wayland protocol
}

- (void)windowDidMiniaturize:(NSNotification *)notification {
    WLog(@"WINDOW", @"Window miniaturized");
    // Could send minimized state to client here
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
    WLog(@"WINDOW", @"Window deminiaturized");
    // Could remove minimized state from client here
}

- (void)dealloc {
    WLog(@"WINDOW", @"Deallocating window container for toplevel %p", _toplevel);
    if (_window) {
        [_window close];
    }
}

@end

//==============================================================================
// MARK: - WawonaPopupContainer Implementation
//==============================================================================

@implementation WawonaPopupContainer

- (instancetype)initWithPopup:(struct xdg_popup_impl *)popup
                 parentWindow:(WawonaWindowContainer *)parent
                     position:(CGPoint)position
                         size:(CGSize)size {
    self = [super init];
    if (self) {
        _popup = popup;
        _parentWindow = parent;
        _position = position;
        
        // Create surface layer for popup
        // _surfaceLayer would be set externally after creation
        
        // For now, create a simple floating layer
        // In production, decide between floating layer vs child window based on needs
        WLog(@"POPUP", @"Created popup container at (%.0f, %.0f)", position.x, position.y);
    }
    return self;
}

- (void)show {
    if (self.childWindow) {
        [self.childWindow orderFront:nil];
    } else if (self.surfaceLayer) {
        self.surfaceLayer.isMapped = YES;
        [self.surfaceLayer setNeedsRedisplay];
    }
    WLog(@"POPUP", @"Showed popup %p", _popup);
}

- (void)hide {
    if (self.childWindow) {
        [self.childWindow orderOut:nil];
    } else if (self.surfaceLayer) {
        self.surfaceLayer.isMapped = NO;
    }
    WLog(@"POPUP", @"Hid popup %p", _popup);
}

- (void)updatePosition:(CGPoint)newPosition {
    self.position = newPosition;
    
    if (self.childWindow) {
        // Update child window position
        NSRect parentFrame = self.parentWindow.window.frame;
        NSPoint screenPoint = NSMakePoint(parentFrame.origin.x + newPosition.x,
                                         parentFrame.origin.y + newPosition.y);
        [self.childWindow setFrameOrigin:screenPoint];
    } else if (self.surfaceLayer) {
        // Update layer position
        self.surfaceLayer.rootLayer.position = newPosition;
    }
    
    WLog(@"POPUP", @"Updated popup position to (%.0f, %.0f)", newPosition.x, newPosition.y);
}

@end

//==============================================================================
// MARK: - WawonaSurfaceManager Implementation
//==============================================================================

@implementation WawonaSurfaceManager

+ (instancetype)sharedManager {
    static WawonaSurfaceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WawonaSurfaceManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Use NSMapTable with pointer keys (non-retaining)
        _surfaceLayers = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                               valueOptions:NSPointerFunctionsStrongMemory];
        
        _windowContainers = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                                  valueOptions:NSPointerFunctionsStrongMemory];
        
        _popupContainers = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                                 valueOptions:NSPointerFunctionsStrongMemory];
        
        WLog(@"SURFACE_MGR", @"Initialized surface manager");
    }
    return self;
}

- (WawonaSurfaceLayer *)createSurfaceLayerForSurface:(struct wl_surface_impl *)surface {
    if (!surface) return nil;
    
    NSValue *key = [NSValue valueWithPointer:surface];
    WawonaSurfaceLayer *existing = [self.surfaceLayers objectForKey:key];
    if (existing) {
        WLog(@"SURFACE_MGR", @"Surface layer already exists for %p", surface);
        return existing;
    }
    
    WawonaSurfaceLayer *layer = [[WawonaSurfaceLayer alloc] initWithSurface:surface];
    [self.surfaceLayers setObject:layer forKey:key];
    
    WLog(@"SURFACE_MGR", @"Created surface layer for surface %p", surface);
    return layer;
}

- (void)destroySurfaceLayer:(struct wl_surface_impl *)surface {
    if (!surface) return;
    
    NSValue *key = [NSValue valueWithPointer:surface];
    [self.surfaceLayers removeObjectForKey:key];
    
    WLog(@"SURFACE_MGR", @"Destroyed surface layer for surface %p", surface);
}

- (WawonaSurfaceLayer *)layerForSurface:(struct wl_surface_impl *)surface {
    if (!surface) return nil;
    
    NSValue *key = [NSValue valueWithPointer:surface];
    return [self.surfaceLayers objectForKey:key];
}

- (WawonaWindowContainer *)createWindowForToplevel:(struct xdg_toplevel_impl *)toplevel
                                    decorationMode:(WawonaDecorationMode)mode
                                              size:(CGSize)size {
    if (!toplevel) return nil;
    
    NSValue *key = [NSValue valueWithPointer:toplevel];
    WawonaWindowContainer *existing = [self.windowContainers objectForKey:key];
    if (existing) {
        WLog(@"SURFACE_MGR", @"Window container already exists for toplevel %p", toplevel);
        return existing;
    }
    
    WawonaWindowContainer *container = [[WawonaWindowContainer alloc] initWithToplevel:toplevel
                                                                        decorationMode:mode
                                                                                  size:size];
    [self.windowContainers setObject:container forKey:key];
    
    // Create surface layer for the toplevel's surface
    if (toplevel->xdg_surface && toplevel->xdg_surface->wl_surface) {
        WawonaSurfaceLayer *surfaceLayer = [self createSurfaceLayerForSurface:toplevel->xdg_surface->wl_surface];
        container.surfaceLayer = surfaceLayer;
    }
    
    WLog(@"SURFACE_MGR", @"Created window container for toplevel %p (mode=%d)", toplevel, (int)mode);
    return container;
}

- (void)destroyWindowForToplevel:(struct xdg_toplevel_impl *)toplevel {
    if (!toplevel) return;
    
    NSValue *key = [NSValue valueWithPointer:toplevel];
    WawonaWindowContainer *container = [self.windowContainers objectForKey:key];
    
    if (container) {
        // Destroy associated surface layer
        if (toplevel->xdg_surface && toplevel->xdg_surface->wl_surface) {
            [self destroySurfaceLayer:toplevel->xdg_surface->wl_surface];
        }
        
        [self.windowContainers removeObjectForKey:key];
        WLog(@"SURFACE_MGR", @"Destroyed window container for toplevel %p", toplevel);
    }
}

- (WawonaWindowContainer *)windowForToplevel:(struct xdg_toplevel_impl *)toplevel {
    if (!toplevel) return nil;
    
    NSValue *key = [NSValue valueWithPointer:toplevel];
    return [self.windowContainers objectForKey:key];
}

- (WawonaPopupContainer *)createPopup:(struct xdg_popup_impl *)popup
                         parentWindow:(WawonaWindowContainer *)parent
                             position:(CGPoint)position
                                 size:(CGSize)size {
    if (!popup) return nil;
    
    NSValue *key = [NSValue valueWithPointer:popup];
    WawonaPopupContainer *container = [[WawonaPopupContainer alloc] initWithPopup:popup
                                                                      parentWindow:parent
                                                                          position:position
                                                                              size:size];
    [self.popupContainers setObject:container forKey:key];
    
    // Create surface layer for popup
    if (popup->xdg_surface && popup->xdg_surface->wl_surface) {
        WawonaSurfaceLayer *surfaceLayer = [self createSurfaceLayerForSurface:popup->xdg_surface->wl_surface];
        container.surfaceLayer = surfaceLayer;
    }
    
    WLog(@"SURFACE_MGR", @"Created popup container for popup %p", popup);
    return container;
}

- (void)destroyPopup:(struct xdg_popup_impl *)popup {
    if (!popup) return;
    
    NSValue *key = [NSValue valueWithPointer:popup];
    WawonaPopupContainer *container = [self.popupContainers objectForKey:key];
    
    if (container) {
        // Destroy associated surface layer
        if (popup->xdg_surface && popup->xdg_surface->wl_surface) {
            [self destroySurfaceLayer:popup->xdg_surface->wl_surface];
        }
        
        [self.popupContainers removeObjectForKey:key];
        WLog(@"SURFACE_MGR", @"Destroyed popup container for popup %p", popup);
    }
}

- (void)renderSurface:(struct wl_surface_impl *)surface {
    WawonaSurfaceLayer *layer = [self layerForSurface:surface];
    if (layer && layer.isMapped) {
        [layer setNeedsRedisplay];
    }
}

- (void)setNeedsDisplayForAllSurfaces {
    for (WawonaSurfaceLayer *layer in [self.surfaceLayers objectEnumerator]) {
        if (layer.isMapped) {
            [layer setNeedsRedisplay];
        }
    }
}

@end

