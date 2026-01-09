// WawonaWindowLifecycle_macos.h - macOS window lifecycle management
// Extracted from WawonaCompositor.m for better organization

#pragma once

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

#include "../compositor_implementations/xdg_shell.h"

// Window lifecycle functions
void macos_create_window_for_toplevel(struct xdg_toplevel_impl *toplevel);
void macos_update_toplevel_decoration_mode(struct xdg_toplevel_impl *toplevel);

// Window state management
void macos_toplevel_set_minimized(struct xdg_toplevel_impl *toplevel);
void macos_toplevel_set_maximized(struct xdg_toplevel_impl *toplevel);
void macos_toplevel_unset_maximized(struct xdg_toplevel_impl *toplevel);
void macos_toplevel_close(struct xdg_toplevel_impl *toplevel);
void macos_toplevel_set_fullscreen(struct xdg_toplevel_impl *toplevel);
void macos_toplevel_unset_fullscreen(struct xdg_toplevel_impl *toplevel);
void macos_toplevel_set_min_size(struct xdg_toplevel_impl *toplevel, int32_t width, int32_t height);
void macos_toplevel_set_max_size(struct xdg_toplevel_impl *toplevel, int32_t width, int32_t height);
void macos_start_toplevel_resize(struct xdg_toplevel_impl *toplevel, uint32_t edges);
void macos_start_toplevel_move(struct xdg_toplevel_impl *toplevel);

#endif // !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

