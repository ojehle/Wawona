#include "wayland_linux_dmabuf.h"
#include "wayland_compositor.h"
#include "metal_dmabuf.h"
#include "logging.h"
#include <wayland-server.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>

// Define interface structures
const struct wl_interface zwp_linux_dmabuf_v1_interface = {
    "zwp_linux_dmabuf_v1", 4,  // Version 4 supports feedback
    0, NULL,
    0, NULL
};

const struct wl_interface zwp_linux_buffer_params_v1_interface = {
    "zwp_linux_buffer_params_v1", 4,
    0, NULL,
    0, NULL
};

// DRM format codes (from drm_fourcc.h)
#define DRM_FORMAT_ARGB8888 0x34325241
#define DRM_FORMAT_XRGB8888 0x34325258
#define DRM_FORMAT_ABGR8888 0x34324241
#define DRM_FORMAT_XBGR8888 0x34324258
#define DRM_FORMAT_RGBA8888 0x41424752
#define DRM_FORMAT_RGBX8888 0x58424752
#define DRM_FORMAT_BGRA8888 0x41424742
#define DRM_FORMAT_BGRX8888 0x58424742
#define DRM_FORMAT_MOD_INVALID 0x00ffffffffffffffULL

// Buffer plane data
struct dmabuf_plane {
    int32_t fd;
    uint32_t offset;
    uint32_t stride;
    uint64_t modifier;
    bool used;
};

// Buffer params implementation
struct wl_linux_buffer_params_impl {
    struct wl_resource *resource;
    struct dmabuf_plane planes[4];  // Max 4 planes
    uint32_t num_planes;
    bool used;
    int32_t width;
    int32_t height;
    uint32_t format;
    uint32_t flags;
};

static struct wl_linux_buffer_params_impl *params_from_resource(struct wl_resource *resource) {
    return wl_resource_get_user_data(resource);
}

// Buffer destroy handler
static void buffer_destroy_handler(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    
    // Clear buffer reference from any surfaces
    wl_compositor_clear_buffer_reference(resource);
    
    wl_resource_destroy(resource);
}

static const struct wl_buffer_interface buffer_interface = {
    .destroy = buffer_destroy_handler,
};

// Buffer destructor
static void buffer_destroy(struct wl_resource *resource) {
    struct metal_dmabuf_buffer *buf_data = wl_resource_get_user_data(resource);
    if (buf_data) {
        metal_dmabuf_destroy_buffer(buf_data);
    }
}

// Create wl_buffer from DMA-BUF params
static struct wl_resource *create_dmabuf_buffer(struct wl_client *client,
                                                struct wl_linux_buffer_params_impl *params,
                                                uint32_t buffer_id) {
    // Validate we have at least one plane
    if (params->num_planes == 0) {
        wl_resource_post_error(params->resource, ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_INCOMPLETE,
                              "no planes added");
        return NULL;
    }
    
    // Validate dimensions
    if (params->width <= 0 || params->height <= 0) {
        wl_resource_post_error(params->resource, ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_INVALID_DIMENSIONS,
                              "invalid dimensions");
        return NULL;
    }
    
    // For macOS, we'll use IOSurface to create Metal-compatible buffers
    // In a real implementation, we'd import the DMA-BUF fd and convert to IOSurface
    // For now, create a basic buffer structure
    
    // Create buffer resource
    uint32_t version = (uint32_t)wl_resource_get_version(params->resource);
    struct wl_resource *buffer_resource = wl_resource_create(client, &wl_buffer_interface, (int)version, buffer_id);
    if (!buffer_resource) {
        wl_client_post_no_memory(client);
        return NULL;
    }
    
    // Create Metal DMA-BUF buffer wrapper
    // Note: In a full implementation, we'd import the actual DMA-BUF fd
    // For now, create a placeholder that can be used with IOSurface
    struct metal_dmabuf_buffer *dmabuf_buf = metal_dmabuf_create_buffer(
        (uint32_t)params->width, (uint32_t)params->height, (uint32_t)params->format);
    
    if (!dmabuf_buf) {
        wl_resource_destroy(buffer_resource);
        return NULL;
    }
    
    // Store buffer data
    wl_resource_set_implementation(buffer_resource, &buffer_interface, dmabuf_buf, buffer_destroy);
    
    log_printf("[DMABUF] ", "create_dmabuf_buffer() - buffer=%p, size=%dx%d, format=0x%x\n",
               (void *)buffer_resource, params->width, params->height, params->format);
    
    return buffer_resource;
}

