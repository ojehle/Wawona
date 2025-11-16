#include "wayland_screencopy.h"
#include "wayland_compositor.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>
#include <string.h>

// Define interface structures (normally from wayland-scanner generated code)
// The protocol name is "zwp_screencopy_manager_v1" (zwp_ prefix for unstable protocols)
const struct wl_interface zwp_screencopy_manager_v1_interface = {
    "zwp_screencopy_manager_v1", 3,  // Protocol name clients expect
    0, NULL,
    0, NULL
};

const struct wl_interface zwp_screencopy_frame_v1_interface = {
    "zwp_screencopy_frame_v1", 3,
    0, NULL,
    0, NULL
};

// Event opcodes
#define ZWP_SCREENCOPY_FRAME_V1_BUFFER 0
#define ZWP_SCREENCOPY_FRAME_V1_READY 1
#define ZWP_SCREENCOPY_FRAME_V1_FAILED 2
#define ZWP_SCREENCOPY_FRAME_V1_DAMAGE 3

// Screencopy protocol implementation
// Allows clients to capture screen content

struct wl_screencopy_frame_impl {
    struct wl_resource *resource;
    struct wl_surface_impl *surface;
    uint32_t buffer_format;
    int32_t width, height;
    bool copied;
};

static struct wl_screencopy_frame_impl *frame_from_resource(struct wl_resource *resource) {
    return wl_resource_get_user_data(resource);
}

static void frame_copy(struct wl_client *client, struct wl_resource *resource,
                       struct wl_resource *buffer_resource) {
    (void)client;
    struct wl_screencopy_frame_impl *frame = frame_from_resource(resource);
    if (!frame) {
        return;
    }
    
    // TODO: Implement actual screen capture
    // For now, just acknowledge the request
    frame->copied = true;
    
    // Send buffer event
    wl_resource_post_event(resource, ZWP_SCREENCOPY_FRAME_V1_BUFFER,
                          WL_SHM_FORMAT_ARGB8888, frame->width, frame->height, 0);
    
    // Send ready event (tv_sec_hi, tv_sec_lo, tv_nsec)
    wl_resource_post_event(resource, ZWP_SCREENCOPY_FRAME_V1_READY, 0, 0, 0);
    
    log_printf("[SCREENCOPY] ", "frame_copy() - surface=%p, buffer=%p\n",
               (void *)frame->surface, (void *)buffer_resource);
}

static void frame_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    struct wl_screencopy_frame_impl *frame = frame_from_resource(resource);
    free(frame);
    wl_resource_destroy(resource);
}

static const struct zwp_screencopy_frame_v1_interface frame_interface = {
    .destroy = frame_destroy,
    .copy = frame_copy,
    .copy_with_damage = NULL,  // Optional
};

struct wl_screencopy_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

static void screencopy_capture_output(struct wl_client *client, struct wl_resource *resource,
                                      uint32_t overlay_cursor, struct wl_resource *output_resource) {
    (void)overlay_cursor;
    (void)output_resource;
    
    // Create frame
    struct wl_screencopy_frame_impl *frame = calloc(1, sizeof(*frame));
    if (!frame) {
        wl_client_post_no_memory(client);
        return;
    }
    
    uint32_t version = (uint32_t)wl_resource_get_version(resource);
    uint32_t id = wl_resource_get_id(resource) + 1;  // Simple ID generation
    struct wl_resource *frame_resource = wl_resource_create(client, &zwp_screencopy_frame_v1_interface, (int)version, id);
    if (!frame_resource) {
        free(frame);
        wl_client_post_no_memory(client);
        return;
    }
    
    // TODO: Get actual output size
    frame->width = 1920;
    frame->height = 1080;
    frame->resource = frame_resource;
    
    wl_resource_set_implementation(frame_resource, &frame_interface, frame, NULL);
    
    log_printf("[SCREENCOPY] ", "capture_output() - client=%p, overlay_cursor=%u\n",
               (void *)client, overlay_cursor);
}

static void screencopy_capture_output_region(struct wl_client *client, struct wl_resource *resource,
                                             uint32_t overlay_cursor, struct wl_resource *output_resource,
                                             int32_t x, int32_t y, int32_t width, int32_t height) {
    (void)overlay_cursor;
    (void)output_resource;
    
    // Create frame with region
    struct wl_screencopy_frame_impl *frame = calloc(1, sizeof(*frame));
    if (!frame) {
        wl_client_post_no_memory(client);
        return;
    }
    
    uint32_t version = (uint32_t)wl_resource_get_version(resource);
    uint32_t id = wl_resource_get_id(resource) + 1;
    struct wl_resource *frame_resource = wl_resource_create(client, &zwp_screencopy_frame_v1_interface, (int)version, id);
    if (!frame_resource) {
        free(frame);
        wl_client_post_no_memory(client);
        return;
    }
    
    frame->width = width;
    frame->height = height;
    frame->resource = frame_resource;
    
    wl_resource_set_implementation(frame_resource, &frame_interface, frame, NULL);
    
    log_printf("[SCREENCOPY] ", "capture_output_region() - x=%d, y=%d, w=%d, h=%d\n",
               x, y, width, height);
}

static const struct zwp_screencopy_manager_v1_interface screencopy_manager_interface = {
    .destroy = NULL,  // Manager doesn't have destroy
    .capture_output = screencopy_capture_output,
    .capture_output_region = screencopy_capture_output_region,
};

static void screencopy_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_screencopy_manager_impl *screencopy = data;
    
    struct wl_resource *resource = wl_resource_create(client, &zwp_screencopy_manager_v1_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &screencopy_manager_interface, screencopy, NULL);
    
    log_printf("[SCREENCOPY] ", "screencopy_bind() - client=%p, version=%u, id=%u\n",
               (void *)client, version, id);
}

struct wl_screencopy_manager_impl *wl_screencopy_manager_create(struct wl_display *display) {
    struct wl_screencopy_manager_impl *screencopy = calloc(1, sizeof(*screencopy));
    if (!screencopy) {
        return NULL;
    }
    
    screencopy->display = display;
    screencopy->global = wl_global_create(display, &zwp_screencopy_manager_v1_interface, 3, screencopy, screencopy_bind);
    
    if (!screencopy->global) {
        free(screencopy);
        return NULL;
    }
    
    log_printf("[SCREENCOPY] ", "wl_screencopy_manager_create() - global created\n");
    return screencopy;
}

void wl_screencopy_manager_destroy(struct wl_screencopy_manager_impl *screencopy) {
    if (!screencopy) {
        return;
    }
    
    if (screencopy->global) {
        wl_global_destroy(screencopy->global);
    }
    
    free(screencopy);
}

