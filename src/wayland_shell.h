#pragma once

#include <wayland-server.h>
#include <wayland-util.h>

// Legacy wl_shell protocol (deprecated but still used)
// Forward declarations
struct wl_shell_impl;
struct wl_shell_surface_impl;

// Note: wl_shell_interface, wl_shell_surface_interface, wl_shell_error enum,
// and resize enums are defined in wayland-server-protocol.h - we use those

// Event sending functions - use wl_resource_post_event directly with opcodes
// defined in wayland_shell.c (WL_SHELL_SURFACE_PING, etc.)

// Function declarations
struct wl_shell_impl *wl_shell_create(struct wl_display *display);
void wl_shell_destroy(struct wl_shell_impl *shell);

