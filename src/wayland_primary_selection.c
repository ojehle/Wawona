#include "wayland_primary_selection.h"
#include "primary-selection-protocol.h"
#include "wayland_seat.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Primary selection source data structure
struct primary_selection_source_data {
    struct wl_resource *resource;
    struct wl_list mime_types;  // List of offered MIME types
    struct wl_list link;
};

// Primary selection offer data structure
struct primary_selection_offer_data {
    struct wl_resource *resource;
    struct wl_list mime_types;  // List of offered MIME types
    struct wl_resource *source_resource;  // Source that created this offer
};

// MIME type entry
struct mime_type_entry {
    char *mime_type;
    struct wl_list link;
};

// Global primary selection state
static struct wl_resource *current_primary_selection_source = NULL;
static struct wl_list all_sources;

static void primary_selection_manager_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void primary_selection_source_resource_destroy(struct wl_resource *resource) {
    struct primary_selection_source_data *data = wl_resource_get_user_data(resource);
    if (data) {
        // Free MIME type list
        struct mime_type_entry *entry, *tmp;
        wl_list_for_each_safe(entry, tmp, &data->mime_types, link) {
            free(entry->mime_type);
            wl_list_remove(&entry->link);
            free(entry);
        }
        
        // Remove from global list
        wl_list_remove(&data->link);
        
        // Clear current selection if this was it
        if (current_primary_selection_source == resource) {
            current_primary_selection_source = NULL;
        }
        
        free(data);
    }
}

static void primary_selection_source_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void primary_selection_source_offer(struct wl_client *client, struct wl_resource *resource, const char *mime_type) {
    (void)client;
    struct primary_selection_source_data *data = wl_resource_get_user_data(resource);
    if (!data) {
        data = calloc(1, sizeof(*data));
        if (!data) {
            wl_client_post_no_memory(client);
            return;
        }
        data->resource = resource;
        wl_list_init(&data->mime_types);
        wl_list_insert(&all_sources, &data->link);
        wl_resource_set_user_data(resource, data);
        wl_resource_set_destructor(resource, primary_selection_source_resource_destroy);
    }
    
    // Add MIME type to list
    struct mime_type_entry *entry = calloc(1, sizeof(*entry));
    if (!entry) {
        wl_client_post_no_memory(client);
        return;
    }
    entry->mime_type = strdup(mime_type ? mime_type : "");
    wl_list_insert(&data->mime_types, &entry->link);
    
    log_printf("[PRIMARY_SELECTION] ", "source_offer() - mime_type=%s\n", mime_type ? mime_type : "NULL");
}

static const struct zwp_primary_selection_source_v1_interface primary_selection_source_interface = {
    .destroy = primary_selection_source_destroy,
    .offer = primary_selection_source_offer,
};

static void primary_selection_manager_create_source(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    (void)resource;
    // Create source resource
    struct wl_resource *source = wl_resource_create(client, &zwp_primary_selection_source_v1_interface, wl_resource_get_version(resource), id);
    if (!source) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(source, &primary_selection_source_interface, NULL, NULL);
    log_printf("[PRIMARY_SELECTION] ", "create_source() - created source id=%u\n", id);
}

// Primary selection offer implementation
static void primary_selection_offer_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void primary_selection_offer_receive(struct wl_client *client, struct wl_resource *resource, const char *mime_type, int32_t fd) {
    (void)client;
    struct primary_selection_offer_data *offer_data = wl_resource_get_user_data(resource);
    if (!offer_data || !offer_data->source_resource) {
        close(fd);
        return;
    }
    
    struct primary_selection_source_data *source_data = wl_resource_get_user_data(offer_data->source_resource);
    if (!source_data) {
        close(fd);
        return;
    }
    
    // Find matching MIME type and send data
    struct mime_type_entry *entry;
    bool found = false;
    wl_list_for_each(entry, &source_data->mime_types, link) {
        if (strcmp(entry->mime_type, mime_type) == 0) {
            found = true;
            break;
        }
    }
    
    if (found) {
        // Send send event to source
        zwp_primary_selection_source_v1_send_send(offer_data->source_resource, mime_type, fd);
        log_printf("[PRIMARY_SELECTION] ", "offer_receive() - mime_type=%s, fd=%d\n", mime_type, fd);
    } else {
        close(fd);
        log_printf("[PRIMARY_SELECTION] ", "offer_receive() - mime_type=%s not found, closing fd\n", mime_type);
    }
}

static const struct zwp_primary_selection_offer_v1_interface primary_selection_offer_interface = {
    .receive = primary_selection_offer_receive,
    .destroy = primary_selection_offer_destroy,
};

