#pragma once

#include <wayland-server.h>
#include <wayland-util.h>

// Relative Pointer Protocol (zwp_relative_pointer_manager_v1)
// Allows clients to receive relative pointer motion events (for FPS games, etc.)

#ifndef ZWP_RELATIVE_POINTER_MANAGER_V1_INTERFACE
#define ZWP_RELATIVE_POINTER_MANAGER_V1_INTERFACE "zwp_relative_pointer_manager_v1"
#endif

#ifndef ZWP_RELATIVE_POINTER_V1_INTERFACE
#define ZWP_RELATIVE_POINTER_V1_INTERFACE "zwp_relative_pointer_v1"
#endif

// Forward declarations
struct wl_relative_pointer_manager_impl;
struct wl_relative_pointer_impl;

// Relative pointer interface
struct zwp_relative_pointer_v1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
};

// Relative pointer manager interface
struct zwp_relative_pointer_manager_v1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*get_relative_pointer)(struct wl_client *client, struct wl_resource *resource,
                                  uint32_t id, struct wl_resource *pointer);
};

// Function declarations
struct wl_relative_pointer_manager_impl *wl_relative_pointer_manager_create(struct wl_display *display);
void wl_relative_pointer_manager_destroy(struct wl_relative_pointer_manager_impl *manager);

