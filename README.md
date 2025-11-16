# Wawona

[![Build Status](https://github.com/YOUR_USERNAME/Wawona/actions/workflows/build.yml/badge.svg)](https://github.com/YOUR_USERNAME/Wawona/actions/workflows/build.yml)
[![Protocol Status](https://github.com/YOUR_USERNAME/Wawona/actions/workflows/protocols.yml/badge.svg)](https://github.com/YOUR_USERNAME/Wawona/actions/workflows/protocols.yml)
[![Code Style](https://img.shields.io/badge/code%20style-clang--format-blue)](https://clang.llvm.org/docs/ClangFormat.html)

<div align="center">
  <img src="preview1.png" alt="Wawona - Wayland Compositor for macOS Preview" width="800"/>
  
  <details>
    <summary><b>See More</b></summary>
    <br>
    <img src="preview2.png" alt="Wawona - Wayland Compositor for macOS Preview 2" width="800"/>
    <br><br>
    <img src="preview3.png" alt="Wawona - Wayland Compositor for macOS Preview 3" width="800"/>
  </details>
</div>

**Wawona** is a Wayland Compositor for macOS. A **from-scratch** native macOS Wayland compositor with a full Cocoa compatibility layer, built with libwayland-server and Metal for desktop shells and compositors.

## Overview

This compositor runs **natively on macOS** - no Linux, VM, or container required. It features:
- **libwayland-server** (core C API) for protocol marshaling
- **Metal** for high-performance rendering of desktop shells and compositors
- **Cocoa compatibility layer** providing full integration with macOS windowing and input systems
- **NSWindow** for native compositor window management
- **Custom compositor implementation** (not WLRoots - we build our own)
- **Full Wayland protocol support** for QtWayland and other Wayland clients

**Important**: This is a from-scratch compositor implementation with a complete Cocoa compatibility layer. We use ONLY the core Wayland protocol library (`libwayland-server`) for protocol handling, and implement all compositor logic ourselves using Metal for rendering and Cocoa for system integration.

## Prerequisites

See **[docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)** for complete dependency information.

Quick install:

```bash
# Build tools
brew install cmake pkg-config pixman

# Wayland - Homebrew won't install it (Linux requirement), so build from source:
brew install meson ninja expat libffi libxml2
git clone https://gitlab.freedesktop.org/wayland/wayland.git
cd wayland
meson setup build -Ddocumentation=false
meson compile -C build
sudo meson install -C build

# KosmicKrisp Vulkan driver (REQUIRED for DMA-BUF support)
make kosmickrisp

# Waypipe (for Wayland forwarding)
make waypipe
```

**Note**: We do NOT use `wlroots` - it's Linux-only. We're building our own compositor.

Verify installation:

```bash
./check-deps.sh
```

## Quick Start

### Using Makefile (Recommended)

```bash
# Full setup (checks deps, installs wayland if needed, builds compositor)
make all

# Run compositor (in one terminal)
make run-compositor

# Run test client (in another terminal)
make run-client
```

### Manual Setup

1. **Install dependencies**:
   ```bash
   # Build tools
   brew install cmake pkg-config pixman
   
   # Wayland - Homebrew won't install it (Linux requirement), build from source:
   brew install meson ninja expat libffi libxml2
   git clone https://gitlab.freedesktop.org/wayland/wayland.git
   cd wayland
   meson setup build -Ddocumentation=false
   meson compile -C build
   sudo meson install -C build
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
1. Open an NSWindow titled "Wawona"
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

### Local Clients

Once the compositor is running, set the WAYLAND_DISPLAY environment variable and run a Wayland client:

```bash
export WAYLAND_DISPLAY=wayland-0
./MyQtApp -platform wayland
```

### Running Linux Clients in Docker (Colima)

Run Linux Wayland clients (like Weston) in a Docker container with full DMA-BUF and video support:

```bash
# Start compositor (in one terminal)
make run-compositor

# Run Weston in Docker container via waypipe (in another terminal)
make colima-client
```

This will:
1. Start waypipe client to proxy the compositor connection
2. Start a Docker container with Weston
3. Install Mesa Vulkan drivers in the container
4. Forward Wayland protocol via waypipe with DMA-BUF support

**Requirements**:
- Colima installed (`brew install colima`)
- KosmicKrisp Vulkan driver installed (`make kosmickrisp`)
- Waypipe built (`make waypipe`)

## Current Status

This compositor is **fully functional** with:
- ✅ Metal-based rendering pipeline for desktop shells and compositors
- ✅ Complete Cocoa compatibility layer for macOS integration
- ✅ Full Wayland protocol support (xdg-shell, input, output, etc.)
- ✅ Buffer handling (SHM and DMA-BUF via Vulkan/KosmicKrisp)
- ✅ Input event processing (keyboard, mouse, touch)
- ✅ Native macOS window management
- ✅ **KosmicKrisp Vulkan driver** - Vulkan 1.3 conformance on macOS (required for DMA-BUF)
- ✅ **Waypipe integration** - Rust-based Wayland forwarding with video + DMA-BUF support
- ✅ **Colima client support** - Run Linux Wayland clients in Docker containers via waypipe

## Architecture

```
macOS app
→ creates NSWindow with Cocoa compatibility layer
→ initializes libwayland-server (protocol marshaling ONLY)
→ implements custom compositor logic in Objective-C
→ Metal renderer for desktop shells and compositors
→ exposes WAYLAND_DISPLAY=wayland-0
→ Wayland clients connect (QtWayland, GTK, etc.)
→ compositor receives buffers (SHM, DMA-BUF)
→ Metal-based rendering pipeline
→ Cocoa integration for windowing and input
```

### What We Implement Ourselves:
- ✅ Compositor core logic
- ✅ Cocoa compatibility layer for macOS integration
- ✅ Metal renderer for desktop shells and compositors
- ✅ Output (wl_output) implementation
- ✅ Surface (wl_surface) management
- ✅ Buffer handling (SHM, DMA-BUF → Metal textures)
- ✅ Input event bridging (NSEvent → Wayland events)
- ✅ xdg-shell protocol (for window management)
- ✅ Frame timing and synchronization

### What We Use From Libraries:
- ✅ `libwayland-server`: Protocol marshaling/unmarshaling
- ✅ `wayland-scanner`: XML → C header generation
- ✅ macOS frameworks: Cocoa, Metal, QuartzCore, CoreVideo

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

- This is a **from-scratch compositor implementation** with a complete Cocoa compatibility layer
- We do NOT use WLRoots (it's Linux-only and cannot run on macOS)
- We use ONLY `libwayland-server` for protocol handling
- **Metal** is used for high-performance rendering of desktop shells and compositors
- All compositor logic, rendering, and input is implemented in Objective-C with Metal shaders
- Full Cocoa integration for native macOS windowing and input systems
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
- **Metal** for high-performance rendering of desktop shells and compositors
- **Cocoa compatibility layer** for full macOS integration
- NSEvent (macOS input)
- Pure Objective-C implementation with Metal shaders