static void primary_selection_device_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void primary_selection_device_set_selection(struct wl_client *client, struct wl_resource *resource, struct wl_resource *source, uint32_t serial) {
    (void)client;
    (void)serial;
    
    // Cancel previous selection source
    if (current_primary_selection_source && current_primary_selection_source != source) {
        zwp_primary_selection_source_v1_send_cancelled(current_primary_selection_source);
    }
    
    // Set new selection
    current_primary_selection_source = source;
    
    // Notify all devices about the new selection
    // For now, we'll notify the device that set the selection
    // Full implementation would track all devices and notify focused ones
    if (source) {
        struct primary_selection_source_data *source_data = wl_resource_get_user_data(source);
        if (source_data) {
            // Create offer for this device
            // Note: id=0 means let Wayland assign a unique ID
            uint32_t version = (uint32_t)wl_resource_get_version(resource);
            struct wl_resource *offer = wl_resource_create(client, &zwp_primary_selection_offer_v1_interface, (int)version, (uint32_t)0);
            if (offer) {
                struct primary_selection_offer_data *offer_data = calloc(1, sizeof(*offer_data));
                if (offer_data) {
                    offer_data->resource = offer;
                    offer_data->source_resource = source;
                    wl_list_init(&offer_data->mime_types);
                    
                    // Copy MIME types to offer
                    struct mime_type_entry *entry;
                    wl_list_for_each(entry, &source_data->mime_types, link) {
                        zwp_primary_selection_offer_v1_send_offer(offer, entry->mime_type);
                    }
                    
                    wl_resource_set_implementation(offer, &primary_selection_offer_interface, offer_data, NULL);
                    
                    // Protocol requires: send data_offer first, then selection
                    // data_offer introduces the new object with new_id
                    zwp_primary_selection_device_v1_send_data_offer(resource, offer);
                    // selection references the existing offer object
                    zwp_primary_selection_device_v1_send_selection(resource, offer);
                } else {
                    wl_resource_destroy(offer);
                    zwp_primary_selection_device_v1_send_selection(resource, NULL);
                }
            } else {
                zwp_primary_selection_device_v1_send_selection(resource, NULL);
            }
        } else {
            zwp_primary_selection_device_v1_send_selection(resource, NULL);
        }
    } else {
        // Clear selection
        zwp_primary_selection_device_v1_send_selection(resource, NULL);
    }
    
    log_printf("[PRIMARY_SELECTION] ", "device_set_selection() - serial=%u, source=%p\n", serial, (void *)source);
}

static const struct zwp_primary_selection_device_v1_interface primary_selection_device_interface = {
    .destroy = primary_selection_device_destroy,
    .set_selection = primary_selection_device_set_selection,
};

static void primary_selection_manager_get_device(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *seat) {
    (void)seat;
    // Create device resource
    struct wl_resource *device = wl_resource_create(client, &zwp_primary_selection_device_v1_interface, wl_resource_get_version(resource), id);
    if (!device) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(device, &primary_selection_device_interface, NULL, NULL);
    
    // Send current selection if any
    if (current_primary_selection_source) {
        struct primary_selection_source_data *source_data = wl_resource_get_user_data(current_primary_selection_source);
        if (source_data) {
            // Create offer
            uint32_t version = (uint32_t)wl_resource_get_version(resource);
            struct wl_resource *offer = wl_resource_create(client, &zwp_primary_selection_offer_v1_interface, (int)version, (uint32_t)0);
            if (offer) {
                struct primary_selection_offer_data *offer_data = calloc(1, sizeof(*offer_data));
                if (offer_data) {
                    offer_data->resource = offer;
                    offer_data->source_resource = current_primary_selection_source;
                    wl_list_init(&offer_data->mime_types);
                    
                    // Copy MIME types
                    struct mime_type_entry *entry;
                    wl_list_for_each(entry, &source_data->mime_types, link) {
                        zwp_primary_selection_offer_v1_send_offer(offer, entry->mime_type);
                    }
                    
                    wl_resource_set_implementation(offer, &primary_selection_offer_interface, offer_data, NULL);
                    zwp_primary_selection_device_v1_send_data_offer(device, offer);
                    zwp_primary_selection_device_v1_send_selection(device, offer);
                } else {
                    wl_resource_destroy(offer);
                    zwp_primary_selection_device_v1_send_selection(device, NULL);
                }
            } else {
                zwp_primary_selection_device_v1_send_selection(device, NULL);
            }
        } else {
            zwp_primary_selection_device_v1_send_selection(device, NULL);
        }
    } else {
        // Send selection event with NULL offer (no primary selection)
        zwp_primary_selection_device_v1_send_selection(device, NULL);
    }
    
    log_printf("[PRIMARY_SELECTION] ", "get_device() - created device id=%u\n", id);
}

static const struct zwp_primary_selection_device_manager_v1_interface primary_selection_manager_interface = {
    .destroy = primary_selection_manager_destroy,
    .create_source = primary_selection_manager_create_source,
    .get_device = primary_selection_manager_get_device,
};

static void primary_selection_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    (void)data;
    struct wl_resource *resource = wl_resource_create(client, &zwp_primary_selection_device_manager_v1_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(resource, &primary_selection_manager_interface, NULL, NULL);
    log_printf("[PRIMARY_SELECTION] ", "primary_selection_bind() - client=%p, version=%u, id=%u\n", (void *)client, version, id);
}

struct wl_primary_selection_manager_impl *wl_primary_selection_create(struct wl_display *display) {
    struct wl_primary_selection_manager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) return NULL;
    
    manager->display = display;
    manager->global = wl_global_create(display, &zwp_primary_selection_device_manager_v1_interface, 1, manager, primary_selection_bind);
    
    if (!manager->global) {
        free(manager);
        return NULL;
    }
    
    // Initialize global source list
    wl_list_init(&all_sources);
    current_primary_selection_source = NULL;
    
    return manager;
}

void wl_primary_selection_destroy(struct wl_primary_selection_manager_impl *manager) {
    if (!manager) return;
    
    wl_global_destroy(manager->global);
    free(manager);
}

