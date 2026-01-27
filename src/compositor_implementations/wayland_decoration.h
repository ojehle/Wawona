#pragma once
// STUB: This file is a compatibility stub
// Legacy C protocol files have been removed - project now uses Rust protocols
// only

#include <wayland-server-protocol.h>
#include <wayland-server.h>

struct wl_decoration_manager_impl {
  void *stub;
};

void *wl_decoration_manager_create(void *display);
void wl_decoration_manager_destroy(void *manager);
void wl_decoration_hot_reload(void *manager);
void *wl_decoration_create(void *display);
