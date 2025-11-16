# EGL Platform Extension Support in Wawona

## Overview

Wawona fully supports `EGL_EXT_platform_base` and `EGL_EXT_platform_wayland` extensions. Any client connecting to Wawona can use `eglGetPlatformDisplayEXT(EGL_PLATFORM_WAYLAND_EXT, wl_display, NULL)` to initialize EGL.

## How It Works

1. **Wayland Display**: Wawona creates a standard Wayland display using `wl_display_create()` and `wl_display_add_socket_auto()`. This display is fully compatible with EGL platform extensions.

2. **Protocol Support**: Wawona exposes all necessary Wayland protocols (`wl_compositor`, `wl_surface`, etc.) that EGL clients need to create EGL surfaces.

3. **Client-Side EGL**: The EGL library on the client side (e.g., Mesa in containers) must support `EGL_EXT_platform_base` for clients to use `eglGetPlatformDisplayEXT`. If the extension is not available, clients fall back to `eglGetDisplay`, which also works fine.

## Warning Explanation

If you see warnings like:
```
warning: EGL_EXT_platform_base not supported.
warning: either no EGL_EXT_platform_base support or specific platform support; falling back to eglGetDisplay.
```

This means:
- **Wawona's display is fine** - it fully supports EGL platform extensions
- **The client's EGL library** (e.g., Mesa in containers) doesn't have `EGL_EXT_platform_base` compiled in
- **This is harmless** - clients fall back to `eglGetDisplay` which works perfectly

## Ensuring EGL Platform Support

To eliminate the warnings, ensure the client's EGL library supports the extension:

1. **Mesa Installation**: Install Mesa with full EGL support:
   - Nix: `nix-env -iA nixpkgs.mesa.drivers nixpkgs.mesa`
   - Fedora: `dnf install mesa-libEGL mesa-libGLES`
   - Alpine: `apk add mesa-egl mesa-gles`

2. **Environment Variables**: Set EGL platform variables:
   ```bash
   export EGL_PLATFORM=wayland
   export LIBGL_ALWAYS_SOFTWARE=1  # For software rendering
   export GALLIUM_DRIVER=llvmpipe
   ```

3. **Library Path**: Ensure EGL libraries are in `LD_LIBRARY_PATH`:
   ```bash
   export LD_LIBRARY_PATH=/path/to/mesa/lib:$LD_LIBRARY_PATH
   ```

## Verification

Wawona's Wayland display is created in `src/main.m` and exposes all necessary protocols in `src/macos_backend.m`. The display automatically supports:

- ✅ `EGL_EXT_platform_base`
- ✅ `EGL_EXT_platform_wayland`
- ✅ Standard `eglGetDisplay` fallback

Clients can verify EGL extension support:
```c
const char *extensions = eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);
if (strstr(extensions, "EGL_EXT_platform_base")) {
    // Use eglGetPlatformDisplayEXT
} else {
    // Fall back to eglGetDisplay
}
```

## Conclusion

Wawona's compositor fully supports EGL platform extensions. The warnings come from client-side EGL libraries and are harmless - clients automatically fall back to standard EGL initialization.

