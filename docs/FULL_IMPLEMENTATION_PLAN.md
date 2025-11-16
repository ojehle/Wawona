# Complete Wayland Protocol Implementation Plan

## Goal
Implement **ALL Wayland protocols** to create a complete compatibility layer for Wayland on macOS.

## Architecture

### Dual Rendering Paths

1. **Single Wayland Window** → `NSWindow + Cocoa` drawing
   - Use when rendering individual Wayland clients
   - Lightweight, native macOS integration
   - Current implementation

2. **Full Compositor** (like Weston) → `Metal` rendering
   - Use when forwarding entire compositor via waypipe
   - High-performance GPU rendering
   - Required for complex compositors

### Protocol Implementation Status

#### ✅ Fully Implemented
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

#### 🟡 In Progress
- `wp_viewporter` - Viewport transformation (CRITICAL)

#### 🟡 Stubbed (Need Full Implementation)
- `xdg_activation_v1` - Window activation
- `wp_fractional_scale_manager_v1` - Fractional scaling
- `wp_cursor_shape_manager_v1` - Cursor shapes
- `zxdg_decoration_manager_v1` - Window decorations
- `xdg_toplevel_icon_v1` - Window icons
- `zwp_text_input_manager_v3` - Text input (IME)
- `zwp_primary_selection_device_manager_v1` - Primary selection

#### ❌ Missing (Critical for Weston)
- `wl_shell` - Legacy shell protocol
- `wl_screencopy_manager_v1` - Screen capture
- `xdg_popup` - Complete popup implementation
- `xdg_positioner` - Popup positioning
- `zwp_idle_inhibit_manager_v1` - Prevent screensaver
- `zwp_pointer_gestures_v1` - Gesture support
- `zwp_relative_pointer_manager_v1` - Relative motion
- `zwp_pointer_constraints_v1` - Pointer locking
- `zwp_tablet_manager_v2` - Tablet support

## Implementation Strategy

### Phase 1: Critical Protocols (Week 1)
1. ✅ Fix coordinate system (upside-down issue)
2. 🔄 `wp_viewporter` - Viewport transformation
3. `wl_shell` - Legacy compatibility
4. `xdg_popup` - Complete implementation
5. `wl_screencopy_manager_v1` - Screen capture

### Phase 2: Enhanced Input (Week 2)
6. `zwp_idle_inhibit_manager_v1` - Prevent screensaver
7. `zwp_pointer_gestures_v1` - Gestures
8. `zwp_relative_pointer_manager_v1` - Relative motion
9. `zwp_pointer_constraints_v1` - Pointer locking

### Phase 3: Complete Stubs (Week 3)
10. `zwp_text_input_manager_v3` - Full IME support
11. `zwp_primary_selection_device_manager_v1` - Primary selection
12. `wp_fractional_scale_manager_v1` - Fractional scaling
13. `wp_cursor_shape_manager_v1` - Cursor shapes

### Phase 4: Metal Backend (Week 4)
14. Metal renderer implementation
15. Metal texture handling
16. GPU-accelerated compositing
17. Performance optimization

### Phase 5: Waypipe Integration (Week 5)
18. Metal buffer support in waypipe
19. Video codec integration
20. DMA-BUF emulation for macOS
21. Network optimization

## File Structure

```
src/
├── wayland_viewporter.c/h      ✅ In progress
├── wayland_shell.c/h           ❌ TODO
├── wayland_screencopy.c/h      ❌ TODO
├── xdg_popup.c/h               🟡 Partial
├── wayland_idle_inhibit.c/h    ❌ TODO
├── metal_renderer.m/h           ❌ TODO
├── rendering_backend.h          ✅ Created
└── ...
```

## Testing Strategy

1. **Unit Tests**: Test each protocol individually
2. **Integration Tests**: Test with real clients (foot, weston-terminal)
3. **Compatibility Tests**: Test with Weston compositor
4. **Performance Tests**: Benchmark Metal vs Cocoa rendering

## Next Steps

1. Complete `wp_viewporter` implementation
2. Implement `wl_shell` protocol
3. Complete `xdg_popup` implementation
4. Create Metal renderer backend
5. Integrate with waypipe

