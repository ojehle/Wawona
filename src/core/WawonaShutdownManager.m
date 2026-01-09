// WawonaShutdownManager.m - Compositor shutdown management implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaShutdownManager.h"
#import "WawonaCompositor.h"
#import "../compositor_implementations/xdg_shell.h"
#import "../logging/logging.h"
#include <wayland-server-core.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

extern WawonaCompositor *g_wl_compositor_instance;

// Helper function to disconnect all clients gracefully
static void disconnect_all_clients(struct wl_display *display) {
  if (!display)
    return;

  log_printf("COMPOSITOR", "🔌 Disconnecting all clients...\n");

  // Terminate display to stop accepting new connections first
  wl_display_terminate(display);

  // Flush once to send termination signal
  wl_display_flush_clients(display);

  // Process a few events to let termination propagate
  struct wl_event_loop *eventLoop = wl_display_get_event_loop(display);
  for (int i = 0; i < 5; i++) {
    int ret = wl_event_loop_dispatch(eventLoop, 10);
    if (ret < 0)
      break;
    wl_display_flush_clients(display);
  }

  // Use the official Wayland server API to destroy all clients
  // This is the proper protocol-compliant way to disconnect all clients
  wl_display_destroy_clients(display);

  // Process events multiple times AFTER destroying clients
  // This gives clients (like waypipe) time to detect the disconnect and exit
  // gracefully
  for (int i = 0; i < 30; i++) {
    // Dispatch events with a short timeout
    int ret = wl_event_loop_dispatch(eventLoop, 50);
    if (ret < 0) {
      // Error or no more events - continue a bit more to ensure cleanup
      if (i < 15) {
        // Still process a few more times even on error to let waypipe detect
        // disconnect
        continue;
      } else {
        break;
      }
    }
    // Flush all client connections to send pending messages
    wl_display_flush_clients(display);
  }

  // Small delay to allow waypipe and other clients to fully detect disconnect
  // and exit This helps prevent "Broken pipe" errors from appearing after
  // shutdown
  usleep(100000); // 100ms delay

  // Final flush to ensure all messages are sent
  wl_display_flush_clients(display);

  log_printf("COMPOSITOR", "✅ Client disconnection complete\n");
}

@implementation WawonaShutdownManager {
  WawonaCompositor *_compositor;
}

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor {
  self = [super init];
  if (self) {
    _compositor = compositor;
  }
  return self;
}

- (void)stop {
  if (_compositor.stopped) {
    return;
  }
  _compositor.stopped = YES;
  NSLog(@"🛑 Stopping compositor backend...");

  // Clear global reference
  if (g_wl_compositor_instance == _compositor) {
    g_wl_compositor_instance = NULL;
  }

  // CRITICAL: Disconnect clients FIRST while event thread is still running
  // This ensures the event loop can properly process disconnection events
  // and send them to clients (like waypipe) so they can detect the disconnect
  if (_compositor.display) {
    disconnect_all_clients(_compositor.display);
  }

  // Now signal event thread to stop (after clients are disconnected)
  _compositor.shouldStopEventThread = YES;

  // Wait for event thread to finish (with timeout)
  if (_compositor.eventThread && [_compositor.eventThread isExecuting]) {
    // Give thread up to 1 second to finish
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while ([_compositor.eventThread isExecuting] && [timeout timeIntervalSinceNow] > 0) {
      [NSThread sleepForTimeInterval:0.01];
    }

    if ([_compositor.eventThread isExecuting]) {
      NSLog(@"⚠️ Event thread did not stop gracefully, forcing termination");
    }
  }
  _compositor.eventThread = nil;

  // Stop display link
  if (_compositor.displayLink) {
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
    [_compositor.displayLink invalidate];
#else
    CVDisplayLinkStop(_compositor.displayLink);
    CVDisplayLinkRelease(_compositor.displayLink);
#endif
    _compositor.displayLink = NULL;
  }

  // Stop frame callback timer
  if (_compositor.frame_callback_source) {
    wl_event_source_remove(_compositor.frame_callback_source);
    _compositor.frame_callback_source = NULL;
  }

  // Clean up Wayland resources
  if (_compositor.xdg_wm_base) {
    xdg_wm_base_destroy(_compositor.xdg_wm_base);
    _compositor.xdg_wm_base = NULL;
  }

  if (_compositor.shm) {
    wl_shm_destroy(_compositor.shm);
    _compositor.shm = NULL;
  }

  if (_compositor.seat) {
    wl_seat_destroy(_compositor.seat);
    _compositor.seat = NULL;
  }

  if (_compositor.output) {
    wl_output_destroy(_compositor.output);
    _compositor.output = NULL;
  }

  if (_compositor.compositor) {
    wl_compositor_destroy(_compositor.compositor);
    _compositor.compositor = NULL;
  }

  // CRITICAL: Close TCP listening socket if it exists
  // This prevents new connections from being accepted
  if (_compositor.tcp_listen_fd >= 0) {
    close(_compositor.tcp_listen_fd);
    _compositor.tcp_listen_fd = -1;
    log_printf("COMPOSITOR", "🔌 Closed TCP listening socket\n");
  }

  // CRITICAL: Destroy the display to properly close sockets and clean up
  // resources This ensures waypipe and other clients detect the disconnect
  if (_compositor.display) {
    // Destroy display (this closes all sockets and frees resources)
    wl_display_destroy(_compositor.display);
    _compositor.display = NULL;
  }

  // Clean up Unix socket file if it exists
  // This ensures waypipe doesn't think the compositor is still running
  // Note: wl_display_destroy() should close the socket, but we unlink the
  // file to ensure it's removed from the filesystem
  const char *runtime_dir = getenv("XDG_RUNTIME_DIR");
  const char *socket_name = getenv("WAYLAND_DISPLAY");
  if (runtime_dir && socket_name) {
    char socket_path[512];
    snprintf(socket_path, sizeof(socket_path), "%s/%s", runtime_dir,
             socket_name);
    if (unlink(socket_path) == 0) {
      log_printf("COMPOSITOR", "🗑️ Removed socket file: %s\n", socket_path);
    } else if (errno != ENOENT) {
      // ENOENT means file doesn't exist, which is fine (might have been
      // cleaned up already)
      log_printf("COMPOSITOR", "⚠️ Failed to remove socket file %s: %s\n",
                 socket_path, strerror(errno));
    }
  }

  cleanup_logging();
  NSLog(@"🛑 Compositor backend stopped");
}

@end

