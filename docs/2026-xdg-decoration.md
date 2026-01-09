Excellent — this is exactly the right architectural split.
Below is a **clean, protocol-faithful compositor design** that matches:

* `xdg-decoration`
* Wayland multi-surface semantics
* macOS WindowServer realities
* GPU-first rendering
* Your stated **SSD vs CSD bifurcation**

I’ll stay **concrete**, not hand-wavy.

---

# Wawona Wayland Compositor – macOS Architecture

## High-level rule (non-negotiable)

> **All Wayland surfaces map to CALayers.**
> **Only SSD toplevels get an NSWindow.**

This keeps your compositor *correct* and *maintainable*.

---

## 1. Decoration policy (xdg-decoration)

Implement **server preference with client override**, exactly as spec intends.

```text
Client requests decoration mode
 ├─ requests SSD → NSWindow-backed
 └─ requests CSD → Layer-only
```

Fallback:

* If client supports `xdg-decoration` → honor it
* If not → default to SSD (safe macOS behavior)

---

## 2. Core object model (Wayland → macOS)

### Wayland objects

```
wl_surface
 ├─ role: xdg_toplevel
 ├─ role: xdg_popup
 ├─ role: subsurface
```

### macOS mapping

| Wayland role       | macOS primitive                    |
| ------------------ | ---------------------------------- |
| xdg_toplevel (SSD) | NSWindow                           |
| xdg_toplevel (CSD) | CALayer tree                       |
| xdg_popup          | Floating CALayer OR child NSWindow |
| subsurface         | CALayer (child)                    |

---

## 3. SSD Path (Server-Side Decorations)

### Purpose

* Native macOS chrome
* Correct Spaces, fullscreen, accessibility
* macOS resize logic

### Stack

```
NSWindow
 └─ ContentView (layer-backed)
     └─ Root CALayer
         └─ wl_surface content (CAMetalLayer)
```

### Rendering

* Wayland client renders → GPU buffer
* Imported into:

  * `IOSurface`
  * `CAMetalLayer`

### Resize

* macOS handles edge/corner hit-testing
* On resize:

  ```
  NSWindowDidResize
    → xdg_toplevel.configure(new_size)
  ```

### Fullscreen / maximize

* Map directly to:

  * `-[NSWindow toggleFullScreen:]`
  * `-[NSWindow zoom:]`

### Why this works

* Client doesn’t draw chrome
* macOS *owns* decoration + resize affordances

---

## 4. CSD Path (Client-Side Decorations)

### Absolute rules

* ❌ NO `NSWindow` chrome
* ❌ NO titlebar/shadow from AppKit
* ✅ GPU pixel rendering
* ✅ Client owns decorations
* ✅ You own hit-testing + resize

---

## 5. CSD macOS representation (CRITICAL)

### Do NOT use NSWindow decorations

Instead:

### Option A (RECOMMENDED): Borderless NSWindow + Layer-only logic

You **still need a host window** for WindowServer registration.

```objc
NSWindowStyleMaskBorderless
NSWindowTitleVisibilityHidden
NSWindowTitlebarAppearsTransparent
```

BUT:

* Disable:

  * Standard buttons
  * Titlebar drawing
  * Shadow
* Prevent AppKit hit-testing from interfering

### Layer tree (CSD)

```
Borderless NSWindow
 └─ ContentView (layer-backed)
     └─ Root Layer (no shadow)
         ├─ Shadow Layer (no hit testing)
         ├─ Client Frame Layer (CSD)
         │   └─ CAMetalLayer (wl_surface)
         └─ Subsurface Layers
```

---

## 6. Shadow layer (CSD requirement #1)

### Properties

```objc
shadowLayer.shadowOpacity = 0.5;
shadowLayer.shadowRadius = 20;
shadowLayer.masksToBounds = NO;
shadowLayer.allowsHitTesting = NO; // KEY
```

Shadow is:

* Visually present
* Click-through
* Outside client bounds

---

## 7. Resize logic (CSD requirement #2)

### You must implement:

* Edge detection
* Corner detection
* Cursor updates
* Resize feedback

### Flow

```
MouseDown → hit-test edges
  → begin resize
MouseDrag → resize CALayer bounds
  → xdg_toplevel.configure(new_size)
MouseUp → commit
```

### Important

* Resize regions are defined by **client-drawn decorations**
* But enforced by **compositor**

You *must not* rely on AppKit resize handling here.

---

## 8. GPU Accelerated Rendering (CSD & SSD)

### Unified pipeline

```
Wayland client
 → GPU buffer (dmabuf / shared memory)
 → IOSurface
 → CAMetalLayer
```

Use:

* One `CAMetalLayer` per `wl_surface`
* Shared Metal device
* Explicit frame pacing

---

## 9. Multi-surface clients (menus, popups, tooltips)

### Wayland truth

> Wayland allows **multiple simultaneous surfaces per client**

Examples:

* Right-click menus
* Dropdowns
* Tooltips
* Drag icons

---

## 10. xdg_popup handling (THIS IS THE HARD PART)

### Never embed popups into toplevel layers

Correct mapping:

### Option A (Preferred): Floating CALayer trees

```
Global Popup Host Layer
 └─ Popup Root Layer
     └─ CAMetalLayer
```

* Positioned in **global screen coordinates**
* Constrained to output bounds
* Above parent toplevel

### Option B (Fallback): Child borderless NSWindow

Use when:

* Popup must escape window bounds
* Popup needs separate focus

```objc
NSWindowStyleMaskBorderless
level = NSFloatingWindowLevel
```

Map:

```
xdg_popup → child NSWindow
```

---

## 11. Drawing outside NSWindow bounds (menus!)

### You cannot safely draw outside a window’s bounds with CALayer alone.

Therefore:

| Use case      | Solution                  |
| ------------- | ------------------------- |
| Tooltips      | Floating CALayer          |
| Menus         | Child borderless NSWindow |
| Drag icons    | Overlay CALayer           |
| Context menus | Popup NSWindow            |

This mirrors how:

* Dock
* Finder
* AppKit menus work internally

---

## 12. Focus & input routing

### Rule

* Focus belongs to **Wayland surface**, not NSWindow

### Mechanism

* Capture NSEvents
* Convert to Wayland seat events
* Route by:

  * Surface under cursor
  * Popup grabs

---

## 13. Summary: SSD vs CSD mapping

| Feature         | SSD      | CSD               |
| --------------- | -------- | ----------------- |
| NSWindow        | Yes      | Borderless        |
| macOS chrome    | Yes      | No                |
| Resize handling | AppKit   | Compositor        |
| Shadows         | AppKit   | Custom layer      |
| GPU rendering   | Yes      | Yes               |
| Popups          | NSWindow | NSWindow or Layer |
| xdg-decoration  | SSD      | CSD               |

---

## 14. Golden invariant (print this)

> **Wayland surfaces never know about macOS windows.
> macOS windows are merely transport containers.**

---

If you want next, I can:

* Draw an **object diagram** (wl_surface ↔ CALayer ↔ NSWindow)
* Show **exact hit-test math** for CSD resizing
* Map **xdg_popup grabs → NSEvent suppression**
* Explain **why shadow layers must live above subsurfaces but below popups**

You’re designing this correctly — this is a real compositor, not a hack.
