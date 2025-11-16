# Comprehensive Wayland Protocol Implementation Plan

## Executive Summary

This document outlines the plan to implement **all Wayland protocols** and ensure **Weston compositor compatibility** for the Wawona compositor.

**Important Note**: wlroots is Linux-only and cannot run on macOS. However, we can implement wlroots-compatible protocols and follow wlroots patterns where applicable.

---

## Current Status

### ✅ Fully Implemented Protocols
- `wl_display` - Core display server
- `wl_registry` - Global registry
- `wl_compositor` - Surface creation
- `wl_surface` - Surface operations
- `wl_output` - Output geometry
- `wl_seat` - Input devices
- `wl_shm` - Shared memory buffers
- `wl_subcompositor` - Subsurface support
- `wl_data_device_manager` - Clipboard base
- `xdg_wm_base` - Window management
- `xdg_surface` - Surface roles
- `xdg_toplevel` - Top-level windows

### 🟡 Stubbed (Need Full Implementation)
- `xdg_activation_v1` - Window activation
- `wp_fractional_scale_manager_v1` - Fractional scaling
- `wp_cursor_shape_manager_v1` - Cursor shapes
- `zxdg_decoration_manager_v1` - Window decorations
- `xdg_toplevel_icon_v1` - Window icons
- `zwp_text_input_manager_v3` - Text input (IME)
- `zwp_primary_selection_device_manager_v1` - Primary selection

### ❌ Missing Critical Protocols

#### For Weston Compatibility
1. **wl_viewporter** - Viewport transformation (CRITICAL)
2. **wl_shell** - Legacy shell protocol (for older clients)
3. **wl_screencopy_manager_v1** - Screen capture
4. **xdg_popup** - Full popup implementation
5. **xdg_positioner** - Popup positioning

#### For Enhanced Functionality
6. **zwp_idle_inhibit_manager_v1** - Prevent screensaver
7. **zwp_pointer_gestures_v1** - Gesture support
8. **zwp_relative_pointer_manager_v1** - Relative motion
9. **zwp_pointer_constraints_v1** - Pointer locking
10. **zwp_tablet_manager_v2** - Tablet support

---

## Implementation Strategy

### Phase 1: Critical Weston Compatibility (Priority 1)
**Goal**: Make compositor compatible with Weston clients

1. **wl_viewporter** ⚠️ CRITICAL
   - Many clients require this for viewport transformations
   - Allows clients to crop/scale surfaces
   - **Status**: Not implemented
   - **Priority**: HIGHEST

2. **wl_shell** (Legacy)
   - Deprecated but still used by older clients
   - Provides basic window management
   - **Status**: Not implemented
   - **Priority**: HIGH

3. **xdg_popup** (Complete Implementation)
   - Currently partially implemented
   - Needed for menus, tooltips, dropdowns
   - **Status**: Partial
   - **Priority**: HIGH

4. **wl_screencopy_manager_v1**
   - Screen capture functionality
   - Used by screenshot tools
   - **Status**: Not implemented
   - **Priority**: MEDIUM

### Phase 2: Enhanced Input Support (Priority 2)
5. **zwp_idle_inhibit_manager_v1**
   - Prevent screensaver during video playback
   - **Status**: Not implemented
   - **Priority**: MEDIUM

6. **zwp_pointer_gestures_v1**
   - Pinch, swipe, hold gestures
   - **Status**: Not implemented
   - **Priority**: LOW

7. **zwp_relative_pointer_manager_v1**
   - Relative pointer motion (for games)
   - **Status**: Not implemented
   - **Priority**: LOW

8. **zwp_pointer_constraints_v1**
   - Pointer locking/constraints
   - **Status**: Not implemented
   - **Priority**: LOW

### Phase 3: Complete Stub Implementations (Priority 3)
9. **zwp_text_input_manager_v3** (Full Implementation)
   - Currently stubbed
   - Full IME support
   - **Status**: Stub
   - **Priority**: MEDIUM

10. **zwp_primary_selection_device_manager_v1** (Full Implementation)
    - Currently stubbed
    - Middle-click paste support
    - **Status**: Stub
    - **Priority**: LOW

