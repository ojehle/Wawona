#pragma once
// STUB: This file is a compatibility stub
// Legacy C protocol files have been removed - project now uses Rust protocols
// only See src/core/wayland/protocol/ for Rust protocol implementations

#include <stdbool.h>
#include <stdint.h>
#include <wayland-server-protocol.h>
#include <wayland-server.h>

// Stub structures - kept for compatibility with macOS code
// Real protocol handling is done in Rust via src/core/wayland/protocol/

struct xdg_wm_base_impl {
  void *stub;
};

struct xdg_surface_impl {
  void *stub;
  struct wl_resource *resource;
  struct wl_surface_impl *wl_surface;
  uint32_t configure_serial;
  bool has_geometry;
  int32_t geometry_x;
  int32_t geometry_y;
  int32_t geometry_width;
  int32_t geometry_height;
};

struct xdg_toplevel_impl {
  void *stub;
  char *title;
  char *app_id;
  void *native_window;
  uint32_t decoration_mode; // Added: referenced by WawonaCompositorView_macos.m
  struct wl_resource *resource; // Added: referenced by WawonaSurfaceManager.m
  struct xdg_surface_impl
      *xdg_surface;      // Added: referenced by WawonaSurfaceManager.m
  int32_t width;         // Added: referenced by WawonaSurfaceManager.m
  int32_t height;        // Added: referenced by WawonaSurfaceManager.m
  void *decoration_data; // Added: for decoration protocol
};

struct xdg_popup_impl {
  void *stub;
};

// Stub declarations - macOS code may reference these
void *xdg_wm_base_create(void *display);
void xdg_wm_base_destroy(void *wm_base);
void xdg_wm_base_send_configure_to_all_toplevels(void *wm_base, int32_t width,
                                                 int32_t height);
void xdg_wm_base_set_output_size(void *wm_base, int32_t width, int32_t height);
struct xdg_toplevel_impl *
xdg_surface_get_toplevel_from_wl_surface(struct wl_surface_impl *wl_surface);

// Protocol send function stubs (needed for linking)
void xdg_surface_send_configure(struct wl_resource *resource, uint32_t serial);
struct wl_array; // Forward declare
void xdg_toplevel_send_configure(struct wl_resource *resource, int32_t width,
                                 int32_t height, struct wl_array *states);
void xdg_toplevel_send_close(struct wl_resource *resource);
void xdg_toplevel_send_configure_bounds(struct wl_resource *resource,
                                        int32_t width, int32_t height);
