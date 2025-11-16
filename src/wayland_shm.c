#include "wayland_shm.h"
#include "logging.h"
#include <wayland-server-protocol.h>
#include <wayland-server.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>

static void shm_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id);
static void shm_create_pool(struct wl_client *client, struct wl_resource *resource, uint32_t id, int32_t fd, int32_t size);

static void shm_release(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct wl_shm_interface shm_interface = {
    .create_pool = shm_create_pool,
    .release = shm_release,
};

static void shm_pool_create_buffer(struct wl_client *client, struct wl_resource *resource, uint32_t id, int32_t offset, int32_t width, int32_t height, int32_t stride, uint32_t format);
static void shm_pool_destroy(struct wl_client *client, struct wl_resource *resource);
static void shm_pool_resize(struct wl_client *client, struct wl_resource *resource, int32_t size);

static const struct wl_shm_pool_interface shm_pool_interface = {
    .create_buffer = shm_pool_create_buffer,
    .destroy = shm_pool_destroy,
    .resize = shm_pool_resize,
};

struct wl_shm_impl *wl_shm_create(struct wl_display *display) {
    struct wl_shm_impl *shm = calloc(1, sizeof(*shm));
    if (!shm) return NULL;
    
    shm->display = display;
    shm->global = wl_global_create(display, &wl_shm_interface, 1, shm, shm_bind);
    
    if (!shm->global) {
        free(shm);
        return NULL;
    }
    
    return shm;
}

void wl_shm_destroy(struct wl_shm_impl *shm) {
    if (!shm) return;
    
    wl_global_destroy(shm->global);
    free(shm);
}

static void shm_bind(struct wl_client *client, void *data, uint32_t version, uint32_t id) {
    struct wl_shm_impl *shm = data;
    struct wl_resource *resource = wl_resource_create(client, &wl_shm_interface, (int)version, id);
    
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    wl_resource_set_implementation(resource, &shm_interface, shm, NULL);
    
    // Send supported formats
    wl_shm_send_format(resource, WL_SHM_FORMAT_ARGB8888);
    wl_shm_send_format(resource, WL_SHM_FORMAT_XRGB8888);
    wl_shm_send_format(resource, WL_SHM_FORMAT_RGBA8888);
    wl_shm_send_format(resource, WL_SHM_FORMAT_RGBX8888);
    wl_shm_send_format(resource, WL_SHM_FORMAT_ABGR8888);
    wl_shm_send_format(resource, WL_SHM_FORMAT_XBGR8888);
    wl_shm_send_format(resource, WL_SHM_FORMAT_BGRA8888);
    wl_shm_send_format(resource, WL_SHM_FORMAT_BGRX8888);
}

static void shm_create_pool(struct wl_client *client, struct wl_resource *resource, uint32_t id, int32_t fd, int32_t size) {
    struct wl_resource *pool_resource = wl_resource_create(client, &wl_shm_pool_interface, wl_resource_get_version(resource), id);
    
    if (!pool_resource) {
        wl_client_post_no_memory(client);
        close(fd);
        return;
    }
    
    // Store fd and size for buffer creation
    struct shm_pool_data {
        int32_t fd;
        int32_t size;
        void *data;
    };
    
    struct shm_pool_data *pool_data = calloc(1, sizeof(*pool_data));
    if (!pool_data) {
        wl_client_post_no_memory(client);
        close(fd);
        wl_resource_destroy(pool_resource);
        return;
    }
    
    pool_data->fd = fd;
    pool_data->size = size;
    pool_data->data = mmap(NULL, (size_t)size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    
    if (pool_data->data == MAP_FAILED) {
        free(pool_data);
        close(fd);
        wl_resource_destroy(pool_resource);
        return;
    }
    
    wl_resource_set_implementation(pool_resource, &shm_pool_interface, pool_data, NULL);
}


struct shm_pool_data {
    int32_t fd;
    int32_t size;
    void *data;
};

#include "wayland_compositor.h"

// Buffer destroy handler - client can destroy buffers
static void buffer_destroy_handler(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    
    // Clear buffer reference from any surfaces that have this buffer attached
    // This prevents use-after-free when surface tries to use destroyed buffer
    wl_compositor_clear_buffer_reference(resource);
    
    // The destructor callback will handle cleanup
    wl_resource_destroy(resource);
}

// Buffer interface - buffers can be destroyed by the client
static const struct wl_buffer_interface buffer_interface = {
    .destroy = buffer_destroy_handler,
};

// Buffer destructor - sends release event when buffer is destroyed
static void buffer_destroy(struct wl_resource *resource) {
    struct buffer_data *buf_data = wl_resource_get_user_data(resource);
    if (buf_data) {
        free(buf_data);
    }
}

static void shm_pool_create_buffer(struct wl_client *client, struct wl_resource *resource, uint32_t id, int32_t offset, int32_t width, int32_t height, int32_t stride, uint32_t format) {
    struct shm_pool_data *pool_data = wl_resource_get_user_data(resource);
    if (!pool_data) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_STRIDE, "invalid pool");
        return;
    }
    
    // Validate buffer parameters
    if (offset < 0 || width <= 0 || height <= 0) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_STRIDE, "invalid buffer parameters");
        return;
    }
    
    // Validate stride (must be at least width * bytes_per_pixel for common formats)
    // For ARGB8888/XRGB8888, that's 4 bytes per pixel
    if (stride < width * 4) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_STRIDE, "invalid stride");
        return;
    }
    
    // Check buffer fits in pool
    uint32_t buffer_size = (uint32_t)(height * stride);
    if ((uint32_t)offset + buffer_size > (uint32_t)pool_data->size) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_STRIDE, "buffer extends beyond pool");
        return;
    }
    
    struct wl_resource *buffer_resource = wl_resource_create(client, &wl_buffer_interface, wl_resource_get_version(resource), id);
    
    if (!buffer_resource) {
        wl_client_post_no_memory(client);
        return;
    }
    
    // Store buffer info
    // IMPORTANT: Copy the data pointer instead of storing pool pointer
    // because the pool may be destroyed while buffers are still in use
    struct buffer_data {
        void *data;  // Copy of pool->data pointer (pool may be destroyed)
        int32_t offset;
        int32_t width;
        int32_t height;
        int32_t stride;
        uint32_t format;
    };
    
    struct buffer_data *buf_data = calloc(1, sizeof(*buf_data));
    if (!buf_data) {
        wl_client_post_no_memory(client);
        wl_resource_destroy(buffer_resource);
        return;
    }
    
    // Copy the data pointer - pool may be destroyed but mmap'd memory remains valid
    // Validate pool data is valid before copying
    if (!pool_data->data || pool_data->data == MAP_FAILED) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_FD, "pool data is invalid");
        free(buf_data);
        wl_resource_destroy(buffer_resource);
        return;
    }
    
    buf_data->data = pool_data->data;
    buf_data->offset = offset;
    buf_data->width = width;
    buf_data->height = height;
    buf_data->stride = stride;
    buf_data->format = format;
    
    log_printf("[COMPOSITOR] ", "shm_pool_create_buffer() - buffer=%p, data=%p, offset=%d, size=%dx%d\n",
               (void *)buffer_resource, buf_data->data, offset, width, height);
    
    // Set implementation with destructor to send release event
    wl_resource_set_implementation(buffer_resource, &buffer_interface, buf_data, buffer_destroy);
}

