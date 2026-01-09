// WawonaCompositor_macos.m - macOS-specific compositor extensions
// Extracted from WawonaCompositor.m for better organization

#import "WawonaCompositor_macos.h"
#import "WawonaCompositor.h"
#import "../compositor_implementations/xdg_shell.h"
#import "../input/wayland_seat.h"
#include "../logging/logging.h"
#include <wayland-server-core.h>

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

extern void xdg_toplevel_send_configure(struct wl_resource *resource,
                                       int32_t width, int32_t height,
                                       struct wl_array *states);
extern void xdg_surface_send_configure(struct wl_resource *resource, uint32_t serial);

@implementation WawonaCompositor (WindowDelegate)

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
                        defaultFrame:(NSRect)newFrame {
  // When maximizing (zooming), use the full visible screen area
  // This ensures borderless windows behave correctly when zoomed
  if (window.screen) {
    return [window.screen visibleFrame];
  }
  return newFrame;
}

- (void)windowWillStartLiveResize:(NSNotification *)notification {
    NSLog(@"[WINDOW] Started live resize for window: %@", notification.object);
    self.isLiveResizing = YES;
    self.liveResizeStartFrame = [notification.object frame];
}

- (void)windowDidEndLiveResize:(NSNotification *)notification {
    NSLog(@"[WINDOW] Ended live resize for window: %@", notification.object);
    self.isLiveResizing = NO;
    
    // Ensure final state is consistent by triggering one last resize logic
    [self windowDidResize:notification];
}

