// WawonaWindowLifecycle_macos.m - macOS window lifecycle management implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaWindowLifecycle_macos.h"
#import "WawonaCompositor.h"
#import "WawonaSurfaceManager.h"
#import "WawonaCompositorView_macos.h"
#import "RenderingBackend.h"
#import "../input/input_handler.h"
#import "../compositor_implementations/xdg_shell.h"
#include "../logging/logging.h"
#include <wayland-server-core.h>
#include <float.h>

// Private NSWindow methods for window resizing
@interface NSWindow (Private)
- (void)performWindowResizeWithEdge:(NSInteger)edge event:(NSEvent *)event;
- (void)performWindowDragWithEvent:(NSEvent *)event;
@end

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

extern WawonaCompositor *g_wl_compositor_instance;
extern void xdg_toplevel_send_configure(struct wl_resource *resource,
                                       int32_t width, int32_t height,
                                       struct wl_array *states);
extern void xdg_surface_send_configure(struct wl_resource *resource, uint32_t serial);

void macos_update_toplevel_title(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !g_wl_compositor_instance) {
    return;
  }

  // Get the NSWindow from the toplevel
  if (toplevel->native_window) {
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    if (!window) {
      return;
    }

    NSString *title = @"Wawona Client"; // Default

    @try {
      if (toplevel->title && strlen(toplevel->title) > 0) {
        title = [NSString stringWithUTF8String:toplevel->title];
      } else if (toplevel->app_id && strlen(toplevel->app_id) > 0) {
        // Fallback to app_id if no title
        NSString *appId = [NSString stringWithUTF8String:toplevel->app_id];
        if (appId) {
          // Clean up common prefixes
          appId =
              [appId stringByReplacingOccurrencesOfString:@"org.freedesktop."
                                               withString:@""];
          appId = [appId stringByReplacingOccurrencesOfString:@"com."
                                                   withString:@""];
          // Capitalize first letter
          if (appId.length > 0) {
            appId = [[[appId substringToIndex:1] uppercaseString]
                stringByAppendingString:[appId substringFromIndex:1]];
          }
          title = appId;
        }
      }
    } @catch (NSException *exception) {
      NSLog(@"[WINDOW] Exception creating title string: %@", exception);
      return;
    }

    // Dispatch to main thread to update title safely
    dispatch_async(dispatch_get_main_queue(), ^{
      @try {
        window.title = title;
        NSLog(@"[WINDOW] Updated toplevel window title to: %@", title);
      } @catch (NSException *exception) {
        NSLog(@"[WINDOW] Exception setting window title: %@", exception);
      }
    });
  }
}

void macos_update_toplevel_decoration_mode(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !g_wl_compositor_instance) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    WawonaSurfaceManager *surfaceManager = [WawonaSurfaceManager sharedManager];
    WawonaWindowContainer *windowContainer = [surfaceManager windowForToplevel:toplevel];
    
    if (!windowContainer) {
      NSLog(@"[WINDOW] No window container found for toplevel %p during decoration mode update", (void *)toplevel);
      return;
    }
    
    // Convert decoration mode: 0 = unset, 1 = CSD, 2 = SSD
    WawonaDecorationMode newMode = WawonaDecorationModeUnset;
    if (toplevel->decoration_mode == 1) {
      newMode = WawonaDecorationModeCSD;
      NSLog(@"[WINDOW] Switching to CSD for toplevel %p", (void *)toplevel);
    } else if (toplevel->decoration_mode == 2) {
      newMode = WawonaDecorationModeSSD;
      NSLog(@"[WINDOW] Switching to SSD for toplevel %p", (void *)toplevel);
    } else {
      // Default to SSD if unset
      newMode = WawonaDecorationModeSSD;
      NSLog(@"[WINDOW] Using default SSD for toplevel %p", (void *)toplevel);
    }
    
    // Update the decoration mode through the window container
    [windowContainer updateDecorationMode:newMode];
    
    // Legacy compatibility: Update native_window pointer if it changed
    if (windowContainer.window) {
      toplevel->native_window = (__bridge void *)windowContainer.window;
      
      // Update legacy map
      if (g_wl_compositor_instance) {
        WawonaCompositor *compositor = g_wl_compositor_instance;
        [compositor.mapLock lock];
        [compositor.windowToToplevelMap
            setObject:[NSValue valueWithPointer:toplevel]
               forKey:[NSValue valueWithPointer:(__bridge void *)windowContainer.window]];
        [compositor.mapLock unlock];
      }
    }
    
    NSLog(@"[WINDOW] Updated decoration mode to %d for toplevel %p", (int)newMode, (void *)toplevel);
  });
}

