// renderer_apple_helpers.m - Simplified Rendering Bridge
#include "../logging/logging.h"
#import "../platform/macos/WawonaCompositor.h"
#import "../platform/macos/WawonaSurfaceManager.h"
#import "renderer_apple.h"
#include <wayland-server-protocol.h>
#include <wayland-server.h>

// Externs
extern struct xdg_toplevel_impl *
xdg_surface_get_toplevel_from_wl_surface(struct wl_surface_impl *wl_surface);
// g_wl_compositor_instance is provided by WawonaCompositor.h

id<RenderingBackend>
wawona_find_renderer_for_surface(struct wl_surface_impl *surface) {
  log_printf("RENDER", "find_renderer entered for surface %p\n", surface);
  if (!surface) {
    log_printf("RENDER", "find_renderer: surface is NULL\n");
    return nil;
  }

  // Find the toplevel window responsible for this surface
  struct xdg_toplevel_impl *toplevel =
      xdg_surface_get_toplevel_from_wl_surface(surface);

  log_printf("RENDER", "find_renderer: surface=%p, toplevel=%p\n", surface,
             (void *)toplevel);

  // If found, look up its Wawona window container
  if (toplevel) {
    WawonaWindowContainer *container =
        [[WawonaSurfaceManager sharedManager] windowForToplevel:toplevel];
    log_printf("RENDER", "find_renderer: toplevel=%p, container=%p\n",
               (void *)toplevel, container);
    if (container) {
      if (container.window) {
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
        UIView *view = container.contentView;
#else
        NSView *view = container.window.contentView;
#endif
        log_printf("RENDER", "find_renderer: container.window=%p, view=%p\n",
                   container.window, view);
        if (view && [view respondsToSelector:@selector(renderer)]) {
          id<RenderingBackend> renderer =
              [view performSelector:@selector(renderer)];
          log_printf("RENDER",
                     "find_renderer: Success: via container, renderer=%p\n",
                     renderer);
          return renderer;
        } else {
          log_printf("RENDER", "find_renderer: Error: view does not "
                               "respond to renderer selector\n");
        }
      } else {
        log_printf("RENDER", "find_renderer: Error: container.window is nil\n");
      }
    } else {
      log_printf("RENDER",
                 "find_renderer: Warning: no container for toplevel (may "
                 "be subsurface)\n");
    }
  } else {
    log_printf("RENDER",
               "find_renderer: Warning: no toplevel for surface (pre-xdg "
               "or cursor)\n");
  }

  // Fallback: If we can't associate with a specific window, try the global
  // backend This handles cases like cursors or unmapped surfaces if they happen
  // to reach here
  if (g_wl_compositor_instance) {
    if (g_wl_compositor_instance.renderingBackend) {
      log_printf("RENDER", "find_renderer: Fallback to global backend %p\n",
                 g_wl_compositor_instance.renderingBackend);
      return g_wl_compositor_instance.renderingBackend;
    } else {
      log_printf("RENDER",
                 "find_renderer: Error: "
                 "g_wl_compositor_instance.renderingBackend is nil\n");
    }
  } else {
    log_printf("RENDER",
               "find_renderer: Error: g_wl_compositor_instance is NULL\n");
  }

  log_printf("RENDER",
             "find_renderer: Final Error: returning nil for surface %p\n",
             surface);
  return nil;
}

void wawona_render_surface_immediate(struct wl_surface_impl *surface) {
  log_printf("RENDER", "Immediate render for surface %p\n", surface);
  if (!surface)
    return;

  id<RenderingBackend> renderer = wawona_find_renderer_for_surface(surface);
  if (renderer) {
    // log_printf("RENDER", "Rendering surface %p\n", surface);
    // Delegate rendering to the backend (Metal Renderer)
    [renderer renderSurface:surface];

    // Trigger repaint
    if ([renderer respondsToSelector:@selector(setNeedsDisplay)]) {
      [renderer setNeedsDisplay];
    } else if ([renderer respondsToSelector:@selector(view)]) {
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
      UIView *v = [renderer performSelector:@selector(view)];
      dispatch_async(dispatch_get_main_queue(), ^{
        [v setNeedsDisplay];
      });
#else
      NSView *v = [renderer performSelector:@selector(view)];
      dispatch_async(dispatch_get_main_queue(), ^{
        [v setNeedsDisplay:YES];
      });
#endif
    }
  }

  // Safety: If no renderer found, we can't draw.
}

void wawona_render_surface_callback(struct wl_surface_impl *surface) {
  log_printf("RENDER", "Callback triggered for surface %p\n", surface);
  if (!surface)
    return;

  // Render synchronously on the current thread (Wayland thread)
  // to prevent Use-After-Free if the surface is destroyed asynchronously.
  wawona_render_surface_immediate(surface);
}
