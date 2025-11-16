# Wawona Ideal Implementation Plan

**Date**: 2025-01-XX  
**Status**: 🚧 **IN PROGRESS**

---

## Goal

Create the **ideal** Wawona compositor implementation that:
- Uses the **optimal macOS graphics stack** for each use case
- Supports **ALL Wayland protocols** and clients
- Supports **embedded compositors** (GNOME, KDE, Sway, etc.)
- Supports **standalone Wayland clients** (GTK, Qt, etc.)
- Follows **macOS GSD** (Global-Side-Decoration) when appropriate
- Is **production-ready** and **performant**

---

## macOS Graphics Stack Analysis

### macOS Native Graphics Stack
1. **Metal** - Low-level GPU API (replaces OpenGL)
   - Best for: GPU-accelerated rendering, nested compositors, complex scenes
   - Performance: Highest
   - Use case: Weston, wlroots-based compositors, GPU-intensive apps
   - **Current**: ✅ Using Metal for nested compositors

2. **CoreGraphics** - 2D graphics API
   - Best for: Simple 2D rendering, text, basic shapes
   - Performance: Good for CPU rendering
   - Use case: Simple Wayland clients, UI elements
   - **Current**: ✅ Using CoreGraphics for regular clients

3. **Cocoa/AppKit** - High-level UI framework
   - Best for: Window management, native macOS integration
   - Performance: Good (uses CoreGraphics/Metal under the hood)
   - Use case: Window decorations, native macOS windows
   - **Current**: ✅ Using Cocoa for window management

4. **Core Animation** - Animation and compositing framework
   - Best for: Smooth animations, layer-based compositing
   - Performance: Excellent (GPU-accelerated)
   - Use case: Window transitions, animations
   - **Current**: ⚠️ Not explicitly used (could enhance)

5. **IOSurface** - GPU buffer sharing
   - Best for: Zero-copy GPU buffer sharing, DMA-BUF equivalent
   - Performance: Excellent (zero-copy)
   - Use case: GPU-accelerated clients, DMA-BUF support
   - **Current**: ⚠️ Partially implemented (needs enhancement)

### Wayland Graphics Stack
1. **EGL** - Interface between OpenGL/OpenGL ES and native platform
   - Used by: Most Wayland clients, nested compositors
   - macOS equivalent: Metal (but EGL can bridge to Metal)
   - **Current**: ⚠️ EGL → Metal bridge not implemented

2. **OpenGL/OpenGL ES** - Graphics API
   - Used by: Many Wayland clients
   - macOS status: Deprecated (use Metal instead)
   - **Current**: ⚠️ Not supported (deprecated on macOS)

3. **Vulkan** - Low-level graphics API
   - Used by: Modern Wayland clients, some compositors
   - macOS status: Supported via MoltenVK (Vulkan → Metal)
   - **Current**: ⚠️ Not implemented (could use MoltenVK)

---

## Ideal Architecture

### Rendering Backend Selection

#### 1. Metal Backend (Primary for GPU-accelerated)
**When to use:**
- Nested compositors (Weston, wlroots, Sway, GNOME, KDE)
- GPU-intensive applications
- Applications requesting hardware acceleration
- Full-screen applications
- Applications using DMA-BUF/IOSurface

**Implementation:**
- ✅ Use `MTKView` for rendering
- ✅ Use `CAMetalLayer` for display sync
- ✅ Use Metal shaders for compositing
- ⚠️ Support EGL → Metal bridge for clients (TODO)
- ⚠️ Support Vulkan via MoltenVK (TODO)
- ⚠️ Support IOSurface/DMA-BUF (partially done)

#### 2. Cocoa/CoreGraphics Backend (Primary for simple clients)
**When to use:**
- Simple Wayland clients (foot, basic GTK apps)
- CPU-rendered applications
- Applications not requesting GPU acceleration
- Windowed applications
- Applications using SHM buffers

**Implementation:**
- ✅ Use `NSView` for rendering
- ✅ Use `CoreGraphics` for 2D rendering
- ✅ Use `CGImage` for surface rendering
- ✅ Native macOS window integration

#### 3. Hybrid Approach (Current - Optimal)
**Strategy:**
- ✅ Auto-detect client type
- ✅ Use Metal for nested compositors
- ✅ Use Cocoa for regular clients
- ⚠️ Seamless switching when needed (needs improvement)

---

## Protocol Implementation Strategy

