// WawonaCompositor_macos.m - macOS-specific compositor extensions
// Extracted from WawonaCompositor.m for better organization

#import "WawonaCompositor_macos.h"
#import "../compositor_implementations/xdg_shell.h"
#import "../input/wayland_seat.h"
#include "../logging/logging.h"
#import "WawonaCompositor.h"
#include <wayland-server-core.h>

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

extern void xdg_toplevel_send_configure(struct wl_resource *resource,
                                        int32_t width, int32_t height,
                                        struct wl_array *states);
extern void xdg_surface_send_configure(struct wl_resource *resource,
                                       uint32_t serial);

// NSWindowDelegate functionality has been moved to WawonaWindowContainer
// in WawonaSurfaceManager.m

#endif // !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
