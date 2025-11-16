# Weston Windowed Output API Documentation

## Overview

`weston_windowed_output_api_wayland_v2` is an API in Weston that manages windowed outputs when Weston operates as a nested compositor (Wayland client). This API creates windowed outputs with decorations by default.

## The Problem

When Weston runs nested in Wawona:
- Weston's wayland backend uses `weston_windowed_output_api_wayland_v2`
- This creates a **windowed output** with decorations (titlebar, close button "x")
- The output is rendered to Weston's own windowed surface, not directly to Wawona's framebuffer
- Log shows: `Registered plugin API 'weston_windowed_output_api_wayland_v2' of size 16`

## Solution: Disable Decorations for Nested Compositors

To make Weston render directly to Wawona's window without decorations:

### 1. XDG Decoration Protocol

The `zxdg_decoration_manager_v1` protocol allows clients to request decoration modes:
- `ZXDG_TOPLEVEL_DECORATION_V1_MODE_CLIENT_SIDE` (1) - Client draws decorations
- `ZXDG_TOPLEVEL_DECORATION_V1_MODE_SERVER_SIDE` (2) - Server draws decorations

**Wawona Policy: NEVER allow CLIENT_SIDE decorations**
- Wawona always uses `SERVER_SIDE` mode
- Client requests for `CLIENT_SIDE` are ignored
- This ensures Wawona maintains full control over window appearance
- For fullscreen surfaces (like nested compositors), decorations are automatically disabled during rendering, but we still use `SERVER_SIDE` mode

**For nested compositors:**
- They receive `SERVER_SIDE` mode like all clients
- Since they're fullscreen, decorations won't be drawn
- This ensures consistent behavior and Wawona maintains control

### 2. Fullscreen State

When a toplevel is set to fullscreen (`XDG_TOPLEVEL_STATE_FULLSCREEN`):
- Decorations should be automatically disabled
- The surface should fill the entire output area
- No titlebar, no close button, no window frame

### 3. Implementation Strategy

**Option A: Don't advertise decoration manager to nested compositors**
- Detect nested compositor clients
- Don't create `zxdg_decoration_manager_v1` global for them
- This prevents Weston from requesting decorations

**Option B: Force no decorations for nested compositors**
- When nested compositor requests decoration, ignore it
- Or always respond with a mode that results in no decorations
- Ensure fullscreen state disables decorations

**Option C: Configure Weston to not request decorations**
- Use Weston config file to disable decorations
- Set `shell=fullscreen-shell.so` (already done)
- But this may not prevent wayland backend from creating windowed output

## Current Implementation Status

### What We Have:
1. ✅ Auto-fullscreen for nested compositors (in `xdg_shell.c`)
2. ✅ Decoration manager protocol stub (in `wayland_protocol_stubs.c`)
3. ✅ Server-side decorations configured by default

### What's Missing:
1. ❌ Detection of nested compositors when they request decorations
2. ❌ Prevention of decoration requests for nested compositors
3. ❌ Ensuring fullscreen surfaces have no decorations

## Recommended Fix

**Implement Option A + B:**
1. Track nested compositor clients (already done in `xdg_shell.c`)
2. When creating decoration manager, check if client is nested compositor
3. If nested compositor, either:
   - Don't create decoration resource for them, OR
   - Always respond with a mode that results in no decorations
4. Ensure fullscreen toplevels never have decorations

## References

- Weston source: `libweston/windowed-output-api.h`
- XDG Decoration Protocol: `protocols/xdg-decoration-unstable-v1.xml`
- Weston documentation: https://wayland.freedesktop.org/weston-doc/

