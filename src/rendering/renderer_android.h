#pragma once

#ifdef __ANDROID__
#include <android/native_window.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#endif

struct wl_surface_impl;

// Android Renderer Interface
// Handles rendering Wayland surfaces to Android NativeWindow (Surface)

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WawonaRendererAndroid WawonaRendererAndroid;

WawonaRendererAndroid* wawona_renderer_android_create(void* native_window);
void wawona_renderer_android_destroy(WawonaRendererAndroid* renderer);

void wawona_renderer_android_render_surface(WawonaRendererAndroid* renderer, struct wl_surface_impl* surface);
void wawona_renderer_android_remove_surface(WawonaRendererAndroid* renderer, struct wl_surface_impl* surface);
void wawona_renderer_android_set_needs_display(WawonaRendererAndroid* renderer);

#ifdef __cplusplus
}
#endif
