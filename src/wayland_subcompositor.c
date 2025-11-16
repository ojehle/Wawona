#include "wayland_subcompositor.h"
#include "logging.h"
#include <wayland-server-protocol.h>
#include <wayland-server.h>
#include <stdlib.h>

static void subcompositor_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id);
static void subcompositor_destroy(struct wl_client *client, struct wl_resource *resource);
static void subcompositor_get_subsurface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface, struct wl_resource *parent);

static const struct wl_subcompositor_interface subcompositor_interface = {
    .destroy = subcompositor_destroy,
    .get_subsurface = subcompositor_get_subsurface,
};

static void subsurface_destroy(struct wl_client *client, struct wl_resource *resource);
static void subsurface_set_position(struct wl_client *client, struct wl_resource *resource, int32_t x, int32_t y);
static void subsurface_place_above(struct wl_client *client, struct wl_resource *resource, struct wl_resource *sibling);
static void subsurface_place_below(struct wl_client *client, struct wl_resource *resource, struct wl_resource *sibling);
static void subsurface_set_sync(struct wl_client *client, struct wl_resource *resource);
static void subsurface_set_desync(struct wl_client *client, struct wl_resource *resource);

static const struct wl_subsurface_interface subsurface_interface = {
    .destroy = subsurface_destroy,
    .set_position = subsurface_set_position,
    .place_above = subsurface_place_above,
    .place_below = subsurface_place_below,
    .set_sync = subsurface_set_sync,
    .set_desync = subsurface_set_desync,
};

struct wl_subcompositor_impl *wl_subcompositor_create(struct wl_display *display) {
    struct wl_subcompositor_impl *subcompositor = calloc(1, sizeof(*subcompositor));
    if (!subcompositor) return NULL;
    
    subcompositor->display = display;
    subcompositor->global = wl_global_create(display, &wl_subcompositor_interface, 1, subcompositor, subcompositor_bind);
    
    if (!subcompositor->global) {
        free(subcompositor);
        return NULL;
    }
    
    return subcompositor;
}

void wl_subcompositor_destroy(struct wl_subcompositor_impl *subcompositor) {
    if (!subcompositor) return;
    
    wl_global_destroy(subcompositor->global);
    free(subcompositor);
}

static void subcompositor_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_subcompositor_impl *subcompositor = data;
    struct wl_resource *resource = wl_resource_create(client, &wl_subcompositor_interface, (int)version, id);
    
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &subcompositor_interface, subcompositor, NULL);
    log_printf("[COMPOSITOR] ", "subcompositor_bind() - client=%p, version=%u, id=%u\n", 
               (void *)client, version, id);
}

static void subcompositor_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void subcompositor_get_subsurface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface, struct wl_resource *parent) {
    (void)client;
    (void)resource;
    (void)surface;
    (void)parent;
    
    // Minimal implementation - just create the subsurface resource
    // Full implementation would track parent-child relationships
    struct wl_resource *subsurface_resource = wl_resource_create(client, &wl_subsurface_interface, wl_resource_get_version(resource), id);
    
    if (!subsurface_resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(subsurface_resource, &subsurface_interface, NULL, NULL);
    log_printf("[COMPOSITOR] ", "subcompositor_get_subsurface() - created subsurface id=%u\n", id);
}

static void subsurface_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void subsurface_set_position(struct wl_client *client, struct wl_resource *resource, int32_t x, int32_t y) {
    (void)client;
    (void)resource;
    (void)x;
    (void)y;
    // Stub - full implementation would update subsurface position
}

static void subsurface_place_above(struct wl_client *client, struct wl_resource *resource, struct wl_resource *sibling) {
    (void)client;
    (void)resource;
    (void)sibling;
    // Stub - full implementation would reorder subsurface
}

static void subsurface_place_below(struct wl_client *client, struct wl_resource *resource, struct wl_resource *sibling) {
    (void)client;
    (void)resource;
    (void)sibling;
    // Stub - full implementation would reorder subsurface
}

static void subsurface_set_sync(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    (void)resource;
    // Stub - full implementation would set sync mode
}

static void subsurface_set_desync(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    (void)resource;
    // Stub - full implementation would set desync mode
}