- (void)windowDidResize:(NSNotification *)notification {
  NSWindow *window = notification.object;
  
  [self.mapLock lock];
  NSValue *toplevelValue = [self.windowToToplevelMap
      objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];
  [self.mapLock unlock];

  if (toplevelValue) {
    struct xdg_toplevel_impl *toplevel = [toplevelValue pointerValue];
    CGSize size = [window.contentView bounds].size;

    // Use logical points for Wayland protocol communication (NOT pixels)
    // Wayland xdg-shell protocol specifies dimensions in logical coordinates.
    int32_t width = (int32_t)size.width;
    int32_t height = (int32_t)size.height;

    // Check if this resize is in response to a client configure (avoid feedback loop)
    // If the surface is currently being configured, don't send another configure
    struct wl_surface_impl *surface = toplevel->xdg_surface->wl_surface;
    if (surface && surface->configured) {
      // Surface is currently processing a configure - skip sending another one
      NSLog(@"[WINDOW] Skipping configure event (surface is being configured)");
      return;
    }
    
    // CSD Resizing Logic:
    // For CSD, the NSWindow size includes client-drawn shadows (buffer size).
    // The configure event expects the GEOMETRY size (excluding shadows).
    // We must subtract the shadow margins to prevent an infinite resize loop.
    int32_t geometryWidth = width;
    int32_t geometryHeight = height;
    
    if (toplevel->decoration_mode == 1 && toplevel->xdg_surface->has_geometry) {
        int32_t currentBufferW = surface->width;
        int32_t currentBufferH = surface->height;
        int32_t currentGeoW = toplevel->xdg_surface->geometry_width;
        int32_t currentGeoH = toplevel->xdg_surface->geometry_height;
        
        // Calculate current margins (shadows)
        int32_t marginW = (currentBufferW > currentGeoW) ? (currentBufferW - currentGeoW) : 0;
        int32_t marginH = (currentBufferH > currentGeoH) ? (currentBufferH - currentGeoH) : 0;
        
        // Subtract margins from window size to get target geometry size
        geometryWidth = width - marginW;
        geometryHeight = height - marginH;
        
        if (geometryWidth < 1) geometryWidth = 1;
        if (geometryHeight < 1) geometryHeight = 1;
        
        NSLog(@"[CSD RESIZE] Window: %dx%d, Margins: %dx%d -> Configure Geometry: %dx%d", 
              width, height, marginW, marginH, geometryWidth, geometryHeight);
    }

    // Update toplevel geometry
    toplevel->width = geometryWidth;
    toplevel->height = geometryHeight;

    // Send configure event
    struct wl_array states;
    wl_array_init(&states);
    uint32_t *activated = wl_array_add(&states, sizeof(uint32_t));
    if (activated)
      *activated = XDG_TOPLEVEL_STATE_ACTIVATED;

    // Also add valid states based on window state
    if (window.isZoomed) {
      uint32_t *maximized = wl_array_add(&states, sizeof(uint32_t));
      if (maximized)
        *maximized = XDG_TOPLEVEL_STATE_MAXIMIZED;
    }
    
    if (toplevel->decoration_mode == 1 && window.styleMask & NSWindowStyleMaskFullScreen) {
        uint32_t *fullscreen = wl_array_add(&states, sizeof(uint32_t));
        if (fullscreen)
            *fullscreen = XDG_TOPLEVEL_STATE_FULLSCREEN;
    }

    xdg_toplevel_send_configure(toplevel->resource, geometryWidth, geometryHeight, &states);
    wl_array_release(&states);

    uint32_t serial = ++toplevel->xdg_surface->configure_serial;
    xdg_surface_send_configure(toplevel->xdg_surface->resource, serial);

    // Track pending serial on the surface too
    if (surface) {
      surface->pending_configure_serial = serial;
      surface->configured = false; // Mark as being configured
    }

    // CRITICAL: Flush clients immediately so they receive the configure
    // events
    wl_display_flush_clients(self.display);

    // Ensure frame callback timer is running to process the first frame after
    // resize
    [self sendFrameCallbacksImmediately];
  }
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
  NSWindow *window = notification.object;
  NSValue *toplevelValue = [self.windowToToplevelMap
      objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];

  if (toplevelValue) {
    struct xdg_toplevel_impl *toplevel = [toplevelValue pointerValue];

    // Send activated state
    struct wl_array states;
    wl_array_init(&states);
    uint32_t *activated = wl_array_add(&states, sizeof(uint32_t));
    if (activated)
      *activated = XDG_TOPLEVEL_STATE_ACTIVATED;

    xdg_toplevel_send_configure(toplevel->resource, 0, 0,
                                &states); // 0,0 means maintain current size
    wl_array_release(&states);

    uint32_t serial = ++toplevel->xdg_surface->configure_serial;
    xdg_surface_send_configure(toplevel->xdg_surface->resource, serial);

    // Track pending serial on the surface too
    struct wl_surface_impl *surface = toplevel->xdg_surface->wl_surface;
    if (surface) {
      surface->pending_configure_serial = serial;
      surface->configured = false;

      if (self.seat) {
        // Create empty keys array
        struct wl_array keys;
        wl_array_init(&keys);
        wl_seat_send_keyboard_enter(self.seat, surface->resource,
                                    wl_seat_get_serial(self.seat), &keys);
        wl_array_release(&keys);
        wl_seat_send_keyboard_modifiers(self.seat,
                                        wl_seat_get_serial(self.seat));
      }
    }

    // Flush to ensure activation and focus are sent
    wl_display_flush_clients(self.display);
  }
}

- (void)windowDidResignKey:(NSNotification *)notification {
  NSWindow *window = notification.object;
  NSValue *toplevelValue = [self.windowToToplevelMap
      objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];

  if (toplevelValue) {
    struct xdg_toplevel_impl *toplevel = [toplevelValue pointerValue];

    // Send deactivated state (empty states)
    struct wl_array states;
    wl_array_init(&states);

    xdg_toplevel_send_configure(toplevel->resource, 0, 0, &states);
    wl_array_release(&states);

    uint32_t serial = ++toplevel->xdg_surface->configure_serial;
    xdg_surface_send_configure(toplevel->xdg_surface->resource, serial);

    // Track pending serial on the surface too
    struct wl_surface_impl *surface = toplevel->xdg_surface->wl_surface;
    if (surface) {
      surface->pending_configure_serial = serial;
      surface->configured = false;

      // Unset keyboard focus
      if (self.seat) {
        wl_seat_send_keyboard_leave(self.seat, surface->resource,
                                    wl_seat_get_serial(self.seat));
      }
    }

    // Flush to ensure deactivation and focus leave are sent
    wl_display_flush_clients(self.display);
  }
}

