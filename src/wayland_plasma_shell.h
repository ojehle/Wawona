#pragma once

#include <wayland-server-core.h>
#include <wayland-server.h>

// Minimal Plasma Shell protocol interface definitions
struct wl_plasma_shell_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

// Minimal interface structures (stubs)
extern const struct wl_interface org_kde_plasma_shell_interface;
extern const struct wl_interface org_kde_plasma_surface_interface;

struct wl_plasma_shell_manager_impl *wl_plasma_shell_create(struct wl_display *display);
void wl_plasma_shell_destroy(struct wl_plasma_shell_manager_impl *manager);

