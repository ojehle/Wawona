// WawonaProtocolSetup.m - Wayland protocol initialization implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaProtocolSetup.h"
#import "WawonaCompositor.h"
#import "../ui/Settings/WawonaPreferencesManager.h"
#include "../compositor_implementations/wayland_fullscreen_shell.h"
#include "../compositor_implementations/wayland_linux_dmabuf.h"
#include "../compositor_implementations/wayland_decoration.h"
#include "../compositor_implementations/wayland_output.h"
#include "../compositor_implementations/wayland_presentation.h"
#include "../compositor_implementations/wayland_shm.h"
#include "../compositor_implementations/wayland_subcompositor.h"
#include "../compositor_implementations/xdg_shell.h"
#include "../compositor_implementations/wayland_data_device_manager.h"
#include "../compositor_implementations/wayland_color_management.h"
#include "../input/wayland_seat.h"
// Note: Some protocol headers don't exist yet - commented out until implemented
// #include "../compositor_implementations/wayland_text_input.h"
// #include "../compositor_implementations/wayland_text_input_v1.h"
#include "../compositor_implementations/wayland_primary_selection.h"
// #include "../compositor_implementations/wayland_toplevel_icon.h"
// #include "../compositor_implementations/wayland_activation.h"
// #include "../compositor_implementations/wayland_fractional_scale.h"
// #include "../compositor_implementations/wayland_cursor_shape.h"
#include "../compositor_implementations/wayland_viewporter.h"
#include "../compositor_implementations/wayland_shell.h"
#include "../compositor_implementations/wayland_screencopy.h"
#include "../compositor_implementations/wayland_drm.h"
#include "../compositor_implementations/wayland_idle_inhibit.h"
#include "../compositor_implementations/wayland_pointer_gestures.h"
#include "../compositor_implementations/wayland_relative_pointer.h"
#include "../compositor_implementations/wayland_pointer_constraints.h"
#include "../compositor_implementations/wayland_tablet.h"
// Note: These protocol headers don't exist yet - commented out until implemented
// #include "../compositor_implementations/wayland_idle_notifier.h"
// #include "../compositor_implementations/wayland_keyboard_shortcuts_inhibit.h"
// #include "../compositor_implementations/gtk_shell.h"
// #include "../compositor_implementations/plasma_shell.h"
// #include "../compositor_implementations/qt_surface_extension.h"
// #include "../compositor_implementations/qt_windowmanager.h"

@implementation WawonaProtocolSetup {
  WawonaCompositor *_compositor;
}

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor {
  self = [super init];
  if (self) {
    _compositor = compositor;
  }
  return self;
}

