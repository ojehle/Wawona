#include "wayland_idle_manager.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>

// Idle manager protocol implementation
// Tracks user idle time and notifies clients

struct wl_idle_manager_impl *wl_idle_manager_create(struct wl_display *display) {
    struct wl_idle_manager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) return NULL;
    
    manager->display = display;
    manager->idle_timeout = 300000; // 5 minutes default
    
    log_printf("[IDLE_MANAGER] ", "idle_manager created\n");
    return manager;
}

void wl_idle_manager_destroy(struct wl_idle_manager_impl *manager) {
    if (!manager) return;
    free(manager);
}

uint32_t wl_idle_manager_get_idle_timeout(struct wl_idle_manager_impl *manager) {
    if (!manager) return 0;
    return manager->idle_timeout;
}

void wl_idle_manager_set_idle_timeout(struct wl_idle_manager_impl *manager, uint32_t timeout) {
    if (!manager) return;
    manager->idle_timeout = timeout;
}

