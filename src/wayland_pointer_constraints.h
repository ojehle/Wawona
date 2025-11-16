#pragma once

#include <wayland-server.h>
#include <wayland-util.h>

// Pointer Constraints Protocol (zwp_pointer_constraints_v1)
// Allows clients to lock or confine the pointer (for FPS games, etc.)

#ifndef ZWP_POINTER_CONSTRAINTS_V1_INTERFACE
#define ZWP_POINTER_CONSTRAINTS_V1_INTERFACE "zwp_pointer_constraints_v1"
#endif

#ifndef ZWP_LOCKED_POINTER_V1_INTERFACE
#define ZWP_LOCKED_POINTER_V1_INTERFACE "zwp_locked_pointer_v1"
#endif

#ifndef ZWP_CONFINED_POINTER_V1_INTERFACE
#define ZWP_CONFINED_POINTER_V1_INTERFACE "zwp_confined_pointer_v1"
#endif

// Forward declarations
struct wl_pointer_constraints_impl;
struct wl_locked_pointer_impl;
struct wl_confined_pointer_impl;

// Locked pointer interface
struct zwp_locked_pointer_v1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*set_cursor_position_hint)(struct wl_client *client, struct wl_resource *resource,
                                      wl_fixed_t surface_x, wl_fixed_t surface_y);
    void (*set_region)(struct wl_client *client, struct wl_resource *resource,
                       struct wl_resource *region);
};

// Confined pointer interface
struct zwp_confined_pointer_v1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*set_region)(struct wl_client *client, struct wl_resource *resource,
                        struct wl_resource *region);
};

// Pointer constraints manager interface
struct zwp_pointer_constraints_v1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*lock_pointer)(struct wl_client *client, struct wl_resource *resource,
                         uint32_t id, struct wl_resource *surface, struct wl_resource *pointer,
                         struct wl_resource *region, uint32_t lifetime);
    void (*confine_pointer)(struct wl_client *client, struct wl_resource *resource,
                            uint32_t id, struct wl_resource *surface, struct wl_resource *pointer,
                            struct wl_resource *region, uint32_t lifetime);
};

// Function declarations
struct wl_pointer_constraints_impl *wl_pointer_constraints_create(struct wl_display *display);
void wl_pointer_constraints_destroy(struct wl_pointer_constraints_impl *constraints);