// Buffer params: add plane
static void params_add(struct wl_client *client, struct wl_resource *resource,
                      int32_t fd, uint32_t plane_idx, uint32_t offset, uint32_t stride,
                      uint32_t modifier_hi, uint32_t modifier_lo) {
    (void)client;
    struct wl_linux_buffer_params_impl *params = params_from_resource(resource);
    if (!params) {
        return;
    }
    
    if (params->used) {
        wl_resource_post_error(resource, ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_ALREADY_USED,
                              "params already used");
        close(fd);
        return;
    }
    
    if (plane_idx >= 4) {
        wl_resource_post_error(resource, ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_PLANE_IDX,
                              "plane index out of bounds");
        close(fd);
        return;
    }
    
    if (params->planes[plane_idx].used) {
        wl_resource_post_error(resource, ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_PLANE_SET,
                              "plane already set");
        close(fd);
        return;
    }
    
    params->planes[plane_idx].fd = fd;
    params->planes[plane_idx].offset = offset;
    params->planes[plane_idx].stride = stride;
    params->planes[plane_idx].modifier = ((uint64_t)modifier_hi << 32) | modifier_lo;
    params->planes[plane_idx].used = true;
    
    if (plane_idx >= params->num_planes) {
        params->num_planes = plane_idx + 1;
    }
    
    log_printf("[DMABUF] ", "params_add() - plane=%u, fd=%d, stride=%u, modifier=0x%llx\n",
               plane_idx, fd, stride, (unsigned long long)params->planes[plane_idx].modifier);
}

// Buffer params: create (async)
static void params_create(struct wl_client *client, struct wl_resource *resource,
                         int32_t width, int32_t height, uint32_t format, uint32_t flags) {
    (void)client;
    struct wl_linux_buffer_params_impl *params = params_from_resource(resource);
    if (!params) {
        return;
    }
    
    if (params->used) {
        wl_resource_post_error(resource, ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_ALREADY_USED,
                              "params already used");
        return;
    }
    
    params->used = true;
    params->width = width;
    params->height = height;
    params->format = format;
    params->flags = flags;
    
    // Create buffer
    uint32_t buffer_id = wl_resource_get_id(resource) + 1000;  // Simple ID generation
    struct wl_resource *buffer_resource = create_dmabuf_buffer(client, params, buffer_id);
    
    if (buffer_resource) {
        // Send created event
        wl_resource_post_event(resource, ZWP_LINUX_BUFFER_PARAMS_V1_CREATED, buffer_resource);
    } else {
        // Send failed event
        wl_resource_post_event(resource, ZWP_LINUX_BUFFER_PARAMS_V1_FAILED);
    }
}

// Buffer params: create_immed (synchronous)
static void params_create_immed(struct wl_client *client, struct wl_resource *resource,
                               uint32_t buffer_id, int32_t width, int32_t height,
                               uint32_t format, uint32_t flags) {
    struct wl_linux_buffer_params_impl *params = params_from_resource(resource);
    if (!params) {
        return;
    }
    
    if (params->used) {
        wl_resource_post_error(resource, ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_ALREADY_USED,
                              "params already used");
        return;
    }
    
    params->used = true;
    params->width = width;
    params->height = height;
    params->format = format;
    params->flags = flags;
    
    // Create buffer immediately
    struct wl_resource *buffer_resource = create_dmabuf_buffer(client, params, buffer_id);
    
    if (!buffer_resource) {
        // On failure, send failed event
        wl_resource_post_event(resource, ZWP_LINUX_BUFFER_PARAMS_V1_FAILED);
    }
    // On success, no event is sent (buffer is ready immediately)
}

// Buffer params: destroy
static void params_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    struct wl_linux_buffer_params_impl *params = params_from_resource(resource);
    if (params) {
        // Close all FDs
        for (uint32_t i = 0; i < params->num_planes; i++) {
            if (params->planes[i].used && params->planes[i].fd >= 0) {
                close(params->planes[i].fd);
            }
        }
        free(params);
    }
    wl_resource_destroy(resource);
}

static const struct zwp_linux_buffer_params_v1_interface params_interface = {
    .destroy = params_destroy,
    .add = params_add,
    .create = params_create,
    .create_immed = params_create_immed,
};

// Manager: create_params
static void dmabuf_create_params(struct wl_client *client, struct wl_resource *resource,
                                 uint32_t params_id) {
    struct wl_linux_buffer_params_impl *params = calloc(1, sizeof(*params));
    if (!params) {
        wl_client_post_no_memory(client);
        return;
    }
    
    uint32_t version = (uint32_t)wl_resource_get_version(resource);
    struct wl_resource *params_resource = wl_resource_create(client, &zwp_linux_buffer_params_v1_interface, (int)version, params_id);
    if (!params_resource) {
        free(params);
        wl_client_post_no_memory(client);
        return;
    }
    
    params->resource = params_resource;
    params->num_planes = 0;
    params->used = false;
    
    // Initialize planes
    for (int i = 0; i < 4; i++) {
        params->planes[i].fd = -1;
        params->planes[i].used = false;
    }
    
    wl_resource_set_implementation(params_resource, &params_interface, params, NULL);
    
    log_printf("[DMABUF] ", "dmabuf_create_params() - params=%p\n", (void *)params_resource);
}

