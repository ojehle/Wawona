// WawonaFrameCallbackManager.m - Frame callback timer management implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaFrameCallbackManager.h"
#import "../compositor_implementations/xdg_shell.h"
#include "../logging/logging.h"
#import "WawonaCompositor.h"
#include <errno.h>
#include <string.h>
#include <wayland-server-core.h>

// Forward declarations
extern WawonaCompositor *g_wl_compositor_instance;
extern int wl_send_frame_callbacks(void);

// Timer callback - must be C function for Wayland
static int send_frame_callbacks_timer(void *data);
static void trigger_first_frame_callback_idle(void *data);
static void ensure_frame_callback_timer_idle(void *data);
static void flush_input_and_send_frame_callbacks_idle(void *data);

//==============================================================================
// MARK: - Public C API
//==============================================================================

void wawona_frame_callback_requested(void) {
  if (!g_wl_compositor_instance)
    return;

  // This runs on the event thread - safe to create timer directly
  if (g_wl_compositor_instance.display) {
    BOOL timer_was_missing =
        (g_wl_compositor_instance.frame_callback_source == NULL);

    // Ensure timer exists - if it was missing, create it with delay 1ms to
    // fire almost immediately Using 1ms instead of 0ms because Wayland timers
    // might not fire with delay=0 Otherwise, if timer already exists, don't
    // modify it (let it fire at its scheduled time) This prevents infinite
    // loops where sending callbacks triggers immediate requests
    if (timer_was_missing) {
      log_printf("COMPOSITOR", "wawona_compositor_frame_callback_requested: "
                               "Creating timer (first frame request)\n");
      // Create timer with 16ms delay for continuous operation
      struct wl_event_loop *eventLoop =
          wl_display_get_event_loop(g_wl_compositor_instance.display);
      g_wl_compositor_instance.frame_callback_source =
          wl_event_loop_add_timer(eventLoop, send_frame_callbacks_timer,
                                  (__bridge void *)g_wl_compositor_instance);

      if (!g_wl_compositor_instance.frame_callback_source) {
        log_printf("COMPOSITOR", "wawona_compositor_frame_callback_"
                                 "requested: Failed to create timer\n");
      } else {
        log_printf("COMPOSITOR",
                   "wawona_compositor_frame_callback_requested: Timer created "
                   "successfully. Scheduling immediate fire via idle.\n");
        // Use idle callback to trigger first frame callback immediately
        // This avoids waiting 16ms for the first frame and ensures start-up
        // is snappy
        wl_event_loop_add_idle(eventLoop, trigger_first_frame_callback_idle,
                               (__bridge void *)g_wl_compositor_instance);
      }
    }
    // If timer already exists, do nothing - it will fire at its scheduled
    // interval
  }
}

void wawona_send_frame_callbacks_immediately(WawonaCompositor *compositor) {
  if (!compositor || !compositor.eventLoop) {
    return;
  }
  // Flush input events AND send frame callbacks immediately via idle
  // callback This ensures:
  // 1. Clients receive keyboard/input events immediately (via flush)
  // 2. Clients can render immediately if they have pending frame callbacks
  wl_event_loop_add_idle(compositor.eventLoop,
                         flush_input_and_send_frame_callbacks_idle,
                         (__bridge void *)compositor);
}

//==============================================================================
// MARK: - Timer Callbacks (C functions for Wayland)
//==============================================================================