- (BOOL)setupProtocols {
  struct wl_display *display = _compositor.display;
  
  // Create xdg_wm_base
  _compositor.xdg_wm_base = xdg_wm_base_create(display);
  if (!_compositor.xdg_wm_base) {
    NSLog(@"❌ Failed to create xdg_wm_base");
    return NO;
  }
  // Set initial output size
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
  CGRect initialFrame = _compositor.window.bounds;
#else
  NSRect initialFrame = [_compositor.window.contentView bounds];
#endif
  xdg_wm_base_set_output_size(_compositor.xdg_wm_base, (int32_t)initialFrame.size.width,
                              (int32_t)initialFrame.size.height);
  NSLog(@"   ✓ xdg_wm_base created");

  // Create optional protocol implementations to satisfy client requirements
  // These are minimal stubs - full implementations can be added later

  // Primary selection protocol
  struct wp_primary_selection_device_manager_impl *primary_selection =
      wp_primary_selection_device_manager_create(display);
  if (primary_selection) {
    NSLog(@"   ✓ Primary selection protocol created");
  }

  // Decoration manager protocol (Available on both iOS and macOS)
  struct wl_decoration_manager_impl *decoration =
      wl_decoration_create(display);
  if (decoration) {
    _compositor.decoration_manager = decoration;
    NSLog(@"   ✓ Decoration manager protocol created");
  }

  // Toplevel icon protocol
  // Note: This protocol is not yet implemented - commented out
  // struct wl_toplevel_icon_manager_impl *toplevel_icon =
  //     wl_toplevel_icon_create(display);
  // if (toplevel_icon) {
  //   NSLog(@"   ✓ Toplevel icon protocol created");
  // }
  struct wl_toplevel_icon_manager_impl *toplevel_icon = NULL;
  (void)toplevel_icon; // Suppress unused variable warning

  // XDG activation protocol
  // Note: This protocol is not yet implemented - commented out
  // struct wl_activation_manager_impl *activation =
  //     wl_activation_create(display);
  // if (activation) {
  //   NSLog(@"   ✓ XDG activation protocol created");
  // }
  struct wl_activation_manager_impl *activation = NULL;
  (void)activation; // Suppress unused variable warning

  // Fractional scale protocol
  // Note: This protocol is not yet implemented - commented out
  // struct wl_fractional_scale_manager_impl *fractional_scale =
  //     wl_fractional_scale_create(display);
  // if (fractional_scale) {
  //   NSLog(@"   ✓ Fractional scale protocol created");
  // }
  struct wl_fractional_scale_manager_impl *fractional_scale = NULL;
  (void)fractional_scale; // Suppress unused variable warning

  // Cursor shape protocol
  // Note: This protocol is not yet implemented - commented out
  // struct wl_cursor_shape_manager_impl *cursor_shape =
  //     wl_cursor_shape_create(display);
  // if (cursor_shape) {
  //   NSLog(@"   ✓ Cursor shape protocol created");
  // }
  struct wl_cursor_shape_manager_impl *cursor_shape = NULL;
  (void)cursor_shape; // Suppress unused variable warning

  // Text input protocol v3
  // Note: This protocol is not yet implemented - commented out
  // struct wl_text_input_manager_impl *text_input =
  //     wl_text_input_create(display);
  // if (text_input && text_input->global) {
  //   _compositor.text_input_manager = text_input; // Store to keep it alive
  //   NSLog(@"   ✓ Text input protocol v3 created");
  // } else {
  //   _compositor.text_input_manager = NULL;
  // }
  _compositor.text_input_manager = NULL; // Set to NULL since protocol not implemented

  // Text input protocol v1 (for weston-editor compatibility)
  // Note: This protocol is not yet implemented - commented out
  // struct wl_text_input_manager_v1_impl *text_input_v1 =
  //     wl_text_input_v1_create(display);
  // if (text_input_v1 && text_input_v1->global) {
  //   NSLog(@"   ✓ Text input protocol v1 created");
  // }

  // EGL disabled - Vulkan only
  NSLog(@"   ✓ EGL disabled - Vulkan only mode");

  // Viewporter protocol (critical for Weston compatibility)
  struct wp_viewporter_impl *viewporter = wp_viewporter_create(display);
  if (viewporter) {
    NSLog(@"   ✓ Viewporter protocol created");
  }

  // Shell protocol (legacy compatibility)
  struct wl_shell_impl *shell = wl_shell_create(display);
  if (shell) {
    NSLog(@"   ✓ Shell protocol created");
  }

  // Screencopy protocol (screen capture)
  struct zwlr_screencopy_manager_v1_impl *screencopy =
      zwlr_screencopy_manager_v1_create(display);
  if (screencopy) {
    NSLog(@"   ✓ Screencopy protocol created");
  }

  // Linux DMA-BUF protocol (critical for wlroots and hardware-accelerated
  // clients) Check preference - this allows toggle between IOSurface-backed
  // dmabuf (enabled) and CPU-based H264 waypipe fallback (disabled)
  // Disabled on macOS due to Vulkan compatibility issues with KosmicKrisp
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
  WawonaPreferencesManager *prefsManager =
      [WawonaPreferencesManager sharedManager];
  if ([prefsManager dmabufEnabled]) {
    struct zwp_linux_dmabuf_v1_impl *linux_dmabuf =
        zwp_linux_dmabuf_v1_create(display);
    if (linux_dmabuf) {
      NSLog(@"   ✓ Linux DMA-BUF protocol created (IOSurface-backed, nearly "
            @"zero-copy)");
    }
  } else {
    NSLog(@"   ⊘ Linux DMA-BUF protocol disabled (using CPU-based H264 waypipe "
          @"fallback)");
  }
#else
  NSLog(@"   ⊘ Linux DMA-BUF protocol disabled on macOS (Vulkan compatibility "
        @"issues)");
#endif

  // wl_drm protocol (for EGL fallback when dmabuf feedback doesn't provide
  // render node)
  struct wl_drm_impl *wl_drm = wl_drm_create(display);
  if (wl_drm) {
    NSLog(@"   ✓ wl_drm protocol created (stub for macOS EGL compatibility)");
  }

  // Idle inhibit protocol (prevent screensaver)
  struct zwp_idle_inhibit_manager_v1_impl *idle_inhibit =
      zwp_idle_inhibit_manager_v1_create(display);
  if (idle_inhibit) {
    NSLog(@"   ✓ Idle inhibit protocol created");
  }

  // Pointer gestures protocol (trackpad gestures)
  struct zwp_pointer_gestures_v1_impl *pointer_gestures =
      zwp_pointer_gestures_v1_create(display);
  if (pointer_gestures) {
    NSLog(@"   ✓ Pointer gestures protocol created");
  }

  // Relative pointer protocol (relative motion for games)
  struct zwp_relative_pointer_manager_v1_impl *relative_pointer =
      zwp_relative_pointer_manager_v1_create(display);
  if (relative_pointer) {
    NSLog(@"   ✓ Relative pointer protocol created");
  }

  // Pointer constraints protocol (pointer locking/confining for games)
  struct zwp_pointer_constraints_v1_impl *pointer_constraints =
      zwp_pointer_constraints_v1_create(display);
  if (pointer_constraints) {
    NSLog(@"   ✓ Pointer constraints protocol created");
  }

  // Register additional protocols
  struct zwp_tablet_manager_v2_impl *tablet =
      zwp_tablet_manager_v2_create(display);
  (void)tablet; // Suppress unused variable warning
  NSLog(@"   ✓ Tablet protocol created");

  // Note: These protocols are not yet implemented - commented out
  // struct ext_idle_notifier_v1_impl *idle_manager =
  //     ext_idle_notifier_v1_create(display);
  // (void)idle_manager; // Suppress unused variable warning
  // NSLog(@"   ✓ Idle manager protocol created");

  // struct zwp_keyboard_shortcuts_inhibit_manager_v1_impl *keyboard_shortcuts =
  //     zwp_keyboard_shortcuts_inhibit_manager_v1_create(display);
  // (void)keyboard_shortcuts; // Suppress unused variable warning
  // NSLog(@"   ✓ Keyboard shortcuts inhibit protocol created");

  // CRITICAL: Initialize fullscreen shell BEFORE xdg_wm_base
  // Weston checks for arbitrary resolution support early, so fullscreen shell
  // must be available when it connects
  wayland_fullscreen_shell_init(display);
  NSLog(@"   ✓ Fullscreen shell protocol created (for arbitrary resolution "
        @"support)");

  // GTK Shell protocol (for GTK applications) - optional
  // Note: This protocol is not yet implemented - commented out
  // struct gtk_shell1_impl *gtk_shell = gtk_shell1_create(display);
  // if (gtk_shell) {
  //   NSLog(@"   ✓ GTK Shell protocol created");
  // }

  // Plasma Shell protocol (for KDE applications) - optional
  // Note: This protocol is not yet implemented - commented out
  // struct org_kde_plasma_shell_impl *plasma_shell =
  //     org_kde_plasma_shell_create(display);
  // (void)plasma_shell; // Suppress unused variable warning
  // if (plasma_shell) {
  //   NSLog(@"   ✓ Plasma Shell protocol created");
  // }

  // Presentation time protocol (for accurate presentation timing feedback)
  struct wp_presentation_impl *presentation = wp_presentation_create(display);
  if (presentation) {
    NSLog(@"   ✓ Presentation time protocol created");
  }

  // Color management protocol (for color operations and HDR support)
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
  _compositor.color_manager = wp_color_manager_create(display, _compositor.output);
  if (_compositor.color_manager) {
    NSLog(@"   ✓ Color management protocol created (HDR: %s)",
          _compositor.color_manager->hdr_supported ? "yes" : "no");
  }
#endif

  // Qt Wayland Extensions (for QtWayland applications) - optional
  // Note: These protocols are not yet implemented - commented out
  // struct qt_surface_extension_impl *qt_surface =
  //     qt_surface_extension_create(display);
  // if (qt_surface) {
  //   NSLog(@"   ✓ Qt Surface Extension protocol created");
  // }
  // struct qt_windowmanager_impl *qt_wm = qt_windowmanager_create(display);
  // if (qt_wm) {
  //   NSLog(@"   ✓ Qt Window Manager protocol created");
  // }

  return YES;
}

@end

