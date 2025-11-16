#include "wayland_data_device_manager.h"
#include "logging.h"
#include <wayland-server-protocol.h>
#include <wayland-server.h>
#include <stdlib.h>

static void data_device_manager_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id);
static void data_device_manager_create_data_source(struct wl_client *client, struct wl_resource *resource, uint32_t id);
static void data_device_manager_get_data_device(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *seat);

static const struct wl_data_device_manager_interface data_device_manager_interface = {
    .create_data_source = data_device_manager_create_data_source,
    .get_data_device = data_device_manager_get_data_device,
};

static void data_source_offer(struct wl_client *client, struct wl_resource *resource, const char *mime_type);
static void data_source_destroy_request(struct wl_client *client, struct wl_resource *resource);
static void data_source_set_actions(struct wl_client *client, struct wl_resource *resource, uint32_t dnd_actions);

static const struct wl_data_source_interface data_source_interface = {
    .offer = data_source_offer,
    .destroy = data_source_destroy_request,
    .set_actions = data_source_set_actions,
};

static void data_device_start_drag(struct wl_client *client, struct wl_resource *resource, struct wl_resource *source, struct wl_resource *origin, struct wl_resource *icon, uint32_t serial);
static void data_device_set_selection(struct wl_client *client, struct wl_resource *resource, struct wl_resource *source, uint32_t serial);
static void data_device_release(struct wl_client *client, struct wl_resource *resource);

static const struct wl_data_device_interface data_device_interface = {
    .start_drag = data_device_start_drag,
    .set_selection = data_device_set_selection,
    .release = data_device_release,
};

struct wl_data_device_manager_impl *wl_data_device_manager_create(struct wl_display *display) {
    struct wl_data_device_manager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) return NULL;
    
    manager->display = display;
    manager->global = wl_global_create(display, &wl_data_device_manager_interface, 3, manager, data_device_manager_bind);
    
    if (!manager->global) {
        free(manager);
        return NULL;
    }
    
    return manager;
}

void wl_data_device_manager_destroy(struct wl_data_device_manager_impl *manager) {
    if (!manager) return;
    
    wl_global_destroy(manager->global);
    free(manager);
}

static void data_device_manager_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_data_device_manager_impl *manager = data;
    struct wl_resource *resource = wl_resource_create(client, &wl_data_device_manager_interface, (int)version, id);
    
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &data_device_manager_interface, manager, NULL);
    log_printf("[COMPOSITOR] ", "data_device_manager_bind() - client=%p, version=%u, id=%u\n", 
               (void *)client, version, id);
}

static void data_device_manager_create_data_source(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    struct wl_resource *source_resource = wl_resource_create(client, &wl_data_source_interface, wl_resource_get_version(resource), id);
    
    if (!source_resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(source_resource, &data_source_interface, NULL, NULL);
    log_printf("[COMPOSITOR] ", "data_device_manager_create_data_source() - created source id=%u\n", id);
}

static void data_device_manager_get_data_device(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *seat) {
    (void)seat;
    struct wl_resource *device_resource = wl_resource_create(client, &wl_data_device_interface, wl_resource_get_version(resource), id);
    
    if (!device_resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(device_resource, &data_device_interface, NULL, NULL);
    log_printf("[COMPOSITOR] ", "data_device_manager_get_data_device() - created device id=%u\n", id);
}

static void data_source_offer(struct wl_client *client, struct wl_resource *resource, const char *mime_type) {
    (void)client;
    (void)resource;
    (void)mime_type;
    // Stub - full implementation would track MIME types
}

static void data_source_destroy_request(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void data_source_set_actions(struct wl_client *client, struct wl_resource *resource, uint32_t dnd_actions) {
    (void)client;
    (void)resource;
    (void)dnd_actions;
    // Stub - full implementation would track drag-and-drop actions
}

static void data_device_start_drag(struct wl_client *client, struct wl_resource *resource, struct wl_resource *source, struct wl_resource *origin, struct wl_resource *icon, uint32_t serial) {
    (void)client;
    (void)resource;
    (void)source;
    (void)origin;
    (void)icon;
    (void)serial;
    // Stub - full implementation would handle drag-and-drop
}

static void data_device_set_selection(struct wl_client *client, struct wl_resource *resource, struct wl_resource *source, uint32_t serial) {
    (void)client;
    (void)resource;
    (void)source;
    (void)serial;
    // Stub - full implementation would handle clipboard selection
}

static void data_device_release(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

