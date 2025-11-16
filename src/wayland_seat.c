#include "wayland_seat.h"
#include "wayland_compositor.h"
#include "logging.h"
#include <wayland-server-protocol.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

static void seat_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id);
static void seat_get_pointer(struct wl_client *client, struct wl_resource *resource, uint32_t id);
static void seat_get_keyboard(struct wl_client *client, struct wl_resource *resource, uint32_t id);
static void seat_get_touch(struct wl_client *client, struct wl_resource *resource, uint32_t id);
static void seat_release(struct wl_client *client, struct wl_resource *resource);

static const struct wl_seat_interface seat_interface = {
    .get_pointer = seat_get_pointer,
    .get_keyboard = seat_get_keyboard,
    .get_touch = seat_get_touch,
    .release = seat_release,
};

static void pointer_set_cursor(struct wl_client *client, struct wl_resource *resource, uint32_t serial, struct wl_resource *surface, int32_t hotspot_x, int32_t hotspot_y);
static void pointer_release(struct wl_client *client, struct wl_resource *resource);
static const struct wl_pointer_interface pointer_interface = {
    .set_cursor = pointer_set_cursor,
    .release = pointer_release,
};

static void keyboard_release(struct wl_client *client, struct wl_resource *resource);
static const struct wl_keyboard_interface keyboard_interface = {
    .release = keyboard_release,
};

static void touch_release(struct wl_client *client, struct wl_resource *resource);
static const struct wl_touch_interface touch_interface = {
    .release = touch_release,
};

struct wl_seat_impl *wl_seat_create(struct wl_display *display) {
    struct wl_seat_impl *seat = calloc(1, sizeof(*seat));
    if (!seat) return NULL;
    
    seat->display = display;
    seat->capabilities = WL_SEAT_CAPABILITY_POINTER | WL_SEAT_CAPABILITY_KEYBOARD | WL_SEAT_CAPABILITY_TOUCH;
    seat->serial = 1;
    
    seat->global = wl_global_create(display, &wl_seat_interface, 7, seat, seat_bind);
    
    if (!seat->global) {
        free(seat);
        return NULL;
    }
    
    return seat;
}

void wl_seat_destroy(struct wl_seat_impl *seat) {
    if (!seat) return;
    
    wl_global_destroy(seat->global);
    free(seat);
}

static void seat_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_seat_impl *seat = data;
    log_printf("[SEAT] ", "seat_bind: client=%p, version=%u, id=%u, capabilities=0x%x\n", 
               (void *)client, version, id, seat->capabilities);
    
    struct wl_resource *resource = wl_resource_create(client, &wl_seat_interface, (int)version, id);
    
    if (!resource) {
        log_printf("[SEAT] ", "seat_bind: failed to create seat resource\n");
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &seat_interface, seat, NULL);
    
    wl_seat_send_capabilities(resource, seat->capabilities);
    log_printf("[SEAT] ", "seat_bind: sent capabilities=0x%x (keyboard=%s, pointer=%s, touch=%s)\n",
               seat->capabilities,
               (seat->capabilities & WL_SEAT_CAPABILITY_KEYBOARD) ? "yes" : "no",
               (seat->capabilities & WL_SEAT_CAPABILITY_POINTER) ? "yes" : "no",
               (seat->capabilities & WL_SEAT_CAPABILITY_TOUCH) ? "yes" : "no");
    
    if (version >= WL_SEAT_NAME_SINCE_VERSION) {
        wl_seat_send_name(resource, "default");
    }
}

