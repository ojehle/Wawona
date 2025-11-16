#include "wayland_gtk_shell.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>
#include <string.h>

// GTK Shell Protocol - Minimal stub implementation
// Allows GTK applications to connect without crashing

// Minimal interface definitions (stubs)
static const struct wl_message gtk_shell1_requests[] = {
    { "destroy", "", NULL },
    { "get_gtk_surface", "no", NULL },
    { "set_startup_id", "s", NULL },
    { "system_bell", "o", NULL },
};

static const struct wl_message gtk_surface1_requests[] = {
    { "destroy", "", NULL },
    { "set_modal", "", NULL },
    { "unset_modal", "", NULL },
    { "present", "u", NULL },
};

const struct wl_interface gtk_shell1_interface = {
    "gtk_shell1", 1,
    4, gtk_shell1_requests,
    0, NULL,
};

const struct wl_interface gtk_surface1_interface = {
    "gtk_surface1", 1,
    4, gtk_surface1_requests,
    0, NULL,
};

// Interface struct definition
struct gtk_shell1_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*get_gtk_surface)(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface);
    void (*set_startup_id)(struct wl_client *client, struct wl_resource *resource, const char *startup_id);
    void (*system_bell)(struct wl_client *client, struct wl_resource *resource, struct wl_resource *surface);
};

// Forward declarations
static void gtk_shell_destroy(struct wl_client *client, struct wl_resource *resource);
static void gtk_shell_get_gtk_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface);
static void gtk_shell_set_startup_id(struct wl_client *client, struct wl_resource *resource, const char *startup_id);
static void gtk_shell_system_bell(struct wl_client *client, struct wl_resource *resource, struct wl_resource *surface);

static const struct gtk_shell1_interface gtk_shell_interface = {
    .destroy = gtk_shell_destroy,
    .get_gtk_surface = gtk_shell_get_gtk_surface,
    .set_startup_id = gtk_shell_set_startup_id,
    .system_bell = gtk_shell_system_bell,
};

static void gtk_shell_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void gtk_shell_get_gtk_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface) {
    (void)resource;
    (void)surface;
    log_printf("[GTK_SHELL] ", "get_gtk_surface() - id=%u (stub)\n", id);
    // Create minimal stub resource
    struct wl_resource *gtk_surface = wl_resource_create(client, &gtk_surface1_interface, 1, id);
    if (gtk_surface) {
        // Minimal stub implementation - just accept requests
        wl_resource_set_implementation(gtk_surface, NULL, NULL, NULL);
    }
}

static void gtk_shell_set_startup_id(struct wl_client *client, struct wl_resource *resource, const char *startup_id) {
    (void)client;
    (void)resource;
    log_printf("[GTK_SHELL] ", "set_startup_id() - startup_id=%s (stub)\n", startup_id ? startup_id : "NULL");
}

static void gtk_shell_system_bell(struct wl_client *client, struct wl_resource *resource, struct wl_resource *surface) {
    (void)client;
    (void)resource;
    (void)surface;
    log_printf("[GTK_SHELL] ", "system_bell() (stub)\n");
}

static void gtk_shell_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    (void)data;
    struct wl_resource *resource = wl_resource_create(client, &gtk_shell1_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(resource, &gtk_shell_interface, NULL, NULL);
    log_printf("[GTK_SHELL] ", "gtk_shell_bind() - client=%p, version=%u, id=%u\n", (void *)client, version, id);
}

struct wl_gtk_shell_manager_impl *wl_gtk_shell_create(struct wl_display *display) {
    struct wl_gtk_shell_manager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) return NULL;

    manager->display = display;
    manager->global = wl_global_create(display, &gtk_shell1_interface, 1, manager, gtk_shell_bind);
    
    if (!manager->global) {
        free(manager);
        return NULL;
    }
    
    return manager;
}

void wl_gtk_shell_destroy(struct wl_gtk_shell_manager_impl *manager) {
    if (!manager) return;
    
    wl_global_destroy(manager->global);
    free(manager);
}

