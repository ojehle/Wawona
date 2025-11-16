/*
 * Wawona Wayland Client Test
 * Connects to Wawona and verifies protocol implementations
 */

#include <wayland-client.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

struct protocol_info {
    const char *name;
    int found;
    uint32_t version;
    uint32_t id;
};

struct protocol_info protocols[] = {
    {"wl_compositor", 0, 0, 0},
    {"wl_output", 0, 0, 0},
    {"wl_seat", 0, 0, 0},
    {"wl_shm", 0, 0, 0},
    {"wl_subcompositor", 0, 0, 0},
    {"wl_data_device_manager", 0, 0, 0},
    {"xdg_wm_base", 0, 0, 0},
    {"wl_shell", 0, 0, 0},
    {"gtk_shell1", 0, 0, 0},
    {"org_kde_plasma_shell", 0, 0, 0},
    {"qt_surface_extension", 0, 0, 0},
    {"qt_windowmanager", 0, 0, 0},
    {"xdg_activation_v1", 0, 0, 0},
    {"zxdg_decoration_manager_v1", 0, 0, 0},
    {"wp_viewporter", 0, 0, 0},
    {"zwp_screencopy_manager_v1", 0, 0, 0},  // Fixed: correct protocol name
    {"zwlr_screencopy_manager_v1", 0, 0, 0},  // wlroots version
    {"zwp_linux_dmabuf_v1", 0, 0, 0},  // DMA-BUF support (critical for wlroots)
    {"zwp_primary_selection_device_manager_v1", 0, 0, 0},
    {"zwp_idle_inhibit_manager_v1", 0, 0, 0},
    {"zwp_text_input_manager_v3", 0, 0, 0},
    {"wp_fractional_scale_manager_v1", 0, 0, 0},
    {"wp_cursor_shape_manager_v1", 0, 0, 0},
    {NULL, 0, 0, 0}
};

static void registry_global(void *data, struct wl_registry *registry,
                           uint32_t name, const char *interface, uint32_t version) {
    (void)data;
    (void)registry;
    
    for (int i = 0; protocols[i].name != NULL; i++) {
        if (strcmp(protocols[i].name, interface) == 0) {
            protocols[i].found = 1;
            protocols[i].version = version;
            protocols[i].id = name;
            printf("FOUND: %s version %u (id=%u)\n", interface, version, name);
            break;
        }
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    registry_global,
    registry_global_remove
};

int main(int argc, char **argv) {
    const char *socket = getenv("WAYLAND_DISPLAY");
    if (!socket) socket = "wayland-0";
    
    printf("=== Wawona Protocol Verification ===\n");
    printf("Connecting to: %s\n\n", socket);
    
    struct wl_display *display = wl_display_connect(socket);
    if (!display) {
        fprintf(stderr, "ERROR: Failed to connect to Wayland display: %s\n", strerror(errno));
        return 1;
    }
    
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    
    // Roundtrip to get all globals
    if (wl_display_roundtrip(display) < 0) {
        fprintf(stderr, "ERROR: Roundtrip failed\n");
        wl_registry_destroy(registry);
        wl_display_disconnect(display);
        return 1;
    }
    
    printf("\n=== Protocol Status ===\n");
    int found_count = 0;
    int missing_count = 0;
    
    for (int i = 0; protocols[i].name != NULL; i++) {
        if (protocols[i].found) {
            printf("✓ %s (v%u)\n", protocols[i].name, protocols[i].version);
            found_count++;
        } else {
            printf("✗ %s - NOT FOUND\n", protocols[i].name);
            missing_count++;
        }
    }
    
    printf("\n=== Summary ===\n");
    printf("Found:   %d\n", found_count);
    printf("Missing: %d\n", missing_count);
    printf("Total:   %d\n\n", found_count + missing_count);
    
    wl_registry_destroy(registry);
    wl_display_disconnect(display);
    
    return missing_count > 0 ? 1 : 0;
}

