#include "wayland_plasma_shell.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>
#include <string.h>

// Plasma Shell Protocol - Minimal stub implementation
// Allows KDE Plasma applications to connect without crashing

// Minimal interface definitions (stubs)
static const struct wl_message org_kde_plasma_shell_requests[] = {
    { "destroy", "", NULL },
    { "get_surface", "no", NULL },
};

static const struct wl_message org_kde_plasma_surface_requests[] = {
    { "destroy", "", NULL },
    { "set_role", "u", NULL },
    { "set_skip_taskbar", "u", NULL },
    { "set_skip_switcher", "u", NULL },
};

const struct wl_interface org_kde_plasma_shell_interface = {
    "org_kde_plasma_shell", 1,
    2, org_kde_plasma_shell_requests,
    0, NULL,
};

const struct wl_interface org_kde_plasma_surface_interface = {
    "org_kde_plasma_surface", 1,
    4, org_kde_plasma_surface_requests,
    0, NULL,
};

// Interface struct definition
struct org_kde_plasma_shell_interface {
    void (*destroy)(struct wl_client *client, struct wl_resource *resource);
    void (*get_surface)(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface);
};

// Forward declarations
static void plasma_shell_destroy(struct wl_client *client, struct wl_resource *resource);
static void plasma_shell_get_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface);

static const struct org_kde_plasma_shell_interface plasma_shell_interface = {
    .destroy = plasma_shell_destroy,
    .get_surface = plasma_shell_get_surface,
};

static void plasma_shell_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void plasma_shell_get_surface(struct wl_client *client, struct wl_resource *resource, uint32_t id, struct wl_resource *surface) {
    (void)resource;
    (void)surface;
    log_printf("[PLASMA_SHELL] ", "get_surface() - id=%u (stub)\n", id);
    // Create minimal stub resource
    struct wl_resource *plasma_surface = wl_resource_create(client, &org_kde_plasma_surface_interface, 1, id);
    if (plasma_surface) {
        wl_resource_set_implementation(plasma_surface, NULL, NULL, NULL);
    }
}

static void plasma_shell_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    (void)data;
    struct wl_resource *resource = wl_resource_create(client, &org_kde_plasma_shell_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(resource, &plasma_shell_interface, NULL, NULL);
    log_printf("[PLASMA_SHELL] ", "plasma_shell_bind() - client=%p, version=%u, id=%u\n", (void *)client, version, id);
}

struct wl_plasma_shell_manager_impl *wl_plasma_shell_create(struct wl_display *display) {
    struct wl_plasma_shell_manager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) return NULL;

    manager->display = display;
    manager->global = wl_global_create(display, &org_kde_plasma_shell_interface, 1, manager, plasma_shell_bind);
    
    if (!manager->global) {
        free(manager);
        return NULL;
    }
    
    return manager;
}

void wl_plasma_shell_destroy(struct wl_plasma_shell_manager_impl *manager) {
    if (!manager) return;
    
    wl_global_destroy(manager->global);
    free(manager);
}

