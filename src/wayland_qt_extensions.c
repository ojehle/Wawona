#include "wayland_qt_extensions.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>
#include <string.h>

// Qt Wayland Extensions - Minimal stub implementation
// Allows QtWayland applications to connect without crashing

// Minimal interface definitions (stubs)
static const struct wl_message qt_surface_extension_requests[] = {
    { "destroy", "", NULL },
    { "get_extended_surface", "no", NULL },
};

static const struct wl_message qt_extended_surface_requests[] = {
    { "destroy", "", NULL },
    { "update_property", "ss", NULL },
};

static const struct wl_message qt_windowmanager_requests[] = {
    { "destroy", "", NULL },
    { "open_uri", "hs", NULL },
};

const struct wl_interface qt_surface_extension_interface = {
    "qt_surface_extension", 1,
    2, qt_surface_extension_requests,
    0, NULL,
};

const struct wl_interface qt_extended_surface_interface = {
    "qt_extended_surface", 1,
    2, qt_extended_surface_requests,
    0, NULL,
};

const struct wl_interface qt_windowmanager_interface = {
    "qt_windowmanager", 1,
    2, qt_windowmanager_requests,
    0, NULL,
};

// ============================================================================
// Qt Surface Extension Protocol
// ============================================================================

// Interface struct definitions
struct qt_surface_extension_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*get_extended_surface)(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface);
};

struct qt_windowmanager_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*open_uri)(struct wl_client *client, struct wl_resource *resource, uint32_t fd, const char *uri);
};

// Forward declarations
static void qt_surface_extension_destroy(struct wl_client *client, struct wl_resource *resource);
static void qt_surface_extension_get_extended_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface);

static const struct qt_surface_extension_interface qt_surface_extension_interface_impl = {
    .destroy = qt_surface_extension_destroy,
    .get_extended_surface = qt_surface_extension_get_extended_surface,
};

static void qt_surface_extension_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void qt_surface_extension_get_extended_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface) {
    (void)resource;
    (void)surface;
    log_printf("[QT_SURFACE] ", "get_extended_surface() - id=%u (stub)\n", id);
    struct wl_resource *extended_surface = wl_resource_create(client, &qt_extended_surface_interface, 1, id);
    if (extended_surface) {
        wl_resource_set_implementation(extended_surface, NULL, NULL, NULL);
    }
}

static void qt_surface_extension_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    (void)data;
    struct wl_resource *resource = wl_resource_create(client, &qt_surface_extension_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(resource, &qt_surface_extension_interface_impl, NULL, NULL);
    log_printf("[QT_SURFACE] ", "qt_surface_extension_bind() - client=%p, version=%u, id=%u\n", (void *)client, version, id);
}

// ============================================================================
// Qt Window Manager Protocol
// ============================================================================

static void qt_windowmanager_destroy(struct wl_client *client, struct wl_resource *resource);
static void qt_windowmanager_open_uri(struct wl_client *client, struct wl_resource *resource, uint32_t fd, const char *uri);

static const struct qt_windowmanager_interface qt_windowmanager_interface_impl = {
    .destroy = qt_windowmanager_destroy,
    .open_uri = qt_windowmanager_open_uri,
};

static void qt_windowmanager_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void qt_windowmanager_open_uri(struct wl_client *client, struct wl_resource *resource, uint32_t fd, const char *uri) {
    (void)client;
    (void)resource;
    (void)fd;
    log_printf("[QT_WM] ", "open_uri() - uri=%s (stub)\n", uri ? uri : "NULL");
}

static void qt_windowmanager_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    (void)data;
    struct wl_resource *resource = wl_resource_create(client, &qt_windowmanager_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(resource, &qt_windowmanager_interface_impl, NULL, NULL);
    log_printf("[QT_WM] ", "qt_windowmanager_bind() - client=%p, version=%u, id=%u\n", (void *)client, version, id);
}

// ============================================================================
// Manager Creation Functions
// ============================================================================

struct wl_qt_surface_extension_impl *wl_qt_surface_extension_create(struct wl_display *display) {
    struct wl_qt_surface_extension_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) return NULL;

    manager->display = display;
    manager->global = wl_global_create(display, &qt_surface_extension_interface, 1, manager, qt_surface_extension_bind);
    
    if (!manager->global) {
        free(manager);
        return NULL;
    }
    
    return manager;
}

void wl_qt_surface_extension_destroy(struct wl_qt_surface_extension_impl *manager) {
    if (!manager) return;
    wl_global_destroy(manager->global);
    free(manager);
}

struct wl_qt_windowmanager_impl *wl_qt_windowmanager_create(struct wl_display *display) {
    struct wl_qt_windowmanager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) return NULL;

    manager->display = display;
    manager->global = wl_global_create(display, &qt_windowmanager_interface, 1, manager, qt_windowmanager_bind);
    
    if (!manager->global) {
        free(manager);
        return NULL;
    }
    
    return manager;
}

void wl_qt_windowmanager_destroy(struct wl_qt_windowmanager_impl *manager) {
    if (!manager) return;
    wl_global_destroy(manager->global);
    free(manager);
}

