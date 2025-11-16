#pragma once

#include <wayland-server-core.h>
#include <wayland-server.h>

struct wl_primary_selection_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

struct wl_primary_selection_manager_impl *wl_primary_selection_create(struct wl_display *display);
void wl_primary_selection_destroy(struct wl_primary_selection_manager_impl *manager);