// Manager: destroy
static void dmabuf_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

// Manager: get_default_feedback (version 4+)
static void dmabuf_get_default_feedback(struct wl_client *client, struct wl_resource *resource,
                                       uint32_t id) {
    (void)client;
    (void)resource;
    (void)id;
    // TODO: Implement feedback for version 4+
    log_printf("[DMABUF] ", "get_default_feedback() - not yet implemented\n");
}

// Manager: get_surface_feedback (version 4+)
static void dmabuf_get_surface_feedback(struct wl_client *client, struct wl_resource *resource,
                                        uint32_t id, struct wl_resource *surface) {
    (void)client;
    (void)resource;
    (void)id;
    (void)surface;
    // TODO: Implement surface feedback for version 4+
    log_printf("[DMABUF] ", "get_surface_feedback() - not yet implemented\n");
}

static const struct zwp_linux_dmabuf_v1_interface dmabuf_interface = {
    .destroy = dmabuf_destroy,
    .create_params = dmabuf_create_params,
    .get_default_feedback = dmabuf_get_default_feedback,
    .get_surface_feedback = dmabuf_get_surface_feedback,
};

struct wl_linux_dmabuf_manager_impl {
    struct wl_global *global;
    struct wl_display *display;
};

static void dmabuf_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_linux_dmabuf_manager_impl *dmabuf = data;
    
    struct wl_resource *resource = wl_resource_create(client, &zwp_linux_dmabuf_v1_interface, (int)version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &dmabuf_interface, dmabuf, NULL);
    
    // Advertise supported formats (deprecated in v4+, but send for compatibility)
    if (version < 4) {
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_FORMAT, DRM_FORMAT_ARGB8888);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_FORMAT, DRM_FORMAT_XRGB8888);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_FORMAT, DRM_FORMAT_ABGR8888);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_FORMAT, DRM_FORMAT_XBGR8888);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_FORMAT, DRM_FORMAT_RGBA8888);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_FORMAT, DRM_FORMAT_RGBX8888);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_FORMAT, DRM_FORMAT_BGRA8888);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_FORMAT, DRM_FORMAT_BGRX8888);
        
        // Advertise modifiers (DRM_FORMAT_MOD_INVALID means implicit modifier)
        uint32_t mod_hi = (DRM_FORMAT_MOD_INVALID >> 32) & 0xFFFFFFFF;
        uint32_t mod_lo = DRM_FORMAT_MOD_INVALID & 0xFFFFFFFF;
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_MODIFIER, DRM_FORMAT_ARGB8888, mod_hi, mod_lo);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_MODIFIER, DRM_FORMAT_XRGB8888, mod_hi, mod_lo);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_MODIFIER, DRM_FORMAT_ABGR8888, mod_hi, mod_lo);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_MODIFIER, DRM_FORMAT_XBGR8888, mod_hi, mod_lo);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_MODIFIER, DRM_FORMAT_RGBA8888, mod_hi, mod_lo);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_MODIFIER, DRM_FORMAT_RGBX8888, mod_hi, mod_lo);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_MODIFIER, DRM_FORMAT_BGRA8888, mod_hi, mod_lo);
        wl_resource_post_event(resource, ZWP_LINUX_DMABUF_V1_MODIFIER, DRM_FORMAT_BGRX8888, mod_hi, mod_lo);
    }
    
    log_printf("[DMABUF] ", "dmabuf_bind() - client=%p, version=%u, id=%u\n",
               (void *)client, version, id);
}

struct wl_linux_dmabuf_manager_impl *wl_linux_dmabuf_create(struct wl_display *display) {
    struct wl_linux_dmabuf_manager_impl *dmabuf = calloc(1, sizeof(*dmabuf));
    if (!dmabuf) {
        return NULL;
    }
    
    dmabuf->display = display;
    // Version 4 supports feedback, but we advertise v4 for compatibility
    dmabuf->global = wl_global_create(display, &zwp_linux_dmabuf_v1_interface, 4, dmabuf, dmabuf_bind);
    
    if (!dmabuf->global) {
        free(dmabuf);
        return NULL;
    }
    
    log_printf("[DMABUF] ", "wl_linux_dmabuf_create() - global created\n");
    return dmabuf;
}

void wl_linux_dmabuf_destroy(struct wl_linux_dmabuf_manager_impl *dmabuf) {
    if (!dmabuf) {
        return;
    }
    
    if (dmabuf->global) {
        wl_global_destroy(dmabuf->global);
    }
    
    free(dmabuf);
}

