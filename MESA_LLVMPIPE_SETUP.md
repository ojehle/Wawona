# Mesa llvmpipe Setup for GL Rendering

## Overview

Weston was falling back to Pixman software rendering because EGL couldn't initialize in the container environment (no GPU access). To enable GL rendering, we've configured Mesa's llvmpipe (software GL implementation) which allows Weston to use its GL renderer path even without hardware GPU.

## Changes Made

### 1. Mesa Installation
Added Mesa packages to the container installation:
- **Nix**: `nixpkgs.mesa`
- **Fedora/RHEL**: `mesa-libGL mesa-dri-drivers`
- **Alpine**: `mesa mesa-gl mesa-dri-gallium`

### 2. Environment Variables
Configured the following environment variables before starting Weston:
- `LIBGL_ALWAYS_SOFTWARE=1` - Forces software rendering
- `GALLIUM_DRIVER=llvmpipe` - Uses llvmpipe driver (software GL)
- `MESA_GL_VERSION_OVERRIDE=3.3` - Sets OpenGL version
- `MESA_GLSL_VERSION_OVERRIDE=330` - Sets GLSL version

### 3. Files Updated
- `scripts/colima-client/container-commands.sh` - Added Mesa installation and environment setup
- `scripts/colima-client/weston-install.sh` - Added Mesa to installation functions
- `scripts/colima-client/weston-run.sh` - Added Mesa environment variables

## How It Works

1. **Mesa llvmpipe**: A software implementation of OpenGL that runs entirely on the CPU
2. **EGL Initialization**: With llvmpipe, EGL can initialize successfully even without GPU
3. **Weston GL Renderer**: Weston detects EGL and uses its GL renderer instead of Pixman
4. **Performance**: Software GL is slower than hardware, but provides full GL compatibility

## Expected Output

With Mesa llvmpipe configured, you should see:
```
✅ Weston and Mesa installed via nix-env
   Configured Mesa llvmpipe (software GL) for GL rendering
   LIBGL_ALWAYS_SOFTWARE=1
   GALLIUM_DRIVER=llvmpipe
   MESA_GL_VERSION_OVERRIDE=3.3
```

And Weston should start with:
```
Loading module '/nix/store/.../libweston-14/gl-renderer.so'
Using GL renderer
```

Instead of:
```
Failed to initialize the GL renderer; falling back to Pixman.
Using Pixman renderer
```

## Benefits

- ✅ Weston uses GL renderer (better compatibility)
- ✅ Full OpenGL 3.3 support
- ✅ Works in containers without GPU access
- ✅ Better rendering quality than Pixman

## Performance Note

llvmpipe is software-based and will be slower than hardware GPU rendering, but it provides full GL compatibility and better rendering quality than Pixman fallback.