void macos_create_window_for_toplevel(struct xdg_toplevel_impl *toplevel) {
  if (!g_wl_compositor_instance) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    WawonaCompositor *compositor = g_wl_compositor_instance;

    // Check if toplevel is still valid
    if (!toplevel->resource || !wl_resource_get_client(toplevel->resource)) {
      NSLog(@"⚠️ Toplevel resource invalid, skipping window creation");
      return;
    }

    // Determine initial window size from toplevel (last sent configure)
    int32_t initialWidth = toplevel->width > 0 ? toplevel->width : 1024;
    int32_t initialHeight = toplevel->height > 0 ? toplevel->height : 768;

    // Use window geometry if available as an override
    if (toplevel->xdg_surface && toplevel->xdg_surface->has_geometry) {
      initialWidth = toplevel->xdg_surface->geometry_width;
      initialHeight = toplevel->xdg_surface->geometry_height;
      NSLog(@"[WINDOW] Overriding initial size with geometry: %dx%d",
            initialWidth, initialHeight);
    } else {
      struct wl_surface_impl *surface = toplevel->xdg_surface->wl_surface;
      if (surface && surface->width > 0 && surface->height > 0) {
        initialWidth = surface->width;
        initialHeight = surface->height;
        NSLog(@"[WINDOW] Overriding initial size with surface: %dx%d",
              initialWidth, initialHeight);
      }
    }

    NSLog(@"[WINDOW] Creating window with content size: %dx%d", initialWidth,
          initialHeight);

    // Use a reasonable default size if nothing is known yet
    if (initialWidth <= 0)
      initialWidth = 1024;
    if (initialHeight <= 0)
      initialHeight = 768;

    // Use WawonaSurfaceManager to create window container
    WawonaSurfaceManager *surfaceManager = [WawonaSurfaceManager sharedManager];
    
    // Convert decoration mode: 0 = unset, 1 = CSD, 2 = SSD
    WawonaDecorationMode mode = WawonaDecorationModeUnset;
    if (toplevel->decoration_mode == 1) {
      mode = WawonaDecorationModeCSD;
    } else if (toplevel->decoration_mode == 2) {
      mode = WawonaDecorationModeSSD;
    } else {
      // Default to SSD if unset
      mode = WawonaDecorationModeSSD;
    }
    
    CGSize windowSize = CGSizeMake(initialWidth, initialHeight);
    WawonaWindowContainer *windowContainer = [surfaceManager createWindowForToplevel:toplevel
                                                                      decorationMode:mode
                                                                                size:windowSize];
    
    if (!windowContainer || !windowContainer.window) {
      NSLog(@"❌ Failed to create window container for toplevel");
      return;
    }
    
    NSWindow *window = windowContainer.window;
    
    // Set window title if available
    if (toplevel->title) {
      [windowContainer setTitle:[NSString stringWithUTF8String:toplevel->title]];
    }
    
    // CRITICAL: Set up CompositorView and renderer for the window
    // The rendering pipeline expects this!
    // Get the existing content view frame (respects window style)
    NSRect viewRect = window.contentView.frame;
    CompositorView *compositorView = [[CompositorView alloc] initWithFrame:viewRect];
    
    // Replace the window's content view with our CompositorView
    // This preserves the window's style and decoration mode
    window.contentView = compositorView;
    compositorView.compositor = compositor;
    compositorView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    // Create Metal renderer
    id<RenderingBackend> renderer = [RenderingBackendFactory createBackend:RENDERING_BACKEND_METAL 
                                                                    withView:compositorView];
    compositorView.renderer = renderer;
    
    // Set as fallback renderer if needed
    if (!compositor.renderingBackend) {
      compositor.renderingBackend = renderer;
    }
    
    // Create input handler for this window
    InputHandler *inputHandler = [[InputHandler alloc] initWithSeat:compositor.seat
                                                              window:window
                                                          compositor:compositor];
    compositorView.inputHandler = inputHandler;
    
    // Legacy compatibility: Store toplevel in old map for existing code
    [compositor.mapLock lock];
    [compositor.windowToToplevelMap
        setObject:[NSValue valueWithPointer:toplevel]
           forKey:[NSValue valueWithPointer:(__bridge void *)window]];
    [compositor.mapLock unlock];

    // Show the window
    [windowContainer show];
    [window makeFirstResponder:compositorView];
    
    NSLog(@"[WINDOW] Created and showed window %p via WawonaSurfaceManager (mode=%d) with renderer %p",
          (__bridge void *)window, (int)mode, renderer);
    [window makeKeyWindow];

    // Now set initial title from toplevel if available
    macos_update_toplevel_title(toplevel);

    // Store window in nativeWindows to ensure it is retained by ARC
    [compositor.nativeWindows addObject:window];
    
    // CRITICAL: Send initial configure to client with proper size and states
    if (toplevel->xdg_surface && toplevel->xdg_surface->resource) {
      // Build states array
      struct wl_array states;
      wl_array_init(&states);
      
      // Add activated state
      uint32_t *state = wl_array_add(&states, sizeof(uint32_t));
      if (state) {
        *state = 4; // XDG_TOPLEVEL_STATE_ACTIVATED
      }
      
      // Get content size to send to client
      NSRect contentRect = [window contentRectForFrameRect:window.frame];
      int32_t configWidth = (int32_t)contentRect.size.width;
      int32_t configHeight = (int32_t)contentRect.size.height;
      
      // Send configure events
      xdg_toplevel_send_configure(toplevel->resource, configWidth, configHeight, &states);
      uint32_t serial = ++toplevel->xdg_surface->configure_serial;
      xdg_surface_send_configure(toplevel->xdg_surface->resource, serial);
      
      toplevel->width = configWidth;
      toplevel->height = configHeight;
      
      wl_array_release(&states);
      
      NSLog(@"[WINDOW] Sent initial configure: %dx%d serial=%u mode=%d",
            configWidth, configHeight, serial, (int)mode);
    }

    NSLog(@"✅ Created window for toplevel: %@ (Mode: %u)", window,
          toplevel->decoration_mode);
  });
}