static void seat_get_pointer(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    struct wl_seat_impl *seat = wl_resource_get_user_data(resource);
    struct wl_resource *pointer_resource = wl_resource_create(client, &wl_pointer_interface, wl_resource_get_version(resource), id);
    
    if (!pointer_resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(pointer_resource, &pointer_interface, seat, NULL);
    seat->pointer_resource = pointer_resource;
}

static void seat_get_keyboard(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    struct wl_seat_impl *seat = wl_resource_get_user_data(resource);
    log_printf("[SEAT] ", "seat_get_keyboard: client=%p, seat=%p, id=%u\n", (void *)client, (void *)seat, id);
    
    struct wl_resource *keyboard_resource = wl_resource_create(client, &wl_keyboard_interface, wl_resource_get_version(resource), id);
    
    if (!keyboard_resource) {
        log_printf("[SEAT] ", "seat_get_keyboard: failed to create keyboard resource\n");
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(keyboard_resource, &keyboard_interface, seat, NULL);
    seat->keyboard_resource = keyboard_resource;
    log_printf("[SEAT] ", "seat_get_keyboard: keyboard resource created successfully: %p\n", (void *)keyboard_resource);
    
    // Send keymap - use a standard pc+us layout so Linux clients understand our keycodes
    const char *keymap_string =
        "xkb_keymap {\n"
        "  xkb_keycodes  { include \"evdev+aliases(qwerty)\" };\n"
        "  xkb_types     { include \"complete\" };\n"
        "  xkb_compat    { include \"complete\" };\n"
        "  xkb_symbols   { include \"pc+us\" };\n"
        "  xkb_geometry  { include \"pc(pc105)\" };\n"
        "};\n";
    
    int keymap_fd = -1;
    size_t keymap_size = strlen(keymap_string) + 1;
    
    // Create a temporary file for the keymap
    char keymap_path[] = "/tmp/wayland-keymap-XXXXXX";
    keymap_fd = mkstemp(keymap_path);
    if (keymap_fd >= 0) {
        unlink(keymap_path);
        if (write(keymap_fd, keymap_string, keymap_size) == (ssize_t)keymap_size) {
            lseek(keymap_fd, 0, SEEK_SET);
            wl_keyboard_send_keymap(keyboard_resource, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, keymap_fd, (uint32_t)keymap_size);
        }
        close(keymap_fd);
    }
}

static void seat_get_touch(struct wl_client *client, struct wl_resource *resource, uint32_t id) {
    struct wl_seat_impl *seat = wl_resource_get_user_data(resource);
    struct wl_resource *touch_resource = wl_resource_create(client, &wl_touch_interface, wl_resource_get_version(resource), id);
    
    if (!touch_resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(touch_resource, &touch_interface, seat, NULL);
    seat->touch_resource = touch_resource;
}

static void touch_release(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void seat_release(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void pointer_set_cursor(struct wl_client *client, struct wl_resource *resource, uint32_t serial, struct wl_resource *surface, int32_t hotspot_x, int32_t hotspot_y) {
    // Cursor handling - accept cursor surface requests
    // Note: The cursor errors (dnd-move, dnd-copy, dnd-none) are from weston-terminal
    // trying to load cursor themes, which we don't support yet. These are harmless warnings.
    (void)client;
    (void)resource;
    (void)serial;
    (void)surface;
    (void)hotspot_x;
    (void)hotspot_y;
    
    // TODO: Implement cursor rendering using NSCursor or custom CALayer
    // For now, we just acknowledge the request (required by protocol)
    // macOS will use its default cursor
}

static void pointer_release(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    struct wl_seat_impl *seat = wl_resource_get_user_data(resource);
    if (seat) {
        seat->pointer_resource = NULL;
    }
    // Clear user data before destroying to prevent use-after-free
    wl_resource_set_user_data(resource, NULL);
    wl_resource_destroy(resource);
}

static void keyboard_release(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    struct wl_seat_impl *seat = wl_resource_get_user_data(resource);
    log_printf("[SEAT] ", "keyboard_release: resource=%p, seat=%p\n", (void *)resource, (void *)seat);
    if (seat) {
        if (seat->keyboard_resource == resource) {
            log_printf("[SEAT] ", "keyboard_release: clearing keyboard_resource\n");
            seat->keyboard_resource = NULL;
        } else {
            log_printf("[SEAT] ", "keyboard_release: WARNING - keyboard_resource mismatch (seat->keyboard_resource=%p, resource=%p)\n", 
                      (void *)seat->keyboard_resource, (void *)resource);
        }
    }
    // Clear user data before destroying to prevent use-after-free
    wl_resource_set_user_data(resource, NULL);
    wl_resource_destroy(resource);
}

void wl_seat_set_capabilities(struct wl_seat_impl *seat, uint32_t capabilities) {
    seat->capabilities = capabilities;
}

uint32_t wl_seat_get_serial(struct wl_seat_impl *seat) {
    return ++seat->serial;
}

void wl_seat_set_focused_surface(struct wl_seat_impl *seat, void *surface) {
    seat->focused_surface = surface;
    // For simplicity, pointer focus follows keyboard focus
    // In a full compositor, pointer focus would be independent
    seat->pointer_focused_surface = surface;
}

void wl_seat_send_pointer_enter(struct wl_seat_impl *seat, struct wl_resource *surface, uint32_t serial, double x, double y) {
    if (!seat->pointer_resource || !surface) return;
    // Verify pointer resource is still valid before sending event
    if (wl_resource_get_user_data(seat->pointer_resource) == NULL) {
        return; // Pointer resource was destroyed
    }
    // Verify surface resource is still valid
    if (wl_resource_get_user_data(surface) == NULL) {
        return; // Surface resource was destroyed
    }

    // Get the surface implementation from the resource
    struct wl_surface_impl *surface_impl = wl_resource_get_user_data(surface);
    if (!surface_impl) {
        return; // Surface was destroyed
    }

    // If entering a different surface, send leave to the previous one first
    if (seat->pointer_focused_surface != surface_impl && seat->pointer_focused_surface) {
        struct wl_surface_impl *prev = (struct wl_surface_impl *)seat->pointer_focused_surface;
        if (prev->resource && wl_resource_get_user_data(prev->resource) != NULL) {
            uint32_t leave_serial = wl_seat_get_serial(seat);
            log_printf("[SEAT] ", "wl_seat_send_pointer_enter: sending leave to previous surface %p\n", (void *)prev);
            wl_seat_send_pointer_leave(seat, prev->resource, leave_serial);
        }
    }

    // Clear pressed buttons when entering a new surface (fresh start)
    seat->pressed_buttons = 0;
    
    wl_fixed_t fx = wl_fixed_from_double(x);
    wl_fixed_t fy = wl_fixed_from_double(y);
    
    wl_pointer_send_enter(seat->pointer_resource, serial, surface, fx, fy);

    // Update pointer focus
    seat->pointer_focused_surface = surface_impl;
    log_printf("[SEAT] ", "wl_seat_send_pointer_enter: pointer focus set to surface %p\n", (void *)surface_impl);
}

void wl_seat_send_pointer_leave(struct wl_seat_impl *seat, struct wl_resource *surface, uint32_t serial) {
    if (!seat->pointer_resource || !surface) return;
    // Verify pointer resource is still valid before sending event
    if (wl_resource_get_user_data(seat->pointer_resource) == NULL) {
        return; // Pointer resource was destroyed
    }
    // Verify surface resource is still valid
    if (wl_resource_get_user_data(surface) == NULL) {
        return; // Surface resource was destroyed
    }
    
    // Clear pressed buttons when pointer leaves (Wayland protocol requirement)
    // Any buttons that were pressed must be considered released when pointer leaves
    if (seat->pressed_buttons != 0) {
        log_printf("[SEAT] ", "wl_seat_send_pointer_leave: clearing pressed buttons (bitmask=0x%X)\n", seat->pressed_buttons);
        seat->pressed_buttons = 0;
    }
    
    wl_pointer_send_leave(seat->pointer_resource, serial, surface);

    // Clear pointer focus
    seat->pointer_focused_surface = NULL;
    log_printf("[SEAT] ", "wl_seat_send_pointer_leave: pointer focus cleared\n");
}

void wl_seat_send_pointer_motion(struct wl_seat_impl *seat, uint32_t time, double x, double y) {
    if (!seat || !seat->pointer_resource) return;
    // Verify pointer resource is still valid before sending event
    if (wl_resource_get_user_data(seat->pointer_resource) == NULL) {
        seat->pointer_resource = NULL; // Clear invalid pointer
        return; // Pointer resource was destroyed
    }

    // For simplicity, assume pointer is always over the focused surface (toplevel)
    // In a full compositor, you'd need to check which surface contains (x,y)
    struct wl_surface_impl *current_surface = (struct wl_surface_impl *)seat->focused_surface;

    // If we don't have a focused surface yet, don't send motion events
    if (!current_surface || !current_surface->resource ||
        wl_resource_get_user_data(current_surface->resource) == NULL) {
        return;
    }

    // Send enter event if this is the first time we're interacting with this surface
    if (seat->pointer_focused_surface != current_surface) {
        // Send leave event for previous surface if any
        if (seat->pointer_focused_surface && ((struct wl_surface_impl *)seat->pointer_focused_surface)->resource) {
            struct wl_surface_impl *prev = (struct wl_surface_impl *)seat->pointer_focused_surface;
            if (wl_resource_get_user_data(prev->resource) != NULL) {
                uint32_t serial = wl_seat_get_serial(seat);
                log_printf("[SEAT] ", "wl_seat_send_pointer_motion: sending leave to surface %p\n", (void *)prev);
                wl_seat_send_pointer_leave(seat, prev->resource, serial);
            }
        }

        // Send enter event for new surface
        uint32_t serial = wl_seat_get_serial(seat);
        wl_fixed_t fx = wl_fixed_from_double(x);
        wl_fixed_t fy = wl_fixed_from_double(y);
        log_printf("[SEAT] ", "wl_seat_send_pointer_motion: sending enter to surface %p at (%.1f, %.1f)\n",
                  (void *)current_surface, x, y);
        wl_seat_send_pointer_enter(seat, current_surface->resource, serial, fx, fy);

        // Update pointer focus
        seat->pointer_focused_surface = current_surface;
    }

    // Always send motion event to the focused surface
    wl_fixed_t fx = wl_fixed_from_double(x);
    wl_fixed_t fy = wl_fixed_from_double(y);
    
    // Log cursor position for debugging
    log_printf("[CURSOR] ", "mouse motion: position=(%.1f, %.1f), surface=%p, time=%u\n", 
               x, y, (void *)current_surface, time);
    
    wl_pointer_send_motion(seat->pointer_resource, time, fx, fy);
    
    // Flush events to client immediately so input is processed right away
    struct wl_client *client = wl_resource_get_client(seat->pointer_resource);
    if (client) {
        wl_client_flush(client);
    }
}

void wl_seat_send_pointer_button(struct wl_seat_impl *seat, uint32_t serial, uint32_t time, uint32_t button, uint32_t state) {
    if (!seat || !seat->pointer_resource) return;
    // Verify pointer resource is still valid before sending event
    if (wl_resource_get_user_data(seat->pointer_resource) == NULL) {
        seat->pointer_resource = NULL; // Clear invalid pointer
        return; // Pointer resource was destroyed
    }

    // Only send button events if the pointer is currently focused on a surface
    // This prevents "stray button release events" when the pointer hasn't entered any surface
    if (!seat->pointer_focused_surface) {
        log_printf("[SEAT] ", "wl_seat_send_pointer_button: no pointer focus, ignoring button event (button=%u, state=%u)\n", button, state);
        return;
    }

    // Track button state to prevent duplicate press/release events
    // Wayland protocol requires: can only send press once, and release only for pressed buttons
    if (state == WL_POINTER_BUTTON_STATE_PRESSED) {
        // Check if button is already pressed - if so, ignore duplicate press
        if (button >= 272 && button < 272 + 32) {
            uint32_t bit = button - 272;
            uint32_t button_mask = (1U << bit);
            
            if (seat->pressed_buttons & button_mask) {
                // Button is already pressed - ignore duplicate press event
                log_printf("[SEAT] ", "wl_seat_send_pointer_button: ignoring duplicate press for button %u (already pressed, bitmask=0x%X)\n", button, seat->pressed_buttons);
                return;
            }
            
            // Mark button as pressed
            seat->pressed_buttons |= button_mask;
            log_printf("[SEAT] ", "wl_seat_send_pointer_button: button %u pressed (bitmask=0x%X)\n", button, seat->pressed_buttons);
        }
        wl_pointer_send_button(seat->pointer_resource, serial, time, button, state);
    } else if (state == WL_POINTER_BUTTON_STATE_RELEASED) {
        // Only send release if button was previously pressed
        if (button >= 272 && button < 272 + 32) {
            uint32_t bit = button - 272;
            uint32_t button_mask = (1U << bit);
            if (seat->pressed_buttons & button_mask) {
                seat->pressed_buttons &= ~button_mask;
                log_printf("[SEAT] ", "wl_seat_send_pointer_button: button %u released (bitmask=0x%X)\n", button, seat->pressed_buttons);
                wl_pointer_send_button(seat->pointer_resource, serial, time, button, state);
            } else {
                log_printf("[SEAT] ", "wl_seat_send_pointer_button: ignoring stray release for button %u (not pressed, bitmask=0x%X)\n", button, seat->pressed_buttons);
            }
        } else {
            log_printf("[SEAT] ", "wl_seat_send_pointer_button: ignoring release for invalid button %u\n", button);
        }
    }
}

void wl_seat_send_keyboard_enter(struct wl_seat_impl *seat, struct wl_resource *surface, uint32_t serial, struct wl_array *keys) {
    if (!seat->keyboard_resource || !surface) return;
    // Verify keyboard resource is still valid before sending event
    if (wl_resource_get_user_data(seat->keyboard_resource) == NULL) {
        return; // Keyboard resource was destroyed
    }
    // Verify surface resource is still valid
    if (wl_resource_get_user_data(surface) == NULL) {
        return; // Surface resource was destroyed
    }
    log_printf("[SEAT] ", "wl_seat_send_keyboard_enter: sending enter event to surface %p\n", (void *)surface);
    wl_keyboard_send_enter(seat->keyboard_resource, serial, surface, keys);
    
    // Protocol requirement: MUST send modifiers event after enter
    // Send with no modifiers pressed (initial state)
    uint32_t mods_serial = wl_seat_get_serial(seat);
    wl_keyboard_send_modifiers(seat->keyboard_resource, mods_serial, 0, 0, 0, 0);
    log_printf("[SEAT] ", "wl_seat_send_keyboard_enter: sent modifiers event (no modifiers)\n");
}

void wl_seat_send_keyboard_leave(struct wl_seat_impl *seat, struct wl_resource *surface, uint32_t serial) {
    if (!seat->keyboard_resource || !surface) return;
    // Verify keyboard resource is still valid before sending event
    if (wl_resource_get_user_data(seat->keyboard_resource) == NULL) {
        return; // Keyboard resource was destroyed
    }
    // Verify surface resource is still valid
    if (wl_resource_get_user_data(surface) == NULL) {
        return; // Surface resource was destroyed
    }
    wl_keyboard_send_leave(seat->keyboard_resource, serial, surface);
}

// Helper function to check if a keycode is a modifier key and update modifier state
// Returns true if modifier state changed, false otherwise
static bool update_modifier_state(struct wl_seat_impl *seat, uint32_t key, uint32_t state) {
    // XKB modifier masks (from xkb_keysym.h)
    // These are bit positions in the modifier state
    uint32_t shift_mask = 1 << 0;   // Shift
    uint32_t lock_mask = 1 << 1;    // Caps Lock
    uint32_t control_mask = 1 << 2; // Control
    uint32_t mod1_mask = 1 << 3;    // Alt/Meta
    uint32_t mod4_mask = 1 << 6;    // Mod4 (Super/Windows)
    
    uint32_t modifier_mask = 0;
    bool state_changed = false;
    
    // Map Linux keycodes to modifier masks
    // Keycode 42 = Left Control, 54 = Right Shift, 56 = Left Shift, 29 = Left Alt, etc.
    switch (key) {
        case 42:  // Left Control
        case 97:  // Right Control
            modifier_mask = control_mask;
            break;
        case 56:  // Left Shift
        case 54:  // Right Shift
            modifier_mask = shift_mask;
            break;
        case 29:  // Left Alt
        case 100: // Right Alt
            modifier_mask = mod1_mask; // Alt is typically mod1
            break;
        case 58:  // Caps Lock
            modifier_mask = lock_mask;
            break;
        case 125: // Left Super/Command
        case 126: // Right Super/Command
            modifier_mask = mod4_mask; // Super/Command is typically mod4
            break;
        default:
            return false; // Not a modifier key
    }
    
    // Update modifier state based on key press/release
    uint32_t old_depressed = seat->mods_depressed;
    
    if (state == WL_KEYBOARD_KEY_STATE_PRESSED) {
        seat->mods_depressed |= modifier_mask;
        if (key == 58) { // Caps Lock - toggle locked state
            seat->mods_locked ^= modifier_mask;
            state_changed = true; // Caps Lock always changes state
        } else {
            state_changed = (old_depressed != seat->mods_depressed);
        }
    } else if (state == WL_KEYBOARD_KEY_STATE_RELEASED) {
        seat->mods_depressed &= ~modifier_mask;
        state_changed = (old_depressed != seat->mods_depressed);
        // Note: Caps Lock locked state persists until toggled again
    }
    
    return state_changed;
}

void wl_seat_send_keyboard_modifiers(struct wl_seat_impl *seat, uint32_t serial) {
    if (!seat || !seat->keyboard_resource) return;
    if (!seat->focused_surface) return;
    
    // Verify keyboard resource is still valid
    if (wl_resource_get_user_data(seat->keyboard_resource) == NULL) {
        seat->keyboard_resource = NULL;
        return;
    }
    
    wl_keyboard_send_modifiers(seat->keyboard_resource, serial,
                               seat->mods_depressed,
                               seat->mods_latched,
                               seat->mods_locked,
                               seat->group);
    
    // Flush client connection immediately to reduce input latency
    struct wl_client *client = wl_resource_get_client(seat->keyboard_resource);
    if (client) {
        wl_client_flush(client);
    }
}

void wl_seat_send_keyboard_key(struct wl_seat_impl *seat, uint32_t serial, uint32_t time, uint32_t key, uint32_t state) {
    if (!seat || !seat->keyboard_resource) {
        return;
    }

    // Only send keyboard events if there's a focused surface
    // Keyboard events should only go to the client that has keyboard focus
    if (!seat->focused_surface) {
        return; // No focused surface, don't send keyboard events
    }

    // Update modifier state if this is a modifier key
    // Only send modifier update if modifier state actually changed
    bool modifier_changed = update_modifier_state(seat, key, state);
    
    // Verify keyboard resource is still valid before sending event
    // If the client disconnected, the resource will be destroyed
    struct wl_client *client = wl_resource_get_client(seat->keyboard_resource);
    if (!client) {
        // Client disconnected, resource is invalid - clear it
        seat->keyboard_resource = NULL;
        return;
    }
    // Also verify the resource's user_data is still valid
    if (wl_resource_get_user_data(seat->keyboard_resource) == NULL) {
        // Resource was destroyed, clear it
        seat->keyboard_resource = NULL;
        return;
    }
    
    // Verify that the keyboard resource belongs to the client that owns the focused surface
    // For waypipe, all surfaces come through waypipe's client, so this should match
    // But if it doesn't, we should still send the event to the keyboard resource we have
    // since waypipe will handle forwarding
    struct wl_surface_impl *focused = (struct wl_surface_impl *)seat->focused_surface;
    if (focused && focused->resource) {
        struct wl_client *focused_client = wl_resource_get_client(focused->resource);
        // Don't check for mismatch - waypipe will handle forwarding if needed
        (void)focused_client; // Suppress unused variable warning
    }
    
    wl_keyboard_send_key(seat->keyboard_resource, serial, time, key, state);
    
    // Send modifier update after key event if modifier state changed
    // This ensures the client knows the current modifier state
    if (modifier_changed) {
        uint32_t mods_serial = wl_seat_get_serial(seat);
        wl_seat_send_keyboard_modifiers(seat, mods_serial);
    }
    
    // Flush client connection immediately to reduce input latency
    // Reuse the client variable already defined above
    if (client) {
        wl_client_flush(client);
    }
}

void wl_seat_send_touch_down(struct wl_seat_impl *seat, uint32_t serial, uint32_t time, struct wl_resource *surface, int32_t id, wl_fixed_t x, wl_fixed_t y) {
    if (!seat->touch_resource) return;
    wl_touch_send_down(seat->touch_resource, serial, time, surface, id, x, y);
}

void wl_seat_send_touch_up(struct wl_seat_impl *seat, uint32_t serial, uint32_t time, int32_t id) {
    if (!seat->touch_resource) return;
    wl_touch_send_up(seat->touch_resource, serial, time, id);
}

void wl_seat_send_touch_motion(struct wl_seat_impl *seat, uint32_t time, int32_t id, wl_fixed_t x, wl_fixed_t y) {
    if (!seat->touch_resource) return;
    wl_touch_send_motion(seat->touch_resource, time, id, x, y);
}

void wl_seat_send_touch_frame(struct wl_seat_impl *seat) {
    if (!seat->touch_resource) return;
    wl_touch_send_frame(seat->touch_resource);
}

void wl_seat_send_touch_cancel(struct wl_seat_impl *seat) {
    if (!seat->touch_resource) return;
    wl_touch_send_cancel(seat->touch_resource);
}

