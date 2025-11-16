# macOS Wayland Compositor

A **from-scratch** native macOS Wayland compositor built with libwayland-server and CALayer.

## Overview

This compositor runs **natively on macOS** - no Linux, VM, or container required. It uses:
- **libwayland-server** (core C API) for protocol marshaling
- **CALayer** for rendering surfaces
- **NSWindow** for the compositor window
- **Custom compositor implementation** (not WLRoots - we build our own)
- **QtWayland** clients can connect and run natively

**Important**: This is a from-scratch compositor implementation. We use ONLY the core Wayland protocol library (`libwayland-server`) for protocol handling, and implement all compositor logic ourselves using macOS frameworks.

## Prerequisites

See **[DEPENDENCIES.md](DEPENDENCIES.md)** for complete dependency information.

Quick install:

```bash
brew install cmake pkg-config wayland pixman
```

**Note**: We do NOT use `wlroots` - it's Linux-only. We're building our own compositor.

Verify installation:

```bash
./check-deps.sh
```

## Quick Start

1. **Install dependencies**:
   ```bash
   brew install cmake pkg-config wayland pixman
   ```
   
   **Note**: `wayland` provides ONLY the core protocol libraries (libwayland-server/client). No compositor, no backends, no rendering - just protocol marshaling. We implement everything else ourselves.

2. **Verify dependencies**:
   ```bash
   ./check-deps.sh
   ```

3. **Build compositor**:
   ```bash
   mkdir build && cd build
   cmake ..
   make -j8
   ```

4. **Run compositor**:
   ```bash
   ./Wawona
   ```

5. **View docs** (in another terminal):
   ```bash
   ./serve-docs.sh
   ```

## Building

```bash
mkdir build
cd build
cmake ..
make -j8
```

## Running

```bash
./Wawona
```

The compositor will:
1. Open an NSWindow titled "macOS Wayland Compositor"
2. Create a Wayland socket (typically `wayland-0`)
3. Print the WAYLAND_DISPLAY name to the console

## Viewing Documentation

The documentation is now in the `docs/` folder with a proper Node.js server.

**First time setup** (installs npm dependencies):

```bash
./serve-docs.sh
```

This will:
1. Install npm dependencies (express, marked) if needed
2. Start the documentation server
3. Automatically open your browser to http://localhost:8080

Or specify a custom port:

```bash
./serve-docs.sh 3000
```

**Manual setup** (if you prefer):

```bash
cd docs
npm install
npm start
```

The server uses Express.js to serve markdown files with proper rendering via the marked library.

## Testing with Wayland Clients

Once the compositor is running, set the WAYLAND_DISPLAY environment variable and run a Wayland client:

```bash
export WAYLAND_DISPLAY=wayland-0
./MyQtApp -platform wayland
```

## Current Status

This is the **minimal skeleton** - it compiles, links, and runs, but doesn't yet:
- Render surfaces to CALayers
- Handle input events
- Process Wayland buffers

## Next Steps

Future enhancements will include:
- ✅ CADisplayLink for frame timing
- ✅ SHM buffer → CGImage → CALayer conversion
- ✅ wlr_output commit handling
- ✅ Input event bridging (keyboard/mouse)
- ✅ Full QtWayland client support

## Architecture

```
macOS app
→ creates NSWindow + CALayer tree
→ initializes libwayland-server (protocol marshaling ONLY)
→ implements custom compositor logic in Objective-C
→ exposes WAYLAND_DISPLAY=wayland-0
→ QtWayland clients connect
→ compositor receives SHM buffers
→ converts to CGImage
→ renders into CALayers
```

### What We Implement Ourselves:
- ✅ Compositor core logic
- ✅ Output (wl_output) implementation
- ✅ Surface (wl_surface) management
- ✅ Buffer handling (SHM → CGImage → CALayer)
- ✅ Input event bridging (NSEvent → Wayland events)
- ✅ xdg-shell protocol (for window management)
- ✅ Frame timing (CADisplayLink)

### What We Use From Libraries:
- ✅ `libwayland-server`: Protocol marshaling/unmarshaling
- ✅ `wayland-scanner`: XML → C header generation
- ✅ macOS frameworks: Cocoa, QuartzCore, CoreVideo

## Running as a Service (Launchd)

To run the compositor as a macOS Launchd service:

1. Copy `com.aspauldingcode.wawona.compositor.plist` to `~/Library/LaunchAgents/`
2. Update the `ProgramArguments` path to your compositor binary
3. Load the service:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.aspauldingcode.wawona.compositor.plist
   ```

See **[DEPENDENCIES.md](DEPENDENCIES.md)** for detailed Launchd setup instructions.

## Notes

- This is a **from-scratch compositor implementation**
- We do NOT use WLRoots (it's Linux-only and cannot run on macOS)
- We use ONLY `libwayland-server` for protocol handling
- All compositor logic, rendering, and input is implemented in Objective-C
- No DRM, GBM, libinput, or udev dependencies
- Runs entirely in userspace on macOS
- Uses macOS Launchd (not systemd) for service management

## Why Not WLRoots?

**WLRoots requires Linux**. Even though Homebrew might let you install it, it:
- Depends on DRM/KMS (Linux kernel display management)
- Depends on libinput (Linux input handling)
- Depends on udev (Linux device management)
- Cannot actually function on macOS

Instead, we build our own compositor using:
- `libwayland-server` (protocol layer only)
- CALayer (macOS rendering)
- NSEvent (macOS input)
- Pure Objective-C implementation
