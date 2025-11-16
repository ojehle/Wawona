#!/bin/bash
# Wawona Implementation Verification Script
# Verifies what's ACTUALLY implemented vs what's claimed

set -e

COMPOSITOR_BIN="${BUILD_DIR:-build}/Wawona"
VERIFICATION_LOG="/tmp/wawona_verification.log"

echo "=== Wawona Implementation Verification ===" | tee "$VERIFICATION_LOG"
echo "Date: $(date)" | tee -a "$VERIFICATION_LOG"
echo "" | tee -a "$VERIFICATION_LOG"

# Check if compositor binary exists
if [ ! -f "$COMPOSITOR_BIN" ]; then
    echo "❌ ERROR: Compositor binary not found at $COMPOSITOR_BIN" | tee -a "$VERIFICATION_LOG"
    exit 1
fi

echo "✓ Compositor binary found: $COMPOSITOR_BIN" | tee -a "$VERIFICATION_LOG"

# Start compositor in background
echo "" | tee -a "$VERIFICATION_LOG"
echo "=== Starting Compositor ===" | tee -a "$VERIFICATION_LOG"
"$COMPOSITOR_BIN" > /tmp/wawona_verification_output.log 2>&1 &
COMPOSITOR_PID=$!
sleep 2

# Check if compositor is running
if ! kill -0 $COMPOSITOR_PID 2>/dev/null; then
    echo "❌ ERROR: Compositor failed to start" | tee -a "$VERIFICATION_LOG"
    cat /tmp/wawona_verification_output.log | tee -a "$VERIFICATION_LOG"
    exit 1
fi

echo "✓ Compositor started (PID: $COMPOSITOR_PID)" | tee -a "$VERIFICATION_LOG"

# Check Wayland socket
WAYLAND_SOCKET="${XDG_RUNTIME_DIR:-/tmp}/wayland-0"
if [ ! -S "$WAYLAND_SOCKET" ]; then
    echo "❌ ERROR: Wayland socket not found at $WAYLAND_SOCKET" | tee -a "$VERIFICATION_LOG"
    kill $COMPOSITOR_PID 2>/dev/null || true
    exit 1
fi

echo "✓ Wayland socket found: $WAYLAND_SOCKET" | tee -a "$VERIFICATION_LOG"

# Use wayland-info or wayland-scanner to check advertised globals
echo "" | tee -a "$VERIFICATION_LOG"
echo "=== Checking Advertised Protocols ===" | tee -a "$VERIFICATION_LOG"

# Check for wayland-scanner or use wl_display_get_registry
if command -v wayland-scanner &> /dev/null; then
    echo "Using wayland-scanner to verify protocols..." | tee -a "$VERIFICATION_LOG"
else
    echo "⚠ wayland-scanner not found, using alternative method..." | tee -a "$VERIFICATION_LOG"
fi

# Create a simple C program to query registry
cat > /tmp/check_registry.c << 'EOF'
#include <wayland-client.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

struct protocol_info {
    const char *name;
    int found;
    uint32_t version;
};

struct protocol_info protocols[] = {
    {"wl_compositor", 0, 0},
    {"wl_output", 0, 0},
    {"wl_seat", 0, 0},
    {"wl_shm", 0, 0},
    {"wl_subcompositor", 0, 0},
    {"wl_data_device_manager", 0, 0},
    {"xdg_wm_base", 0, 0},
    {"wl_shell", 0, 0},
    {"gtk_shell1", 0, 0},
    {"org_kde_plasma_shell", 0, 0},
    {"qt_surface_extension", 0, 0},
    {"qt_windowmanager", 0, 0},
    {"xdg_activation_v1", 0, 0},
    {"zxdg_decoration_manager_v1", 0, 0},
    {"wp_viewporter", 0, 0},
    {"wl_screencopy_manager_v1", 0, 0},
    {"zwp_primary_selection_device_manager_v1", 0, 0},
    {"zwp_idle_inhibit_manager_v1", 0, 0},
    {"zwp_text_input_manager_v3", 0, 0},
    {"wp_fractional_scale_manager_v1", 0, 0},
    {"wp_cursor_shape_manager_v1", 0, 0},
    {NULL, 0, 0}
};

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

int main() {
    const char *socket = getenv("WAYLAND_DISPLAY");
    if (!socket) socket = "wayland-0";
    
    struct wl_display *display = wl_display_connect(socket);
    if (!display) {
        fprintf(stderr, "Failed to connect to Wayland display\n");
        return 1;
    }
    
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    
    printf("PROTOCOL_CHECK_RESULTS\n");
    for (int i = 0; protocols[i].name != NULL; i++) {
        if (protocols[i].found) {
            printf("FOUND:%s:%u\n", protocols[i].name, protocols[i].version);
        } else {
            printf("MISSING:%s\n", protocols[i].name);
        }
    }
    
    wl_registry_destroy(registry);
    wl_display_disconnect(display);
    return 0;
}
EOF

# Compile and run registry checker
if gcc -o /tmp/check_registry /tmp/check_registry.c -lwayland-client 2>/dev/null; then
    export WAYLAND_DISPLAY="wayland-0"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
    
    /tmp/check_registry 2>&1 | tee -a "$VERIFICATION_LOG" | grep -E "(FOUND|MISSING)" | while IFS=: read -r status name version; do
        if [ "$status" = "FOUND" ]; then
            echo "✓ $name (version $version)" | tee -a "$VERIFICATION_LOG"
        else
            echo "❌ $name - NOT ADVERTISED" | tee -a "$VERIFICATION_LOG"
        fi
    done
else
    echo "⚠ Could not compile registry checker, skipping protocol verification" | tee -a "$VERIFICATION_LOG"
fi

# Check compositor logs for protocol creation
echo "" | tee -a "$VERIFICATION_LOG"
echo "=== Checking Compositor Logs ===" | tee -a "$VERIFICATION_LOG"
sleep 1
if [ -f /tmp/wawona_verification_output.log ]; then
    grep -E "(protocol created|protocol|GTK|PLASMA|Qt|gtk|plasma|qt)" /tmp/wawona_verification_output.log | head -20 | tee -a "$VERIFICATION_LOG"
fi

# Cleanup
kill $COMPOSITOR_PID 2>/dev/null || true
wait $COMPOSITOR_PID 2>/dev/null || true

echo "" | tee -a "$VERIFICATION_LOG"
echo "=== Verification Complete ===" | tee -a "$VERIFICATION_LOG"
echo "Full log: $VERIFICATION_LOG" | tee -a "$VERIFICATION_LOG"

