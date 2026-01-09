// WawonaRenderManager.m - Rendering management implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaRenderManager.h"
#import "WawonaCompositor.h"
#import "../compositor_implementations/wayland_compositor.h"
#import "RenderingBackend.h"
#import "../rendering/renderer_macos.h"

// Render context for thread-safe iteration
struct RenderContext {
  __unsafe_unretained WawonaCompositor *compositor;
  BOOL surfacesWereRendered;
};

// Iterator function for rendering surfaces
static void render_surface_iterator(struct wl_surface_impl *surface,
                                    void *data) {
  struct RenderContext *ctx = (struct RenderContext *)data;
  WawonaCompositor *compositor = ctx->compositor;

  // Only render if surface is still valid and has committed buffer
  if (surface->committed && surface->buffer_resource && surface->resource) {
    // Verify resource is still valid before rendering
    struct wl_client *client = wl_resource_get_client(surface->resource);
    if (client) {
      // Use compositor's rendering backend
      id<RenderingBackend> renderer = compositor.renderingBackend;
      if (renderer && [renderer respondsToSelector:@selector(renderSurface:)]) {
        [renderer renderSurface:surface];
        ctx->surfacesWereRendered = YES;
      }
    }
    surface->committed = false;
  }
}

@implementation WawonaRenderManager {
  WawonaCompositor *_compositor;
}

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor {
  self = [super init];
  if (self) {
    _compositor = compositor;
  }
  return self;
}

- (void)renderFrame {
  // Render callback - called at display refresh rate (via CVDisplayLink)
  // Event processing is handled by the dedicated Wayland event thread
  // This ensures smooth rendering updates synced to display refresh
  // NOTE: This continues to run even when the window loses focus, ensuring
  // Wayland clients continue to receive frame callbacks and can render
  // updates

  // Note: Frame callback timer is now created automatically when clients
  // request frame callbacks via the macos_compositor_frame_callback_requested
  // callback. This ensures the timer is created on the event thread and
  // starts firing immediately. We don't need to check here anymore - the
  // timer will be created when needed.

  // Check for any committed surfaces and render them
  // Note: The event thread also triggers rendering, but this ensures
  // we catch any surfaces that might have been committed between thread
  // dispatches Continue rendering even when window isn't focused - clients
  // need frame callbacks

  struct RenderContext ctx;
  ctx.compositor = _compositor;
  ctx.surfacesWereRendered = NO;

  // Use thread-safe iteration to render surfaces
  // This locks the surfaces mutex to prevent race conditions with the event
  // thread
  wl_compositor_for_each_surface(render_surface_iterator, &ctx);

  BOOL surfacesWereRendered = ctx.surfacesWereRendered;

  // Trigger view redraw if surfaces were rendered
  // CRITICAL: Even with Metal backend continuous rendering, we must trigger
  // redraw when surfaces are updated to ensure immediate display of nested
  // compositor updates
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
  UIView *contentView = _compositor.window.rootViewController.view;
  if (surfacesWereRendered && _compositor.window && contentView) {
    if (_compositor.backendType == 1) {
      // Metal backend - trigger redraw using renderer's setNeedsDisplay
      // method This ensures nested compositors (like Weston) see updates
      // immediately
      if ([_compositor.renderingBackend
              respondsToSelector:@selector(setNeedsDisplay)]) {
        [_compositor.renderingBackend setNeedsDisplay];
      }
    } else {
      // Cocoa backend - needs explicit redraw
      [contentView setNeedsDisplay];
    }
  } else if (_compositor.window && contentView && _compositor.backendType != 1) {
    // Cocoa backend always needs redraw for frame callbacks
    [contentView setNeedsDisplay];
  }
#else
  if (surfacesWereRendered && _compositor.window && _compositor.window.contentView) {
    if (_compositor.backendType == 1) {
      // Metal backend - trigger redraw using renderer's setNeedsDisplay
      // method This ensures nested compositors (like Weston) see updates
      // immediately
      if ([_compositor.renderingBackend
              respondsToSelector:@selector(setNeedsDisplay)]) {
        [_compositor.renderingBackend setNeedsDisplay];
      }
    } else {
      // Cocoa backend - needs explicit redraw
      [_compositor.window.contentView setNeedsDisplay:YES];
    }
  } else if (_compositor.window && _compositor.window.contentView && _compositor.backendType != 1) {
    // Cocoa backend always needs redraw for frame callbacks
    [_compositor.window.contentView setNeedsDisplay:YES];
  }
#endif
}

@end