void macos_toplevel_set_minimized(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    [window miniaturize:nil];
  });
}

void macos_toplevel_set_maximized(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    if (![window isZoomed]) {
      [window zoom:nil];
    }
  });
}

void macos_toplevel_unset_maximized(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    if ([window isZoomed]) {
      [window zoom:nil];
    }
  });
}

void macos_toplevel_close(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    [window close];
  });
}

void macos_toplevel_set_fullscreen(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    if (!((window.styleMask & NSWindowStyleMaskFullScreen) ==
          NSWindowStyleMaskFullScreen)) {
      [window toggleFullScreen:nil];
    }
  });
}

void macos_toplevel_unset_fullscreen(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    if ((window.styleMask & NSWindowStyleMaskFullScreen) ==
        NSWindowStyleMaskFullScreen) {
      [window toggleFullScreen:nil];
    }
  });
}

void macos_toplevel_set_min_size(struct xdg_toplevel_impl *toplevel, int32_t width, int32_t height) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    if (width > 0 && height > 0) {
        window.minSize = NSMakeSize(width, height);
    } else {
        window.minSize = NSMakeSize(1, 1); // Default small size
    }
  });
}

void macos_toplevel_set_max_size(struct xdg_toplevel_impl *toplevel, int32_t width, int32_t height) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    if (width > 0 && height > 0) {
        window.maxSize = NSMakeSize(width, height);
    } else {
        window.maxSize = NSMakeSize(FLT_MAX, FLT_MAX); // No restriction
    }
  });
}

void macos_start_toplevel_resize(struct xdg_toplevel_impl *toplevel,
                                 uint32_t edges) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    NSEvent *event = nil;
    if (g_wl_compositor_instance && g_wl_compositor_instance.inputHandler) {
        event = g_wl_compositor_instance.inputHandler.lastMouseDownEvent;
    }
    if (!event) {
        event = [NSApp currentEvent];
    }
    
    if (event) {
      // Mapping xdg_toplevel.resize edges to NSWindowEdge
      // xdg: 1=T, 2=B, 4=L, 5=TL, 6=BL, 8=R, 9=TR, 10=BR
      // AppKit: L=0, R=1, T=2, B=3, TL=4, TR=5, BL=6, BR=7
      NSInteger appKitEdge = 0;
      switch (edges) {
      case 1:
        appKitEdge = 2;
        break; // Top
      case 2:
        appKitEdge = 3;
        break; // Bottom
      case 4:
        appKitEdge = 0;
        break; // Left
      case 8:
        appKitEdge = 1;
        break; // Right
      case 5:
        appKitEdge = 4;
        break; // TopLeft
      case 9:
        appKitEdge = 5;
        break; // TopRight
      case 6:
        appKitEdge = 6;
        break; // BottomLeft
      case 10:
        appKitEdge = 7;
        break; // BottomRight
      default:
        return; // No valid edge
      }

      if ([window respondsToSelector:@selector
                  (performWindowResizeWithEdge:event:)]) {
        [window performWindowResizeWithEdge:appKitEdge event:event];
      }
    }
  });
}

void macos_start_toplevel_move(struct xdg_toplevel_impl *toplevel) {
  if (!toplevel || !toplevel->native_window)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = (__bridge NSWindow *)toplevel->native_window;
    NSEvent *event = nil;
    if (g_wl_compositor_instance && g_wl_compositor_instance.inputHandler) {
        event = g_wl_compositor_instance.inputHandler.lastMouseDownEvent;
    }
    if (!event) {
        event = [NSApp currentEvent];
    }
    
    if (event && [window respondsToSelector:@selector(performWindowDragWithEvent:)]) {
      [window performWindowDragWithEvent:event];
    }
  });
}

#endif // !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