// NSWindowDelegate method - called when window is minimized
- (void)windowDidMiniaturize:(NSNotification *)notification {
  NSWindow *window = notification.object;
  NSValue *toplevelValue = [self.windowToToplevelMap
      objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];

  if (toplevelValue) {
    struct xdg_toplevel_impl *toplevel = [toplevelValue pointerValue];
    NSLog(@"[WINDOW] windowDidMiniaturize called for toplevel %p", (void *)toplevel);

    // Note: xdg-shell protocol doesn't have a minimized state constant
    // The client should handle minimization via set_minimized request
    // We just log the state change here
    
    // Send current state (activated only, no minimized state available)
    struct wl_array states;
    wl_array_init(&states);
    
    // Add activated state
    uint32_t *activated = wl_array_add(&states, sizeof(uint32_t));
    if (activated)
      *activated = XDG_TOPLEVEL_STATE_ACTIVATED;

    xdg_toplevel_send_configure(toplevel->resource, 0, 0, &states);
    wl_array_release(&states);

    uint32_t serial = ++toplevel->xdg_surface->configure_serial;
    xdg_surface_send_configure(toplevel->xdg_surface->resource, serial);

    wl_display_flush_clients(self.display);
  }
}

// NSWindowDelegate method - called when window is deminimized (restored)
- (void)windowDidDeminiaturize:(NSNotification *)notification {
  NSWindow *window = notification.object;
  NSValue *toplevelValue = [self.windowToToplevelMap
      objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];

  if (toplevelValue) {
    struct xdg_toplevel_impl *toplevel = [toplevelValue pointerValue];
    NSLog(@"[WINDOW] Window restored for toplevel %p", (void *)toplevel);

    // Send activated state (no minimized state)
    struct wl_array states;
    wl_array_init(&states);
    
    // Add activated state
    uint32_t *activated = wl_array_add(&states, sizeof(uint32_t));
    if (activated)
      *activated = XDG_TOPLEVEL_STATE_ACTIVATED;

    // Add maximized state if window is zoomed
    if (window.isZoomed) {
      uint32_t *maximized = wl_array_add(&states, sizeof(uint32_t));
      if (maximized)
        *maximized = XDG_TOPLEVEL_STATE_MAXIMIZED;
    }

    xdg_toplevel_send_configure(toplevel->resource, 0, 0, &states);
    wl_array_release(&states);

    uint32_t serial = ++toplevel->xdg_surface->configure_serial;
    xdg_surface_send_configure(toplevel->xdg_surface->resource, serial);

    wl_display_flush_clients(self.display);
  }
}

// NSWindowDelegate method - called when window is zoomed (maximized)
- (void)windowDidZoom:(NSNotification *)notification {
  NSWindow *window = notification.object;
  NSValue *toplevelValue = [self.windowToToplevelMap
      objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];

  if (toplevelValue) {
    struct xdg_toplevel_impl *toplevel = [toplevelValue pointerValue];
    
    if ([window isZoomed]) {
      NSLog(@"[WINDOW] Window maximized for toplevel %p", (void *)toplevel);
    } else {
      NSLog(@"[WINDOW] Window unmaximized for toplevel %p", (void *)toplevel);
    }

    // Send appropriate states to client
    struct wl_array states;
    wl_array_init(&states);
    
    // Add activated state
    uint32_t *activated = wl_array_add(&states, sizeof(uint32_t));
    if (activated)
      *activated = XDG_TOPLEVEL_STATE_ACTIVATED;

    // Add maximized state if window is zoomed
    if ([window isZoomed]) {
      uint32_t *maximized = wl_array_add(&states, sizeof(uint32_t));
      if (maximized)
        *maximized = XDG_TOPLEVEL_STATE_MAXIMIZED;
    }

    xdg_toplevel_send_configure(toplevel->resource, 0, 0, &states);
    wl_array_release(&states);

    uint32_t serial = ++toplevel->xdg_surface->configure_serial;
    xdg_surface_send_configure(toplevel->xdg_surface->resource, serial);

    wl_display_flush_clients(self.display);
  }
}

