#include "wayland_relative_pointer.h"
#include "wayland_seat.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>
#include <string.h>

// Define interface structures
const struct wl_interface zwp_relative_pointer_manager_v1_interface = {
    "zwp_relative_pointer_manager_v1", 1,
    0, NULL,
    0, NULL
};

const struct wl_interface zwp_relative_pointer_v1_interface = {
    "zwp_relative_pointer_v1", 1,
    0, NULL,
    0, NULL
};

// Minimal stub implementation for relative pointer
// Full implementation would track relative mouse motion and send events to clients

struct wl_relative_pointer_impl {
    struct wl_resource *resource;
    struct wl_resource *pointer_resource;
};

struct wl_relative_pointer_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

static void relative_pointer_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    struct wl_relative_pointer_impl *relative_pointer = wl_resource_get_user_data(resource);
    if (relative_pointer) {
        free(relative_pointer);
    }
    wl_resource_destroy(resource);
}

static const struct zwp_relative_pointer_v1_interface relative_pointer_interface = {
    .destroy = relative_pointer_destroy,
};

static void relative_pointer_manager_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void relative_pointer_manager_get_relative_pointer(struct wl_client *client, struct wl_resource *resource,
                                                           uint32_t id, struct wl_resource *pointer) {
    struct wl_relative_pointer_impl *relative_pointer = calloc(1, sizeof(*relative_pointer));
    if (!relative_pointer) {
        wl_client_post_no_memory(client);
        return;
    }
    
    uint32_t version = (uint32_t)wl_resource_get_version(resource);
    struct wl_resource *relative_pointer_resource = wl_resource_create(client, &zwp_relative_pointer_v1_interface, (int)version, id);
    if (!relative_pointer_resource) {
        free(relative_pointer);
        wl_client_post_no_memory(client);
        return;
    }
    
    relative_pointer->resource = relative_pointer_resource;
    relative_pointer->pointer_resource = pointer;
    
    wl_resource_set_implementation(relative_pointer_resource, &relative_pointer_interface, relative_pointer, NULL);
    
    log_printf("[RELATIVE_POINTER] ", "get_relative_pointer() - client=%p, id=%u (stub)\n",
               (void *)client, id);
    // TODO: Track relative motion and send motion events
}

static const struct zwp_relative_pointer_manager_v1_interface relative_pointer_manager_interface = {
    .destroy = relative_pointer_manager_destroy,
    .get_relative_pointer = relative_pointer_manager_get_relative_pointer,
};

static void relative_pointer_manager_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_relative_pointer_manager_impl *manager = data;
    
    struct wl_resource *resource = wl_resource_create(client, &zwp_relative_pointer_manager_v1_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &relative_pointer_manager_interface, manager, NULL);
    
    log_printf("[RELATIVE_POINTER] ", "relative_pointer_manager_bind() - client=%p, version=%u, id=%u\n",
               (void *)client, version, id);
}

struct wl_relative_pointer_manager_impl *wl_relative_pointer_manager_create(struct wl_display *display) {
    struct wl_relative_pointer_manager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) {
        return NULL;
    }
    
    manager->display = display;
    manager->global = wl_global_create(display, &zwp_relative_pointer_manager_v1_interface, 1, manager, relative_pointer_manager_bind);
    
    if (!manager->global) {
        free(manager);
        return NULL;
    }
    
    log_printf("[RELATIVE_POINTER] ", "wl_relative_pointer_manager_create() - global created\n");
    return manager;
}

void wl_relative_pointer_manager_destroy(struct wl_relative_pointer_manager_impl *manager) {
    if (!manager) {
        return;
    }
    
    if (manager->global) {
        wl_global_destroy(manager->global);
    }
    
    free(manager);
}

