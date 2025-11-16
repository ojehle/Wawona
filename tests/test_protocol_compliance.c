/*
 * Wawona Protocol Compliance Test Suite
 * Tests actual protocol implementations against Wayland protocol specifications
 */

#include <wayland-client.h>
#include <wayland-client-protocol.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>

#define MAX_PROTOCOLS 50

struct protocol_test {
    const char *name;
    int found;
    uint32_t version;
    uint32_t min_version;
    int required;
};

struct protocol_test protocols[] = {
    // Core protocols (required)
    {"wl_compositor", 0, 0, 4, 1},
    {"wl_output", 0, 0, 3, 1},
    {"wl_seat", 0, 0, 7, 1},
    {"wl_shm", 0, 0, 1, 1},
    {"wl_subcompositor", 0, 0, 1, 1},
    {"wl_data_device_manager", 0, 0, 3, 1},
    
    // Shell protocols
    {"xdg_wm_base", 0, 0, 4, 1},
    {"wl_shell", 0, 0, 1, 0}, // Legacy, optional
    
    // Application toolkit protocols
    {"gtk_shell1", 0, 0, 1, 0},
    {"org_kde_plasma_shell", 0, 0, 1, 0},
    {"qt_surface_extension", 0, 0, 1, 0},
    {"qt_windowmanager", 0, 0, 1, 0},
    
    // Extended protocols
    {"xdg_activation_v1", 0, 0, 1, 0},
    {"zxdg_decoration_manager_v1", 0, 0, 1, 0},
    {"wp_viewporter", 0, 0, 2, 0},
    {"wl_screencopy_manager_v1", 0, 0, 3, 0},
    {"zwp_primary_selection_device_manager_v1", 0, 0, 1, 0},
    {"zwp_idle_inhibit_manager_v1", 0, 0, 1, 0},
    {"zwp_text_input_manager_v3", 0, 0, 1, 0},
    {"wp_fractional_scale_manager_v1", 0, 0, 1, 0},
    {"wp_cursor_shape_manager_v1", 0, 0, 1, 0},
    {NULL, 0, 0, 0, 0}
};

static int tests_passed = 0;
static int tests_failed = 0;
static int tests_skipped = 0;

static void registry_global(void *data, struct wl_registry *registry,
                           uint32_t name, const char *interface, uint32_t version) {
    (void)registry;
    (void)name;
    
    for (int i = 0; protocols[i].name != NULL; i++) {
        if (strcmp(protocols[i].name, interface) == 0) {
            protocols[i].found = 1;
            protocols[i].version = version;
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

void test_protocol_advertised(const char *name, int found, uint32_t version, uint32_t min_version, int required) {
    if (found) {
        if (version >= min_version) {
            printf("✓ PASS: %s (version %u, required >= %u)\n", name, version, min_version);
            tests_passed++;
        } else {
            printf("✗ FAIL: %s version %u < required %u\n", name, version, min_version);
            tests_failed++;
        }
    } else {
        if (required) {
            printf("✗ FAIL: Required protocol %s not advertised\n", name);
            tests_failed++;
        } else {
            printf("⊘ SKIP: Optional protocol %s not advertised\n", name);
            tests_skipped++;
        }
    }
}

int main(int argc, char **argv) {
    const char *socket = getenv("WAYLAND_DISPLAY");
    if (!socket) socket = "wayland-0";
    
    printf("=== Wawona Protocol Compliance Test ===\n");
    printf("Connecting to Wayland display: %s\n\n", socket);
    
    struct wl_display *display = wl_display_connect(socket);
    if (!display) {
        fprintf(stderr, "✗ FAIL: Failed to connect to Wayland display\n");
        return 1;
    }
    
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    
    printf("Protocol Test Results:\n");
    printf("=====================\n\n");
    
    for (int i = 0; protocols[i].name != NULL; i++) {
        test_protocol_advertised(
            protocols[i].name,
            protocols[i].found,
            protocols[i].version,
            protocols[i].min_version,
            protocols[i].required
        );
    }
    
    printf("\n=== Test Summary ===\n");
    printf("Passed:  %d\n", tests_passed);
    printf("Failed:  %d\n", tests_failed);
    printf("Skipped: %d\n", tests_skipped);
    printf("Total:   %d\n\n", tests_passed + tests_failed + tests_skipped);
    
    wl_registry_destroy(registry);
    wl_display_disconnect(display);
    
    return tests_failed > 0 ? 1 : 0;
}

