#pragma once

#include <wayland-server.h>
#include <wayland-util.h>

// Idle inhibit protocol headers

#ifndef ZWP_IDLE_INHIBIT_MANAGER_V1_INTERFACE
#define ZWP_IDLE_INHIBIT_MANAGER_V1_INTERFACE "zwp_idle_inhibit_manager_v1"
#endif

#ifndef ZWP_IDLE_INHIBITOR_V1_INTERFACE
#define ZWP_IDLE_INHIBITOR_V1_INTERFACE "zwp_idle_inhibitor_v1"
#endif

// Forward declarations
struct wl_idle_inhibit_manager_impl;
struct wl_idle_inhibitor_impl;
struct wl_surface_impl;

// Idle inhibit error codes
enum zwp_idle_inhibit_manager_v1_error {
    ZWP_IDLE_INHIBIT_MANAGER_V1_ERROR_INVALID_SURFACE = 0,
};

// Idle inhibit manager interface
struct zwp_idle_inhibit_manager_v1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*create_inhibitor)(struct wl_client *client, struct wl_resource *resource,
                            uint32_t id, struct wl_resource *surface);
};

// Idle inhibitor interface
struct zwp_idle_inhibitor_v1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
};

// Extern declarations for interfaces
extern const struct wl_interface zwp_idle_inhibit_manager_v1_interface;
extern const struct wl_interface zwp_idle_inhibitor_v1_interface;

// Function declarations
struct wl_idle_inhibit_manager_impl *wl_idle_inhibit_manager_create(struct wl_display *display);
void wl_idle_inhibit_manager_destroy(struct wl_idle_inhibit_manager_impl *manager);

