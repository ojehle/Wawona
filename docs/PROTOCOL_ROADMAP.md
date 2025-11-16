# Wayland Protocol Support Roadmap

## Goal
Support all Wayland protocols and ensure compatibility with Weston compositor clients.

**Note**: wlroots is Linux-only and cannot be used on macOS. We implement protocols directly using libwayland-server.

---

## Current Protocol Status

### ✅ Fully Implemented
- `wl_display` - Core display server (libwayland-server)
- `wl_registry` - Global registry (libwayland-server)
- `wl_compositor` - Surface creation and management
- `wl_surface` - Surface operations (attach, commit, damage, etc.)
- `wl_output` - Output geometry and modes
- `wl_seat` - Input device abstraction
- `wl_shm` - Shared memory buffers
- `wl_subcompositor` - Subsurface support
- `wl_data_device_manager` - Clipboard/data transfer base
- `xdg_wm_base` - Window management base
- `xdg_surface` - Surface roles
- `xdg_toplevel` - Top-level windows

### 🟡 Stubbed (Need Full Implementation)
- `xdg_activation_v1` - Window activation tokens
- `wp_fractional_scale_manager_v1` - Fractional scaling
- `wp_cursor_shape_manager_v1` - Cursor shape management
- `zxdg_decoration_manager_v1` - Window decorations
- `xdg_toplevel_icon_v1` - Window icons
- `zwp_text_input_manager_v3` - Text input (IME support)
- `zwp_primary_selection_device_manager_v1` - Primary selection (middle-click paste)

### ❌ Missing Protocols (Critical for Weston Compatibility)

#### Core Extensions
- `wl_shell` - Legacy shell protocol (deprecated but still used)
- `wl_viewporter` - Viewport transformation
- `wl_scaler` - Surface scaling

#### Input Protocols
- `zwp_tablet_manager_v2` - Graphics tablet support
- `zwp_tablet_seat_v2` - Tablet seat
- `zwp_tablet_v2` - Tablet device
- `zwp_tablet_tool_v2` - Tablet tool
- `zwp_tablet_pad_v2` - Tablet pad
- `zwp_pointer_gestures_v1` - Pointer gestures (pinch, swipe)
- `zwp_relative_pointer_manager_v1` - Relative pointer motion
- `zwp_pointer_constraints_v1` - Pointer locking/constraints

#### Display Protocols
- `wl_drm` - Direct Rendering Manager (Linux-only, not applicable)
- `zwp_linux_dmabuf_v1` - DMA buffer support (Linux-only, not applicable)
- `wl_screencopy_manager_v1` - Screen capture
- `zwp_export_dmabuf_manager_v1` - DMA buffer export (Linux-only)

#### Shell Extensions
- `xdg_popup` - Popup windows (partially implemented)
- `xdg_positioner` - Popup positioning (stub exists)

#### Security & Activation
- `zwp_security_context_manager_v1` - Security context (experimental)
- `zwp_input_method_manager_v2` - Input method (IME)

#### Other Protocols
- `zwp_idle_inhibit_manager_v1` - Prevent idle/screensaver
- `zwp_idle_manager_v1` - Idle detection
- `zwp_keyboard_shortcuts_inhibit_manager_v1` - Keyboard shortcuts
- `zwp_pointer_gesture_pinch_v1` - Pinch gestures
- `zwp_pointer_gesture_swipe_v1` - Swipe gestures
- `zwp_pointer_gesture_hold_v1` - Hold gestures
- `zwp_text_input_manager_v1` - Legacy text input (v1)
- `zwp_text_input_manager_v2` - Text input (v2)
- `zwp_text_input_manager_v3` - Text input (v3) - stubbed
- `wl_fullscreen_shell` - Fullscreen shell (deprecated)
- `wl_shell_surface` - Legacy shell surfaces (deprecated)

---

## Implementation Priority

### Phase 1: Critical for Basic Functionality ✅ (Done)
- [x] Core protocols (compositor, surface, output, seat, shm)
- [x] xdg-shell basic implementation
- [x] Input handling (keyboard, pointer)

### Phase 2: Essential for Weston Compatibility (In Progress)
- [ ] `wl_viewporter` - Viewport transformation
- [ ] `xdg_popup` - Full popup implementation
- [ ] `xdg_positioner` - Popup positioning
- [ ] `wl_shell` - Legacy shell (for older clients)
- [ ] `zwp_idle_inhibit_manager_v1` - Prevent screensaver
- [ ] `wl_screencopy_manager_v1` - Screen capture

### Phase 3: Enhanced Input Support
- [ ] `zwp_pointer_gestures_v1` - Gesture support
- [ ] `zwp_relative_pointer_manager_v1` - Relative motion
- [ ] `zwp_pointer_constraints_v1` - Pointer locking
- [ ] `zwp_tablet_manager_v2` - Tablet support (if needed)

### Phase 4: Advanced Features
- [ ] `zwp_text_input_manager_v3` - Full IME support
- [ ] `zwp_primary_selection_device_manager_v1` - Primary selection
- [ ] `wp_fractional_scale_manager_v1` - Fractional scaling
- [ ] `wp_cursor_shape_manager_v1` - Cursor shapes

### Phase 5: Nice-to-Have
- [ ] `zwp_idle_manager_v1` - Idle detection
- [ ] `zwp_keyboard_shortcuts_inhibit_manager_v1` - Shortcut handling
- [ ] `xdg_activation_v1` - Window activation
- [ ] `zxdg_decoration_manager_v1` - Window decorations

---

## Weston Compatibility Notes

Weston uses these protocols extensively:
1. **wl_viewporter** - For viewport transformations
2. **wl_shell** - Legacy clients (deprecated but still present)
3. **wl_screencopy** - Screen capture utilities
4. **zwp_idle_inhibit** - Prevent screensaver during video playback
5. **xdg_popup** - Context menus, tooltips, dropdowns

To be fully Weston-compatible, we need at minimum:
- ✅ Core protocols (done)
- ✅ xdg-shell (done)
- [ ] wl_viewporter
- [ ] wl_shell (legacy)
- [ ] xdg_popup (full implementation)
- [ ] wl_screencopy

---

## wlroots Compatibility

**Important**: wlroots is Linux-only and cannot run on macOS. However, we can:
1. **Implement wlroots-compatible protocols** - Support the same protocols wlroots supports
2. **Follow wlroots patterns** - Use similar architecture patterns where applicable
3. **Document differences** - Note macOS-specific limitations

wlroots-specific protocols (Linux-only, not applicable):
- `wl_drm` - Direct Rendering Manager
- `zwp_linux_dmabuf_v1` - Linux DMA buffers
- `zwp_export_dmabuf_manager_v1` - DMA buffer export

---

## Implementation Strategy

1. **Start with stubs** - Create protocol handlers that acknowledge requests
2. **Implement incrementally** - Add functionality as needed
3. **Test with real clients** - Use foot, weston-terminal, etc.
4. **Follow Wayland spec** - Ensure protocol compliance

---

## Next Steps

1. Implement `wl_viewporter` (critical for many clients)
2. Complete `xdg_popup` implementation
3. Add `wl_shell` support (legacy compatibility)
4. Implement `wl_screencopy` (screen capture)
5. Add `zwp_idle_inhibit_manager_v1` (prevent screensaver)