// Timer callback to send frame callbacks from Wayland event thread
// This fires every ~16ms (60Hz) to match display refresh rate
static int send_frame_callbacks_timer(void *data) {
  WawonaCompositor *compositor = (__bridge WawonaCompositor *)data;
  if (!compositor) {
    log_printf(
        "[COMPOSITOR] ",
        "ERROR: send_frame_callbacks_timer called with NULL compositor!\n");
    return 0;
  }

  // This runs on the Wayland event thread - safe to call Wayland server
  // functions

  // Handle pending resize configure events first
  if (compositor.needs_resize_configure) {
    // Update wl_output mode/geometry (must be done on event thread to avoid
    // races)
    // wl_output dimensions MUST be in pixels
    if (compositor.output) {
      int32_t pixelWidth =
          compositor.pending_resize_width * compositor.pending_resize_scale;
      int32_t pixelHeight =
          compositor.pending_resize_height * compositor.pending_resize_scale;

      wl_output_update_size(compositor.output, pixelWidth, pixelHeight,
                            compositor.pending_resize_scale);
    }

    if (compositor.xdg_wm_base) {
      // Pass actual output size for storage (clients can use as hint)
      // But configure events send 0x0 to signal arbitrary resolution support
      xdg_wm_base_send_configure_to_all_toplevels(
          compositor.xdg_wm_base, compositor.pending_resize_width,
          compositor.pending_resize_height);
    }
    compositor.needs_resize_configure = NO;
  }

  // Send frame callbacks
  wl_send_frame_callbacks();

  // CRITICAL: Flush clients to ensure frame callbacks are sent immediately
  // This wakes up clients waiting on wl_display_dispatch()
  wl_display_flush_clients(compositor.display);

  // CRITICAL: Re-arm timer for next frame (16ms = 60Hz)
  // Always re-arm to keep timer firing continuously
  if (compositor.frame_callback_source) {
    int ret =
        wl_event_source_timer_update(compositor.frame_callback_source, 16);
    if (ret < 0) {
      int err = errno;
      log_printf("COMPOSITOR",
                 "send_frame_callbacks_timer: Failed to re-arm timer: %s\n",
                 strerror(err));
      // Timer update failed - recreate it
      wl_event_source_remove(compositor.frame_callback_source);
      compositor.frame_callback_source = NULL;

      struct wl_event_loop *eventLoop =
          wl_display_get_event_loop(compositor.display);
      compositor.frame_callback_source = wl_event_loop_add_timer(
          eventLoop, send_frame_callbacks_timer, (__bridge void *)compositor);
      if (compositor.frame_callback_source) {
        wl_event_source_timer_update(compositor.frame_callback_source, 16);
      }
    }
  } else {
    // Timer was removed - recreate it immediately
    struct wl_event_loop *eventLoop =
        wl_display_get_event_loop(compositor.display);
    compositor.frame_callback_source = wl_event_loop_add_timer(
        eventLoop, send_frame_callbacks_timer, (__bridge void *)compositor);
    if (compositor.frame_callback_source) {
      wl_event_source_timer_update(compositor.frame_callback_source, 16);
    }
  }

  // Return 0 to indicate timer callback completed
  // We manually re-arm above, so timer will continue firing
  return 0;
}

// Idle helper to trigger first frame callback immediately
static void trigger_first_frame_callback_idle(void *data) {
  WawonaCompositor *compositor = (__bridge WawonaCompositor *)data;
  if (compositor) {
    // Manually call the timer function
    // This will send callbacks and re-arm the timer for the next frame (16ms
    // later)
    send_frame_callbacks_timer(data);
  }
}

// Idle helper to (re)arm the timer from threads other than the event thread
static void ensure_frame_callback_timer_idle(void *data) {
  WawonaCompositor *compositor = (__bridge WawonaCompositor *)data;
  if (compositor && compositor.display) {
    struct wl_event_loop *eventLoop =
        wl_display_get_event_loop(compositor.display);
    if (!compositor.frame_callback_source) {
      compositor.frame_callback_source = wl_event_loop_add_timer(
          eventLoop, send_frame_callbacks_timer, (__bridge void *)compositor);
    }
    if (compositor.frame_callback_source) {
      wl_event_source_timer_update(compositor.frame_callback_source, 16);
    }
  }
}

// Idle helper to flush input events and trigger frame callback immediately
static void flush_input_and_send_frame_callbacks_idle(void *data) {
  WawonaCompositor *compositor = (__bridge WawonaCompositor *)data;
  if (compositor) {
    // CRITICAL: Flush clients immediately so they receive keyboard/input
    // events This wakes up clients waiting on wl_display_dispatch() so they
    // can process input
    wl_display_flush_clients(compositor.display);

    // Send frame callbacks immediately if any are pending
    // This allows clients to render immediately after processing input
    if (wl_has_pending_frame_callbacks()) {
      send_frame_callbacks_timer(data);
    }
  }
}

//==============================================================================
// MARK: - WawonaFrameCallbackManager Implementation
//==============================================================================