// NSWindowDelegate method - called before window zooms (maximizes)
- (BOOL)windowShouldZoom:(NSWindow *)window toFrame:(NSRect)newFrame {
  struct xdg_toplevel_impl *toplevel = NULL;
  
  [self.mapLock lock];
  NSValue *toplevelValue = [self.windowToToplevelMap
      objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];
  if (toplevelValue) {
    toplevel = [toplevelValue pointerValue];
  }
  [self.mapLock unlock];

  if (toplevel) {
    NSLog(@"[WINDOW] windowShouldZoom called for toplevel %p (new frame: %.0f,%.0f,%.0f,%.0f)", 
          (void *)toplevel, newFrame.origin.x, newFrame.origin.y, newFrame.size.width, newFrame.size.height);
    
    // For CSD clients, we should allow zooming but also notify the client
    if (toplevel->decoration_mode == 1) { // CLIENT_SIDE
      NSLog(@"[WINDOW] Allowing zoom for CSD client");
      return YES;
    }
  }
  
  NSLog(@"[WINDOW] Allowing zoom by default");
  return YES; // Allow zoom by default
}

// Fix for CSD window resizing - ensure CSD windows remain resizable
- (void)fixCSDWindowResizing:(NSWindow *)window {
  if (!window) return;
  
  struct xdg_toplevel_impl *toplevel = NULL;
  
  [self.mapLock lock];
  NSValue *toplevelValue = [self.windowToToplevelMap
      objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];
  if (toplevelValue) {
    toplevel = [toplevelValue pointerValue];
  }
  [self.mapLock unlock];

  if (toplevel) {
    if (toplevel->decoration_mode == 1) { // CLIENT_SIDE
      NSLog(@"[CSD] Fixing resize behavior for CSD window");
      
      // Use Titled + FullSizeContentView to get native resize behavior without visible title bar
      NSWindowStyleMask style = NSWindowStyleMaskTitled | 
                                NSWindowStyleMaskFullSizeContentView |
                                NSWindowStyleMaskResizable |
                                NSWindowStyleMaskMiniaturizable |
                                NSWindowStyleMaskClosable;
                                
      if (window.styleMask != style) {
        window.styleMask = style;
        NSLog(@"[CSD] Updated window style flags for proper CSD behavior (Hidden Titlebar)");
      }
      
      window.titlebarAppearsTransparent = YES;
      window.titleVisibility = NSWindowTitleHidden;
      
      // Hide standard buttons to avoid "macOS GUI"
      NSButton *closeBtn = [window standardWindowButton:NSWindowCloseButton];
      NSButton *minBtn = [window standardWindowButton:NSWindowMiniaturizeButton];
      NSButton *zoomBtn = [window standardWindowButton:NSWindowZoomButton];
      
      [closeBtn setHidden:YES];
      [minBtn setHidden:YES];
      [zoomBtn setHidden:YES];
      
      // Also ensure they are disabled and transparent
      [closeBtn setEnabled:NO];
      [minBtn setEnabled:NO];
      [zoomBtn setEnabled:NO];
      [closeBtn setAlphaValue:0.0];
      [minBtn setAlphaValue:0.0];
      [zoomBtn setAlphaValue:0.0];
      
      // Ensure the window can be resized by dragging edges
      // Disable macOS shadow because CSD clients render their own shadow (Layer 1)
      // Enabling both would cause double shadows
      window.hasShadow = NO;
      
      // Ensure transparent background for CSD content
      window.opaque = NO;
      window.backgroundColor = [NSColor clearColor];
      
      NSLog(@"[CSD] Configured hidden title bar for CSD window");
    }
  }
}

- (void)windowWillClose:(NSNotification *)notification {
  NSWindow *window = notification.object;
  NSValue *windowKey = [NSValue valueWithPointer:(__bridge void *)window];

  NSLog(@"ℹ️ Window will close: %@", window);

  // Remove from toplevel map with lock to prevent race conditions
  [self.mapLock lock];
  NSValue *toplevelValue = [self.windowToToplevelMap objectForKey:windowKey];
  if (toplevelValue) {
      struct xdg_toplevel_impl *toplevel = [toplevelValue pointerValue];
      if (toplevel) {
          // CRITICAL: Nullify the native_window pointer to prevent dangling pointer crashes
          // if the toplevel is accessed after the window is closed.
          toplevel->native_window = NULL;
      }
  }
  [self.windowToToplevelMap removeObjectForKey:windowKey];
  [self.mapLock unlock];

  // Remove from nativeWindows array to allow deallocation
  [self.nativeWindows removeObject:window];
}