### Core Protocols (Must Have) ✅ COMPLETE
- ✅ `wl_display` - Core (libwayland-server)
- ✅ `wl_registry` - Core (libwayland-server)
- ✅ `wl_compositor` - Surface management
- ✅ `wl_surface` - Surface rendering
- ✅ `wl_output` - Display information
- ✅ `wl_seat` - Input handling
- ✅ `wl_shm` - Shared memory buffers
- ✅ `wl_subcompositor` - Sub-surface support

### Shell Protocols (Must Have)
- ✅ `xdg_wm_base` - Modern window management (**UPGRADED TO v7**)
- ✅ `wl_shell` - Legacy window management
- ✅ `xdg_surface` - Surface roles
- ✅ `xdg_toplevel` - Window management
- ✅ `xdg_popup` - Popup windows

**Status**: ✅ Upgraded to v7 for full compatibility

### Application Toolkit Protocols (Must Have) ✅ COMPLETE (Stubs)
- ✅ `gtk_shell1` - GTK applications (functional stub)
- ✅ `org_kde_plasma_shell` - KDE Plasma applications (functional stub)
- ✅ `qt_surface_extension` - QtWayland applications (functional stub)
- ✅ `qt_windowmanager` - QtWayland window management (functional stub)

**Status**: Functional stubs allow apps to connect. Full implementation can be added incrementally.

### Extended Protocols (Should Have) ✅ MOSTLY COMPLETE
- ✅ `xdg_activation_v1` - Window activation
- ✅ `zxdg_decoration_manager_v1` - Window decorations
- ✅ `wp_viewporter` - Viewport transformation
- ⚠️ `wl_screencopy_manager_v1` - Screen capture (created but not advertised correctly)
- ✅ `zwp_primary_selection_device_manager_v1` - Primary selection
- ✅ `zwp_idle_inhibit_manager_v1` - Screensaver prevention
- ✅ `zwp_text_input_manager_v3` - IME support (protocol complete, macOS IME bridge pending)
- ✅ `wp_fractional_scale_manager_v1` - HiDPI scaling
- ✅ `wp_cursor_shape_manager_v1` - Cursor themes (functional stub)

### Advanced Protocols (Nice to Have) ⚠️ MISSING
- ❌ `zwp_linux_dmabuf_v1` - DMA-BUF support (for GPU buffers) - **CRITICAL for wlroots**
- ❌ `zwp_linux_explicit_synchronization_v1` - Explicit sync
- ❌ `wlr_export_dmabuf_unstable_v1` - wlroots export
- ❌ `wlr_gamma_control_unstable_v1` - Gamma control
- ❌ `wlr_data_control_unstable_v1` - Data control
- ⚠️ `zwp_tablet_v2` - Graphics tablet support (stub exists)
- ⚠️ `zwp_pointer_gestures_v1` - Gesture support (stub exists)
- ⚠️ `zwp_relative_pointer_v1` - Relative pointer (stub exists)
- ⚠️ `zwp_pointer_constraints_v1` - Pointer constraints (stub exists)

---

## Desktop Environment Support Strategy

### Embedded Compositors (Nested)
**Supported:**
- ✅ Weston (reference compositor) - **VERIFIED**
- ⚠️ wlroots-based compositors (Sway, niri, etc.) - **PARTIAL** (needs DMA-BUF)
- ⚠️ GNOME (Mutter) - **PARTIAL** (needs detection + protocols)
- ⚠️ KDE Plasma (KWin) - **PARTIAL** (needs detection + protocols)
- ❌ XFCE (Wayfire?) - **NOT TESTED**

**Current Detection Logic:**
```objective-c
// src/macos_backend.m
// Uses proc_pidpath to detect process name
// Checks for: "weston", "mutter", "kwin", "sway", "river", "hyprland", etc.
// ✅ Enhanced: waypipe detection fixed
```

**Ideal Detection:**
1. ✅ Check process name (current - enhanced)
2. ⚠️ Check for compositor-specific protocols (e.g., wlr_* protocols) - **TODO**
3. ⚠️ Check client capabilities (e.g., binds to wl_compositor + creates surfaces) - **TODO**
4. ✅ Avoid false positives (waypipe, proxies) - **FIXED**

**Strategy:**
- Detect compositor type on connection
- Use Metal backend for all nested compositors
- Full-screen rendering
- Pass-through input handling
- Support all required protocols

### Standalone Clients
**Supported:**
- ✅ GTK applications (via gtk_shell1 stub)
- ✅ Qt applications (via qt_* stubs)
- ✅ Terminal emulators (foot, alacritty, etc.)
- ✅ Text editors
- ⚠️ Browsers (if Wayland-enabled) - **NOT TESTED**

**Strategy:**
- Use Cocoa backend for simple clients
- Use Metal backend for GPU-intensive clients
- macOS window decorations (GSD)
- Native macOS integration

