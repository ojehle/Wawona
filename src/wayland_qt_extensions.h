#pragma once

#include <wayland-server-core.h>
#include <wayland-server.h>

// Minimal Qt Wayland protocol interface definitions
struct wl_qt_surface_extension_impl {
    struct wl_global *global;
    struct wl_display *display;
};

struct wl_qt_windowmanager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

// Minimal interface structures (stubs)
extern const struct wl_interface qt_surface_extension_interface;
extern const struct wl_interface qt_extended_surface_interface;
extern const struct wl_interface qt_windowmanager_interface;

struct wl_qt_surface_extension_impl *wl_qt_surface_extension_create(struct wl_display *display);
void wl_qt_surface_extension_destroy(struct wl_qt_surface_extension_impl *manager);

struct wl_qt_windowmanager_impl *wl_qt_windowmanager_create(struct wl_display *display);
void wl_qt_windowmanager_destroy(struct wl_qt_windowmanager_impl *manager);

