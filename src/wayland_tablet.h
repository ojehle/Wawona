#pragma once

#include <wayland-server-core.h>
#include <wayland-server.h>

struct wl_tablet_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

struct wl_tablet_manager_impl *wl_tablet_create(struct wl_display *display);
void wl_tablet_destroy(struct wl_tablet_manager_impl *manager);

