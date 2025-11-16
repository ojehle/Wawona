#pragma once

#include <wayland-server.h>
#include <wayland-util.h>

// Pointer Gestures Protocol (zwp_pointer_gestures_v1)
// Allows clients to receive gesture events (pinch, swipe, hold)

#ifndef ZWP_POINTER_GESTURES_V1_INTERFACE
#define ZWP_POINTER_GESTURES_V1_INTERFACE "zwp_pointer_gestures_v1"
#endif

#ifndef ZWP_POINTER_GESTURE_PINCH_V1_INTERFACE
#define ZWP_POINTER_GESTURE_PINCH_V1_INTERFACE "zwp_pointer_gesture_pinch_v1"
#endif

#ifndef ZWP_POINTER_GESTURE_SWIPE_V1_INTERFACE
#define ZWP_POINTER_GESTURE_SWIPE_V1_INTERFACE "zwp_pointer_gesture_swipe_v1"
#endif

// Forward declarations
struct wl_pointer_gestures_impl;
struct wl_pointer_gesture_pinch_impl;
struct wl_pointer_gesture_swipe_impl;

// Pointer gestures manager interface
struct zwp_pointer_gestures_v1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*get_swipe_gesture)(struct wl_client *client, struct wl_resource *resource,
                              uint32_t id, struct wl_resource *pointer);
    void (*get_pinch_gesture)(struct wl_client *client, struct wl_resource *resource,
                              uint32_t id, struct wl_resource *pointer);
};

// Function declarations
struct wl_pointer_gestures_impl *wl_pointer_gestures_create(struct wl_display *display);
void wl_pointer_gestures_destroy(struct wl_pointer_gestures_impl *gestures);

