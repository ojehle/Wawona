#pragma once

#include <wayland-server-core.h>
#include <wayland-server.h>

// Minimal GTK Shell protocol interface definitions
// These are stub interfaces - actual protocol definitions would come from wayland-scanner

struct wl_gtk_shell_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

// Minimal interface structures (stubs)
extern const struct wl_interface gtk_shell1_interface;
extern const struct wl_interface gtk_surface1_interface;

struct wl_gtk_shell_manager_impl *wl_gtk_shell_create(struct wl_display *display);
void wl_gtk_shell_destroy(struct wl_gtk_shell_manager_impl *manager);

