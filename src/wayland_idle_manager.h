#pragma once

#include <wayland-server-core.h>
#include <wayland-server.h>

struct wl_idle_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
    uint32_t idle_timeout; // milliseconds
};

struct wl_idle_manager_impl *wl_idle_manager_create(struct wl_display *display);
void wl_idle_manager_destroy(struct wl_idle_manager_impl *manager);
uint32_t wl_idle_manager_get_idle_timeout(struct wl_idle_manager_impl *manager);
void wl_idle_manager_set_idle_timeout(struct wl_idle_manager_impl *manager, uint32_t timeout);

