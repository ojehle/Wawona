#include "wayland_protocol_stubs.h"
// Removed: Legacy C protocol headers (using Rust protocols)
// #include "../protocols/text-input-v3-protocol.h"
// #include "../protocols/text-input-v1-protocol.h"
#include <stdlib.h>
#include <string.h>

void register_protocol_stubs(struct wl_display *display) {
  (void)display;
  // Register global interfaces for protocols we want to advertise but not fully
  // implement yet
}

// NOTE: wl_decoration_create is now implemented in wayland_decoration.c

struct wl_toplevel_icon_manager_impl *
wl_toplevel_icon_create(struct wl_display *display) {
  (void)display;
  // Stub implementation - not critical
  return NULL;
}

struct wl_activation_manager_impl *
wl_activation_create(struct wl_display *display) {
  (void)display;
  return NULL;
}

struct wl_fractional_scale_manager_impl *
wl_fractional_scale_create(struct wl_display *display) {
  (void)display;
  return NULL;
}

struct wl_cursor_shape_manager_impl *
wl_cursor_shape_create(struct wl_display *display) {
  (void)display;
  return NULL;
}

// ============================================================================
// Text Input - REMOVED (using Rust protocols instead)
// All text-input v1 and v3 implementations removed
// Text input will be handled by Rust wayland-protocols crate
// ============================================================================

struct wl_text_input_manager_impl *
wl_text_input_create(struct wl_display *display) {
  (void)display;
  // Stub - text input handled by Rust
  return NULL;
}

struct wl_text_input_manager_v1_impl *
wl_text_input_v1_create(struct wl_display *display) {
  (void)display;
  // Stub - text input handled by Rust
  return NULL;
}

struct zwp_primary_selection_device_manager_v1_impl *
zwp_primary_selection_device_manager_v1_create(struct wl_display *display) {
  (void)display;
  return NULL;
}

// These are now implemented in their respective files or are truly optional
struct ext_idle_notifier_v1_impl *
ext_idle_notifier_v1_create(struct wl_display *display) {
  (void)display;
  return NULL;
}

// GTK/KDE/Qt protocols - optional, not critical for basic functionality
struct gtk_shell1_impl *gtk_shell1_create(struct wl_display *display) {
  (void)display;
  return NULL;
}
struct org_kde_plasma_shell_impl *
org_kde_plasma_shell_create(struct wl_display *display) {
  (void)display;
  return NULL;
}
struct qt_surface_extension_impl *
qt_surface_extension_create(struct wl_display *display) {
  (void)display;
  return NULL;
}
struct qt_windowmanager_impl *
qt_windowmanager_create(struct wl_display *display) {
  (void)display;
  return NULL;
}