@interface WawonaFrameCallbackManager ()
@property(nonatomic, weak) WawonaCompositor *compositor;
@end

@implementation WawonaFrameCallbackManager

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor {
  self = [super init];
  if (self) {
    self.compositor = compositor;
  }
  return self;
}

- (BOOL)ensureTimerOnEventThreadWithDelay:(uint32_t)delayMs
                                   reason:(const char *)reason {
  WawonaCompositor *compositor = self.compositor;
  if (!compositor || !compositor.display) {
    return NO;
  }

  struct wl_event_loop *eventLoop =
      wl_display_get_event_loop(compositor.display);
  if (!eventLoop) {
    log_printf("COMPOSITOR", "ensure_frame_callback_timer_on_event_thread: "
                             "event loop unavailable\n");
    return NO;
  }

  if (!compositor.frame_callback_source) {
    compositor.frame_callback_source = wl_event_loop_add_timer(
        eventLoop, send_frame_callbacks_timer, (__bridge void *)compositor);
    if (!compositor.frame_callback_source) {
      log_printf("COMPOSITOR",
                 "ensure_frame_callback_timer_on_event_thread: Failed to "
                 "create timer (%s)\n",
                 reason ? reason : "no reason");
      return NO;
    }
    log_printf("COMPOSITOR",
               "ensure_frame_callback_timer_on_event_thread: Created timer "
               "(%s, delay=%ums)\n",
               reason ? reason : "no reason", delayMs);
  }

  // CRITICAL: Always update timer delay to schedule it
  // If delay is 0, we want immediate execution - but Wayland timers might not
  // fire immediately So use a small delay (1ms) to ensure it fires in the
  // next event loop iteration
  uint32_t actual_delay = (delayMs == 0) ? 1 : delayMs;
  int ret = wl_event_source_timer_update(compositor.frame_callback_source,
                                         actual_delay);
  if (ret < 0) {
    int err = errno;
    log_printf("COMPOSITOR",
               "ensure_frame_callback_timer_on_event_thread: timer update "
               "failed (%s, delay=%ums) - recreating\n",
               strerror(err), delayMs);
    wl_event_source_remove(compositor.frame_callback_source);
    compositor.frame_callback_source = NULL;

    compositor.frame_callback_source = wl_event_loop_add_timer(
        eventLoop, send_frame_callbacks_timer, (__bridge void *)compositor);
    if (!compositor.frame_callback_source) {
      log_printf("COMPOSITOR", "ensure_frame_callback_timer_on_event_thread:"
                               " Failed to recreate timer after error\n");
      return NO;
    }

    ret =
        wl_event_source_timer_update(compositor.frame_callback_source, delayMs);
    if (ret < 0) {
      err = errno;
      log_printf("COMPOSITOR",
                 "ensure_frame_callback_timer_on_event_thread: Second timer "
                 "update failed (%s)\n",
                 strerror(err));
      wl_event_source_remove(compositor.frame_callback_source);
      compositor.frame_callback_source = NULL;
      return NO;
    }

    log_printf("COMPOSITOR", "ensure_frame_callback_timer_on_event_thread: "
                             "Timer recreated successfully\n");
  }
  return YES;
}

- (void)sendFrameCallbacks {
  if (self.compositor) {
    send_frame_callbacks_timer((__bridge void *)self.compositor);
  }
}

- (void)processPendingResizeConfigure {
  WawonaCompositor *compositor = self.compositor;
  if (!compositor || !compositor.needs_resize_configure) {
    return;
  }

  // Update wl_output mode/geometry (must be done on event thread to avoid
  // races)
  if (compositor.output) {
    int32_t pixelWidth =
        compositor.pending_resize_width * compositor.pending_resize_scale;
    int32_t pixelHeight =
        compositor.pending_resize_height * compositor.pending_resize_scale;

    wl_output_update_size(compositor.output, pixelWidth, pixelHeight,
                          compositor.pending_resize_scale);
  }

  if (compositor.xdg_wm_base) {
    xdg_wm_base_send_configure_to_all_toplevels(
        compositor.xdg_wm_base, compositor.pending_resize_width,
        compositor.pending_resize_height);
  }

  compositor.needs_resize_configure = NO;
}

@end
