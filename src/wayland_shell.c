#include "wayland_shell.h"
#include "wayland_compositor.h"
#include "logging.h"
#include <wayland-server.h>
#include <wayland-server-protocol.h>
#include <stdlib.h>
#include <string.h>

// Event opcodes for wl_shell_surface (from wayland.xml)
#define WL_SHELL_SURFACE_PING 0
#define WL_SHELL_SURFACE_CONFIGURE 1
#define WL_SHELL_SURFACE_POPUP_DONE 2

// Legacy wl_shell protocol implementation
// Deprecated but still used by older clients

struct wl_shell_surface_impl {
    struct wl_resource *resource;
    struct wl_surface_impl *surface;
    uint32_t pending_resize;
    uint32_t pending_move;
    bool configured;
};

static struct wl_shell_surface_impl *shell_surface_from_resource(struct wl_resource *resource) {
    return wl_resource_get_user_data(resource);
}

static void shell_surface_pong(struct wl_client *client, struct wl_resource *resource, uint32_t serial) {
    (void)client;
    (void)resource;
    (void)serial;
    log_printf("[WL_SHELL] ", "shell_surface_pong() - serial=%u\n", serial);
}

static void shell_surface_move(struct wl_client *client, struct wl_resource *resource,
                               struct wl_resource *seat_resource, uint32_t serial) {
    (void)client;
    (void)seat_resource;
    (void)serial;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (shell_surface) {
        shell_surface->pending_move = serial;
        log_printf("[WL_SHELL] ", "shell_surface_move() - surface=%p, serial=%u\n",
                   (void *)shell_surface->surface, serial);
    }
}

static void shell_surface_resize(struct wl_client *client, struct wl_resource *resource,
                                 struct wl_resource *seat_resource, uint32_t serial, uint32_t edges) {
    (void)client;
    (void)seat_resource;
    (void)serial;
    (void)edges;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (shell_surface) {
        shell_surface->pending_resize = serial;
        log_printf("[WL_SHELL] ", "shell_surface_resize() - surface=%p, serial=%u, edges=%u\n",
                   (void *)shell_surface->surface, serial, edges);
    }
}

static void shell_surface_set_toplevel(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (!shell_surface || !shell_surface->surface) {
        return;
    }
    
    shell_surface->configured = true;
    
    // Send configure event (0,0 means client decides size)
    // Use wayland-server-protocol.h event sending
    wl_resource_post_event(resource, WL_SHELL_SURFACE_CONFIGURE, WL_SHELL_SURFACE_RESIZE_NONE, 0, 0);
    wl_resource_post_event(resource, WL_SHELL_SURFACE_PING, 0);
    
    log_printf("[WL_SHELL] ", "shell_surface_set_toplevel() - surface=%p\n",
               (void *)shell_surface->surface);
}

static void shell_surface_set_transient(struct wl_client *client, struct wl_resource *resource,
                                        struct wl_resource *parent_resource, int32_t x, int32_t y,
                                        uint32_t flags) {
    (void)client;
    (void)parent_resource;
    (void)x;
    (void)y;
    (void)flags;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (!shell_surface || !shell_surface->surface) {
        return;
    }
    
    shell_surface->configured = true;
    
    // Send configure event for transient window
    wl_resource_post_event(resource, WL_SHELL_SURFACE_CONFIGURE, WL_SHELL_SURFACE_RESIZE_NONE, 0, 0);
    
    log_printf("[WL_SHELL] ", "shell_surface_set_transient() - surface=%p, x=%d, y=%d, flags=%u\n",
               (void *)shell_surface->surface, x, y, flags);
}

static void shell_surface_set_fullscreen(struct wl_client *client, struct wl_resource *resource,
                                         uint32_t method, uint32_t framerate,
                                         struct wl_resource *output_resource) {
    (void)client;
    (void)method;
    (void)framerate;
    (void)output_resource;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (!shell_surface || !shell_surface->surface) {
        return;
    }
    
    shell_surface->configured = true;
    
    // Send configure event for fullscreen
    // TODO: Get actual output size
    wl_resource_post_event(resource, WL_SHELL_SURFACE_CONFIGURE, WL_SHELL_SURFACE_RESIZE_NONE, 1920, 1080);
    
    log_printf("[WL_SHELL] ", "shell_surface_set_fullscreen() - surface=%p\n",
               (void *)shell_surface->surface);
}

static void shell_surface_set_popup(struct wl_client *client, struct wl_resource *resource,
                                    struct wl_resource *seat_resource, uint32_t serial,
                                    struct wl_resource *parent_resource, int32_t x, int32_t y,
                                    uint32_t flags) {
    (void)client;
    (void)seat_resource;
    (void)serial;
    (void)parent_resource;
    (void)x;
    (void)y;
    (void)flags;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (!shell_surface || !shell_surface->surface) {
        return;
    }
    
    shell_surface->configured = true;
    
    // Send configure event for popup
    wl_resource_post_event(resource, WL_SHELL_SURFACE_CONFIGURE, WL_SHELL_SURFACE_RESIZE_NONE, 0, 0);
    
    log_printf("[WL_SHELL] ", "shell_surface_set_popup() - surface=%p, x=%d, y=%d\n",
               (void *)shell_surface->surface, x, y);
}