// NSWindowDelegate method - called when window close button (X) is clicked
- (BOOL)windowShouldClose:(NSWindow *)sender {
  (void)sender;

  NSLog(@"[WINDOW] Window close button clicked - sending close event to "
        @"client");

  // Use compositor's seat to find the focused surface
  struct wl_seat_impl *seat_ref = self.seat;
  if (!seat_ref || !seat_ref->focused_surface) {
    NSLog(@"[WINDOW] No focused surface - closing window");
    return YES; // Allow window to close
  }

  // Get the focused surface
  struct wl_surface_impl *focused_surface =
      (struct wl_surface_impl *)seat_ref->focused_surface;
  if (!focused_surface || !focused_surface->resource) {
    NSLog(@"[WINDOW] Focused surface is invalid - closing window");
    return YES; // Allow window to close
  }

  // Find the toplevel associated with this surface
  extern struct xdg_toplevel_impl *xdg_surface_get_toplevel_from_wl_surface(
      struct wl_surface_impl * wl_surface);
  struct xdg_toplevel_impl *toplevel =
      xdg_surface_get_toplevel_from_wl_surface(focused_surface);

  if (!toplevel || !toplevel->resource) {
    NSLog(@"[WINDOW] No toplevel found for focused surface - closing window");
    return YES; // Allow window to close
  }

  // Verify the toplevel resource is still valid
  struct wl_client *client = wl_resource_get_client(toplevel->resource);
  if (!client || wl_resource_get_user_data(toplevel->resource) == NULL) {
    NSLog(@"[WINDOW] Toplevel resource is invalid - closing window");
    return YES; // Allow window to close
  }

  // Send close event to the client
  NSLog(@"[WINDOW] Sending close event to client (toplevel=%p, client=%p)",
        (void *)toplevel, (void *)client);

  // Use the xdg_toplevel_send_close function from xdg-shell-protocol.h
  // This sends the XDG_TOPLEVEL_CLOSE event to the client
  wl_resource_post_event(toplevel->resource, XDG_TOPLEVEL_CLOSE);

  // Flush the client connection to ensure the close event is sent
  wl_display_flush_clients(self.display);

  // Disconnect the client after a short delay to allow it to handle the close
  // event This gives well-behaved clients a chance to clean up gracefully
  // Store the client pointer in a local variable for the block
  struct wl_client *client_to_disconnect = client;
  struct wl_resource *toplevel_resource = toplevel->resource;

  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        // Check if client is still connected by verifying the toplevel
        // resource still belongs to it
        if (client_to_disconnect && toplevel_resource) {
          struct wl_client *current_client =
              wl_resource_get_client(toplevel_resource);
          if (current_client == client_to_disconnect) {
            // Client is still connected - disconnect it
            NSLog(@"[WINDOW] Client did not close gracefully - disconnecting");
            wl_client_destroy(client_to_disconnect);
          }
        }
      });

  // Don't close the window immediately - let the client handle the close
  // event The window will be closed when the client disconnects
  return NO; // Prevent window from closing immediately
}

// NSWindowDelegate method - called when window enters fullscreen
- (void)windowDidEnterFullScreen:(NSNotification *)notification {
  (void)notification;
  self.isFullscreen = YES;
  NSLog(@"[FULLSCREEN] Window entered fullscreen");
}

// NSWindowDelegate method - called when window exits fullscreen
- (void)windowDidExitFullScreen:(NSNotification *)notification {
  (void)notification;
  self.isFullscreen = NO;

  // Cancel any pending exit timer
  if (self.fullscreenExitTimer) {
    [self.fullscreenExitTimer invalidate];
    self.fullscreenExitTimer = nil;
  }

  // Ensure titlebar is visible after exiting fullscreen (especially if client
  // disconnected) This allows users to interact with the window even if no
  // clients are connected
  if (self.window && self.connectedClientCount == 0) {
    NSWindowStyleMask titlebarStyle =
        (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
         NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable);
    if (self.window.styleMask != titlebarStyle) {
      self.window.styleMask = titlebarStyle;
      NSLog(@"[FULLSCREEN] Restored titlebar after exiting fullscreen (no "
            @"clients connected)");
    }
  }

  NSLog(@"[FULLSCREEN] Window exited fullscreen");
}

@end

#endif // !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

