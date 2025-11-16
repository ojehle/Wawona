#pragma once

#include <wayland-server-core.h>
#include <wayland-server.h>

struct wl_output_impl {
    struct wl_global *global;
    struct wl_display *display;
    
    int32_t width, height;
    int32_t scale;
    int32_t transform;
    int32_t refresh_rate;
    const char *name;
    const char *description;
};

struct wl_output_impl *wl_output_create(struct wl_display *display, int32_t width, int32_t height, const char *name);
void wl_output_destroy(struct wl_output_impl *output);
void wl_output_update_size(struct wl_output_impl *output, int32_t width, int32_t height);