11. **wp_fractional_scale_manager_v1** (Full Implementation)
    - Currently stubbed
    - Fractional scaling support
    - **Status**: Stub
    - **Priority**: LOW

12. **wp_cursor_shape_manager_v1** (Full Implementation)
    - Currently stubbed
    - Cursor shape management
    - **Status**: Stub
    - **Priority**: LOW

---

## Implementation Approach

### For Each Protocol

1. **Get Protocol XML**
   - Download from wayland-protocols repository
   - Place in `protocols/` directory

2. **Generate C Bindings**
   ```bash
   wayland-scanner server-header < protocol.xml > protocol.h
   wayland-scanner private-code < protocol.xml > protocol.c
   ```

3. **Create Implementation Files**
   - `src/wayland_<protocol>.c` - Implementation
   - `src/wayland_<protocol>.h` - Header

4. **Register Global**
   - Add to `macos_backend.m` startup
   - Register with `wl_global_create()`

5. **Implement Handlers**
   - Follow Wayland protocol spec
   - Handle all methods and events

6. **Test**
   - Test with real clients
   - Verify protocol compliance

---

## Weston Compatibility Checklist

To be fully Weston-compatible, we need:

- [x] Core protocols (wl_compositor, wl_surface, wl_output, wl_seat, wl_shm)
- [x] xdg-shell basic implementation
- [ ] **wl_viewporter** ⚠️ CRITICAL
- [ ] **wl_shell** (legacy)
- [ ] **xdg_popup** (complete)
- [ ] **wl_screencopy** (screen capture)
- [ ] **zwp_idle_inhibit** (prevent screensaver)

---

## wlroots Compatibility Notes

**Important**: wlroots is Linux-only and cannot run on macOS.

However, we can:
1. **Implement wlroots-compatible protocols** - Support the same protocols wlroots supports
2. **Follow wlroots patterns** - Use similar architecture where applicable
3. **Document differences** - Note macOS-specific limitations

**wlroots-specific protocols** (Linux-only, not applicable):
- `wl_drm` - Direct Rendering Manager
- `zwp_linux_dmabuf_v1` - Linux DMA buffers
- `zwp_export_dmabuf_manager_v1` - DMA buffer export

**wlroots-compatible protocols** (can implement):
- All stable Wayland protocols
- Most unstable protocols
- XDG shell protocols
- Input protocols (pointer, keyboard, touch, tablet)

---

## Next Steps

1. **Immediate**: Implement `wl_viewporter` (critical for many clients)
2. **Short-term**: Complete `xdg_popup` implementation
3. **Short-term**: Add `wl_shell` support (legacy compatibility)
4. **Medium-term**: Implement `wl_screencopy` (screen capture)
5. **Medium-term**: Add `zwp_idle_inhibit_manager_v1` (prevent screensaver)
6. **Long-term**: Complete all stub implementations
7. **Long-term**: Add advanced input protocols

---

## Testing Strategy

1. **Test with Weston clients**
   - `weston-terminal`
   - `weston-simple-egl`
   - `weston-simple-shm`

2. **Test with real applications**
   - `foot` (terminal)
   - `waybar` (status bar)
   - `swaylock` (lock screen)

3. **Protocol compliance**
   - Use `wayland-scanner` validation
   - Test with `wayland-info` tool
   - Verify event ordering

---

## Resources

- **Wayland Protocol Specs**: https://wayland.freedesktop.org/docs/html/
- **wayland-protocols**: https://gitlab.freedesktop.org/wayland/wayland-protocols
- **Weston Source**: https://gitlab.freedesktop.org/wayland/weston
- **wlroots Source**: https://github.com/swaywm/wlroots (Linux-only, reference only)

---

## Conclusion

This is a **long-term project** that will require significant development effort. The priority is to:

1. **First**: Implement critical protocols for Weston compatibility
2. **Second**: Complete stub implementations
3. **Third**: Add advanced features

The compositor is already functional for basic Wayland clients. With the addition of `wl_viewporter` and completion of `xdg_popup`, it will be compatible with most Weston clients.