static void shm_pool_destroy(struct wl_client *client, struct wl_resource *resource) {
    (void)client;
    struct shm_pool_data *pool_data = wl_resource_get_user_data(resource);
    if (pool_data) {
        // Don't unmap memory here - buffers may still be using it
        // The memory will be cleaned up when buffers are destroyed or process exits
        // Just close the FD - the mmap'd memory remains valid
        close(pool_data->fd);
        // Note: We don't free pool_data here because buffers may still reference it
        // This is a memory leak, but it's safer than use-after-free crashes
        // TODO: Implement proper reference counting for pool cleanup
    }
    wl_resource_destroy(resource);
}

static void shm_pool_resize(struct wl_client *client, struct wl_resource *resource, int32_t size) {
    (void)client;
    struct shm_pool_data *pool_data = wl_resource_get_user_data(resource);
    if (!pool_data) return;
    
    if (size < 0) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_STRIDE, "invalid size");
        return;
    }
    
    // Resize the memory mapping
    if (ftruncate(pool_data->fd, size) < 0) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_FD, "failed to resize");
        return;
    }
    
    // Remap if size changed significantly
    if (size != pool_data->size) {
        if (pool_data->data != MAP_FAILED) {
            munmap(pool_data->data, (size_t)pool_data->size);
        }
        pool_data->data = mmap(NULL, (size_t)size, PROT_READ | PROT_WRITE, MAP_SHARED, pool_data->fd, 0);
        if (pool_data->data == MAP_FAILED) {
            wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_FD, "failed to remap");
            return;
        }
        pool_data->size = (int32_t)size;
    }
}