static void shell_surface_set_maximized(struct wl_client *client, struct wl_resource *resource,
                                        struct wl_resource *output_resource) {
    (void)client;
    (void)output_resource;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (!shell_surface || !shell_surface->surface) {
        return;
    }
    
    shell_surface->configured = true;
    
    // Send configure event for maximized window
    // TODO: Get actual output size
    wl_resource_post_event(resource, WL_SHELL_SURFACE_CONFIGURE, WL_SHELL_SURFACE_RESIZE_NONE, 1920, 1080);
    
    log_printf("[WL_SHELL] ", "shell_surface_set_maximized() - surface=%p\n",
               (void *)shell_surface->surface);
}

static void shell_surface_set_title(struct wl_client *client, struct wl_resource *resource,
                                    const char *title) {
    (void)client;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (shell_surface && shell_surface->surface) {
        log_printf("[WL_SHELL] ", "shell_surface_set_title() - surface=%p, title=%s\n",
                   (void *)shell_surface->surface, title ? title : "NULL");
    }
}

static void shell_surface_set_class(struct wl_client *client, struct wl_resource *resource,
                                    const char *class_) {
    (void)client;
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (shell_surface && shell_surface->surface) {
        log_printf("[WL_SHELL] ", "shell_surface_set_class() - surface=%p, class=%s\n",
                   (void *)shell_surface->surface, class_ ? class_ : "NULL");
    }
}

static void shell_surface_resource_destroy(struct wl_resource *resource) {
    struct wl_shell_surface_impl *shell_surface = shell_surface_from_resource(resource);
    if (shell_surface && shell_surface->surface) {
        shell_surface->surface->user_data = NULL;  // Clear reference
    }
    free(shell_surface);
}

static const struct wl_shell_surface_interface shell_surface_interface = {
    .pong = shell_surface_pong,
    .move = shell_surface_move,
    .resize = shell_surface_resize,
    .set_toplevel = shell_surface_set_toplevel,
    .set_transient = shell_surface_set_transient,
    .set_fullscreen = shell_surface_set_fullscreen,
    .set_popup = shell_surface_set_popup,
    .set_maximized = shell_surface_set_maximized,
    .set_title = shell_surface_set_title,
    .set_class = shell_surface_set_class,
};

struct wl_shell_impl {
    struct wl_global *global;
    struct wl_display *display;
};

static void shell_get_shell_surface(struct wl_client *client, struct wl_resource *resource,
                                    uint32_t id, struct wl_resource *surface_resource) {
    struct wl_surface_impl *surface = wl_resource_get_user_data(surface_resource);
    if (!surface) {
        wl_resource_post_error(resource, WL_SHELL_ERROR_ROLE,
                              "invalid surface");
        return;
    }
    
    // Check if surface already has a shell surface
    if (surface->user_data) {
        wl_resource_post_error(resource, WL_SHELL_ERROR_ROLE,
                              "surface already has a role");
        return;
    }
    
    struct wl_shell_surface_impl *shell_surface = calloc(1, sizeof(*shell_surface));
    if (!shell_surface) {
        wl_client_post_no_memory(client);
        return;
    }
    
    uint32_t version = (uint32_t)wl_resource_get_version(resource);
    struct wl_resource *shell_surface_resource = wl_resource_create(client, &wl_shell_surface_interface, (int)version, id);
    if (!shell_surface_resource) {
        free(shell_surface);
        wl_client_post_no_memory(client);
        return;
    }
    
    shell_surface->resource = shell_surface_resource;
    shell_surface->surface = surface;
    surface->user_data = shell_surface;  // Store shell surface in surface user_data
    
    wl_resource_set_implementation(shell_surface_resource, &shell_surface_interface, shell_surface, shell_surface_resource_destroy);
    
    log_printf("[WL_SHELL] ", "get_shell_surface() - client=%p, surface=%p, shell_surface=%p\n",
               (void *)client, (void *)surface, (void *)shell_surface);
}

static const struct wl_shell_interface shell_interface = {
    .get_shell_surface = shell_get_shell_surface,
};

static void shell_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_shell_impl *shell = data;
    
    struct wl_resource *resource = wl_resource_create(client, &wl_shell_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &shell_interface, shell, NULL);
    
    log_printf("[WL_SHELL] ", "shell_bind() - client=%p, version=%u, id=%u\n",
               (void *)client, version, id);
}

struct wl_shell_impl *wl_shell_create(struct wl_display *display) {
    struct wl_shell_impl *shell = calloc(1, sizeof(*shell));
    if (!shell) {
        return NULL;
    }
    
    shell->display = display;
    shell->global = wl_global_create(display, &wl_shell_interface, 1, shell, shell_bind);
    
    if (!shell->global) {
        free(shell);
        return NULL;
    }
    
    log_printf("[WL_SHELL] ", "wl_shell_create() - global created\n");
    return shell;
}

void wl_shell_destroy(struct wl_shell_impl *shell) {
    if (!shell) {
        return;
    }
    
    if (shell->global) {
        wl_global_destroy(shell->global);
    }
    
    free(shell);
}

