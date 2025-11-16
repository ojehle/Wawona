#pragma once

#include <wayland-server-core.h>
#include <wayland-server.h>

struct wl_keyboard_shortcuts_inhibit_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

struct wl_keyboard_shortcuts_inhibit_manager_impl *wl_keyboard_shortcuts_create(struct wl_display *display);
void wl_keyboard_shortcuts_destroy(struct wl_keyboard_shortcuts_inhibit_manager_impl *manager);