---

## Current vs Ideal Comparison

### ✅ What We're Doing Right

1. **Dual Backend Approach**
   - ✅ Metal for nested compositors
   - ✅ Cocoa for regular clients
   - ✅ Smart detection logic (enhanced)

2. **Core Protocol Support**
   - ✅ All core protocols implemented
   - ✅ Shell protocols implemented (upgraded to v7)
   - ✅ Application toolkit protocols (stubs)

3. **macOS Integration**
   - ✅ Native window management
   - ✅ CSD/GSD support
   - ✅ Retina scaling

4. **Performance Optimizations**
   - ✅ CGImage caching (Cocoa)
   - ✅ Texture caching (Metal)
   - ✅ Frame update optimization

### ⚠️ What Needs Improvement

1. **Protocol Versions**
   - ✅ `xdg_wm_base` v7 (upgraded from v4)
   - ⚠️ Some protocols at minimum version

2. **Advanced Protocols**
   - ❌ DMA-BUF not implemented (critical for wlroots)
   - ❌ Explicit sync not implemented
   - ⚠️ Tablet support incomplete

3. **Graphics Stack**
   - ⚠️ EGL → Metal bridge not implemented
   - ⚠️ Vulkan support via MoltenVK not implemented
   - ⚠️ Direct GPU buffer handling incomplete (IOSurface partially done)

4. **Desktop Environment Support**
   - ✅ GNOME/KDE detection enhanced
   - ⚠️ Some protocols missing for full support
   - ⚠️ wlroots protocols missing (DMA-BUF critical)

5. **Compositor Detection**
   - ✅ waypipe false positive fixed
   - ✅ Detection enhanced with more compositor names
   - ⚠️ Detection could be more robust (check protocols, not just process name)

---

## Implementation Priorities

### Phase 1: Core Optimization (Current) ✅ COMPLETE
- ✅ Dual backend implementation
- ✅ Core protocol support
- ✅ Basic desktop environment support
- ✅ Protocol version upgrades (xdg_wm_base v7)

### Phase 2: Protocol Completeness (Next) 🚧 IN PROGRESS
- ✅ Upgrade `xdg_wm_base` to v7
- [ ] Fix screencopy protocol advertisement
- [ ] Implement DMA-BUF support (critical for wlroots)
- [ ] Implement explicit sync
- [ ] Complete tablet support

### Phase 3: Advanced Features (Future)
- [ ] EGL → Metal bridge
- [ ] Vulkan support (MoltenVK)
- [ ] Advanced desktop environment features
- [ ] Performance optimizations

---

## Testing Strategy

### Client Testing
- [ ] GTK applications (gedit, nautilus, etc.)
- [ ] Qt applications (Qt Creator, etc.)
- [ ] Terminal emulators (foot, alacritty)
- [ ] Text editors (neovim, etc.)
- [ ] Browsers (Firefox, Chrome if Wayland-enabled)

### Compositor Testing
- [x] Weston ✅ VERIFIED
- [ ] Sway (wlroots) - **NEEDS DMA-BUF**
- [ ] GNOME (Mutter) - **NEEDS PROTOCOLS**
- [ ] KDE Plasma (KWin) - **NEEDS PROTOCOLS**
- [ ] XFCE (if Wayland-enabled)

### Protocol Testing
- [x] All protocols via automated tests ✅ CREATED
- [x] Protocol compliance verification ✅ CREATED
- [ ] Performance benchmarking

---

## macOS-Specific Optimizations

### Current Optimizations ✅
1. ✅ Retina display support (fractional-scale-v1)
2. ✅ Native window management (NSWindow)
3. ✅ CSD/GSD support (dynamic window decorations)
4. ✅ Metal for GPU acceleration
5. ✅ CoreGraphics for 2D rendering

### Potential Optimizations ⚠️
1. ⚠️ Core Animation for smooth transitions
2. ⚠️ IOSurface for zero-copy GPU buffers
3. ⚠️ Metal Performance Shaders for compositing
4. ⚠️ Grand Central Dispatch for parallel processing
5. ⚠️ App Sandbox compatibility

---

## Next Steps

1. ✅ Research macOS → Wayland graphics mapping
2. ✅ Update protocol implementations (xdg_wm_base v7)
3. ✅ Enhance desktop environment detection
4. ✅ Create comprehensive test suite
5. ✅ Update scripts for testing various clients/compositors
6. 🚧 Implement DMA-BUF support (critical)
7. 🚧 Fix screencopy protocol advertisement

---

**This document will be updated as research progresses.**
