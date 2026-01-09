// WawonaBackendManager.h - Backend detection and switching
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>
#include <wayland-server-core.h>

@class WawonaCompositor;

// Backend detection function
void wawona_compositor_detect_full_compositor(struct wl_client *client);

