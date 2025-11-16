#include "wayland_idle_inhibit.h"
#include "wayland_compositor.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>
#include <string.h>

// Define interface structures
const struct wl_interface zwp_idle_inhibit_manager_v1_interface = {
    "zwp_idle_inhibit_manager_v1", 1,
    0, NULL,
    0, NULL
};

const struct wl_interface zwp_idle_inhibitor_v1_interface = {
    "zwp_idle_inhibitor_v1", 1,
    0, NULL,
    0, NULL
};

// Idle inhibit protocol implementation
// Allows clients to prevent screensaver/idle

struct wl_idle_inhibitor_impl {
    struct wl_resource *resource;
    struct wl_surface_impl *surface;
    bool active;
};

static struct wl_idle_inhibitor_impl *inhibitor_from_resource(struct wl_resource *resource) {
    return wl_resource_get_user_data(resource);
}

static void inhibitor_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    struct wl_idle_inhibitor_impl *inhibitor = inhibitor_from_resource(resource);
    if (inhibitor) {
        // TODO: Disable idle inhibition
        inhibitor->active = false;
    }
    free(inhibitor);
    wl_resource_destroy(resource);
}

static const struct zwp_idle_inhibitor_v1_interface inhibitor_interface = {
    .destroy = inhibitor_destroy,
};

struct wl_idle_inhibit_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

static void idle_inhibit_create_inhibitor(struct wl_client *client, struct wl_resource *resource,
                                         uint32_t id, struct wl_resource *surface_resource) {
    struct wl_surface_impl *surface = wl_resource_get_user_data(surface_resource);
    if (!surface) {
        wl_resource_post_error(resource, ZWP_IDLE_INHIBIT_MANAGER_V1_ERROR_INVALID_SURFACE,
                              "invalid surface");
        return;
    }
    
    struct wl_idle_inhibitor_impl *inhibitor = calloc(1, sizeof(*inhibitor));
    if (!inhibitor) {
        wl_client_post_no_memory(client);
        return;
    }
    
    uint32_t version = (uint32_t)wl_resource_get_version(resource);
    struct wl_resource *inhibitor_resource = wl_resource_create(client, &zwp_idle_inhibitor_v1_interface, (int)version, id);
    if (!inhibitor_resource) {
        free(inhibitor);
        wl_client_post_no_memory(client);
        return;
    }
    
    inhibitor->resource = inhibitor_resource;
    inhibitor->surface = surface;
    inhibitor->active = true;
    
    wl_resource_set_implementation(inhibitor_resource, &inhibitor_interface, inhibitor, NULL);
    
    // TODO: Actually prevent screensaver/idle on macOS
    // This would use IOKit or similar macOS APIs
    
    log_printf("[IDLE_INHIBIT] ", "create_inhibitor() - client=%p, surface=%p\n",
               (void *)client, (void *)surface);
}

static const struct zwp_idle_inhibit_manager_v1_interface idle_inhibit_manager_interface = {
    .destroy = NULL,  // Manager doesn't have destroy
    .create_inhibitor = idle_inhibit_create_inhibitor,
};

static void idle_inhibit_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_idle_inhibit_manager_impl *manager = data;
    
    struct wl_resource *resource = wl_resource_create(client, &zwp_idle_inhibit_manager_v1_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &idle_inhibit_manager_interface, manager, NULL);
    
    log_printf("[IDLE_INHIBIT] ", "idle_inhibit_bind() - client=%p, version=%u, id=%u\n",
               (void *)client, version, id);
}

struct wl_idle_inhibit_manager_impl *wl_idle_inhibit_manager_create(struct wl_display *display) {
    struct wl_idle_inhibit_manager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) {
        return NULL;
    }
    
    manager->display = display;
    manager->global = wl_global_create(display, &zwp_idle_inhibit_manager_v1_interface, 1, manager, idle_inhibit_bind);
    
    if (!manager->global) {
        free(manager);
        return NULL;
    }
    
    log_printf("[IDLE_INHIBIT] ", "wl_idle_inhibit_manager_create() - global created\n");
    return manager;
}

void wl_idle_inhibit_manager_destroy(struct wl_idle_inhibit_manager_impl *manager) {
    if (!manager) {
        return;
    }
    
    if (manager->global) {
        wl_global_destroy(manager->global);
    }
    
    free(manager);
}

