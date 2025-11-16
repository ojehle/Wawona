#include "wayland_keyboard_shortcuts.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>

// Keyboard shortcuts inhibit protocol implementation
// Allows clients to inhibit global keyboard shortcuts

struct wl_keyboard_shortcuts_inhibit_manager_impl *wl_keyboard_shortcuts_create(struct wl_display *display) {
    struct wl_keyboard_shortcuts_inhibit_manager_impl *manager = calloc(1, sizeof(*manager));
    if (!manager) return NULL;
    
    manager->display = display;
    
    log_printf("[KEYBOARD_SHORTCUTS] ", "keyboard_shortcuts_inhibit_manager created\n");
    return manager;
}

void wl_keyboard_shortcuts_destroy(struct wl_keyboard_shortcuts_inhibit_manager_impl *manager) {
    if (!manager) return;
    free(manager);
}

