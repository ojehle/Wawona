# 🎯 Wawona Implementation Strategy

**Reality Check: What We're Actually Building**

---

## 📦 What Homebrew's `wayland` Formula Actually Provides

Homebrew's `wayland` formula installs **ONLY** the core Wayland protocol libraries:

### ✅ What's Included:

1. **libwayland-server** - C API for Wayland protocol marshaling/unmarshaling
   - Handles `wl_display`, `wl_resource`, `wl_client` objects
   - Protocol event routing
   - Socket management (`wl_display_add_socket_auto`)
   
2. **libwayland-client** - C API for Wayland clients
   - Lets apps connect to a compositor
   - Used by test clients (QtWayland, etc.)
   
3. **libwayland-egl** - Minimal EGL platform wrapper
   - We won't use this
   
4. **wayland-scanner** - Tool to convert XML → C headers
   - Generates protocol bindings from `.xml` files
   - Critical for implementing protocols like xdg-shell
   
5. **Core protocol headers** - Basic Wayland protocol definitions

### ❌ What's NOT Included:

- ❌ No compositor implementation
- ❌ No rendering backend (we use CALayer)
- ❌ No input handling (we use NSEvent)
- ❌ No xdg-shell protocol (we implement ourselves)
- ❌ No layer-shell or other extra protocols
- ❌ No Linux stack (DRM/KMS, libinput, udev, libseat)

---

## 🚫 Why We're NOT Using WLRoots

**WLRoots requires Linux**. It has hard dependencies on:

1. **DRM/KMS** - Linux kernel display management
   - Direct Rendering Manager
   - Kernel Mode Setting
   - Only exists on Linux
   
2. **libinput** - Linux input device handling
   - Depends on udev (Linux-only)
   - Uses /dev/input devices (Linux-only)
   
3. **libudev** - Linux device management
   - Kernel device hotplug
   - Device enumeration
   - Doesn't exist on macOS
   
4. **libseat** - Linux session management
   - VT switching
   - Multi-seat support
   - Linux-specific

Even if we could compile WLRoots on macOS, **it cannot function** without these Linux kernel components.

---

## ✅ Our Implementation Strategy

We're building a **from-scratch compositor** using:

### 1. Protocol Layer (FROM HOMEBREW)

Use `libwayland-server` for:
- Protocol marshaling/unmarshaling
- Socket management
- Client connections
- Event routing

**Code example**:
```c
#include <wayland-server-core.h>

struct wl_display *display = wl_display_create();
const char *socket = wl_display_add_socket_auto(display);
struct wl_event_loop *loop = wl_display_get_event_loop(display);
```

### 2. Compositor Implementation (WE WRITE THIS)

Implement core Wayland interfaces:
- `wl_compositor` - Surface creation
- `wl_surface` - Client surfaces
- `wl_region` - Surface regions
- `wl_callback` - Frame callbacks

**We write handlers for all of these ourselves in Objective-C.**

### 3. Output Implementation (WE WRITE THIS)

Implement `wl_output` interface:
- Output geometry (screen size)
- Output modes (resolution, refresh rate)
- Scale factor
- Transform

**Backend**: NSWindow + NSScreen

### 4. Rendering Pipeline (WE WRITE THIS)

```
Client SHM buffer
    ↓
Read pixel data
    ↓
Create CGImageRef
    ↓
Set as CALayer contents
    ↓
Present to screen
```

**Technologies**:
- CoreGraphics (CGImage)
- QuartzCore (CALayer)
- CoreVideo (CADisplayLink for frame timing)

### 5. Input Handling (WE WRITE THIS)

Implement `wl_seat`, `wl_pointer`, `wl_keyboard`:

```objc
// NSEvent → Wayland events
- (void)mouseDown:(NSEvent *)event {
    // Convert NSEvent to wl_pointer.button event
    wl_pointer_send_button(pointer_resource, serial, time, button, state);
}

- (void)keyDown:(NSEvent *)event {
    // Convert NSEvent to wl_keyboard.key event
    wl_keyboard_send_key(keyboard_resource, serial, time, key, state);
}
```

### 6. Shell Protocol (WE WRITE THIS)

Implement xdg-shell protocol:
- `xdg_wm_base` - Window manager base
- `xdg_surface` - Surface role
- `xdg_toplevel` - Top-level windows
- `xdg_popup` - Popup surfaces

**Steps**:
1. Get xdg-shell protocol XML from wayland-protocols
2. Use `wayland-scanner` to generate C bindings
3. Implement all protocol handlers ourselves

---

## 📋 Implementation Phases

### Phase 1: Basic Foundation ✅ (Current)
- [x] Project structure
- [x] CMakeLists.txt (needs update to remove wlroots)
- [x] Documentation
- [x] Dependency checker
- [ ] Basic NSWindow + wl_display skeleton

### Phase 2: Protocol Core
- [ ] Initialize `wl_display`
- [ ] Create socket (`wl_display_add_socket_auto`)
- [ ] Implement `wl_compositor` interface
- [ ] Implement `wl_surface` creation
- [ ] Set up event loop integration with NSRunLoop

### Phase 3: Output & Rendering
- [ ] Implement `wl_output` interface
- [ ] Create CALayer rendering pipeline
- [ ] SHM buffer → CGImage conversion
- [ ] Frame timing with CADisplayLink
- [ ] Present CALayers to NSWindow

### Phase 4: Input Handling
- [ ] Implement `wl_seat` interface
- [ ] Implement `wl_pointer` (mouse)
- [ ] Implement `wl_keyboard` (keyboard)
- [ ] NSEvent → Wayland event translation
- [ ] Focus management

### Phase 5: Shell Protocol
- [ ] Get xdg-shell protocol XML
- [ ] Generate C bindings with wayland-scanner
- [ ] Implement `xdg_wm_base`
- [ ] Implement `xdg_surface`
- [ ] Implement `xdg_toplevel` (windows)
- [ ] Window geometry management

### Phase 6: Testing & Refinement
- [ ] Test with simple SHM client
- [ ] Test with QtWayland apps
- [ ] Multiple surface support
- [ ] Performance optimization
- [ ] Bug fixes

---

## 🛠️ Technical Details

### Event Loop Integration

**Challenge**: Wayland uses its own event loop, macOS uses NSRunLoop.

**Solution**: Integrate `wl_event_loop` with NSRunLoop using file descriptors:

```objc
int wl_fd = wl_event_loop_get_fd(loop);
NSFileHandle *fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:wl_fd];

// Monitor in NSRunLoop
[[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(waylandEventReady:)
    name:NSFileHandleDataAvailableNotification
    object:fileHandle];
[fileHandle waitForDataInBackgroundAndNotify];
```

### SHM Buffer Handling

**Challenge**: Convert Wayland SHM buffers to macOS CALayer.

**Solution**:

```objc
// 1. Get SHM buffer data
struct wl_shm_buffer *buffer = wl_shm_buffer_get(resource);
void *data = wl_shm_buffer_get_data(buffer);
int32_t width = wl_shm_buffer_get_width(buffer);
int32_t height = wl_shm_buffer_get_height(buffer);
int32_t stride = wl_shm_buffer_get_stride(buffer);

// 2. Create CGImage
CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, stride * height, NULL);
CGImageRef image = CGImageCreate(width, height, 8, 32, stride, 
    CGColorSpaceCreateDeviceRGB(), kCGImageAlphaFirst, provider, NULL, false, kCGRenderingIntentDefault);

// 3. Set as CALayer contents
layer.contents = (__bridge id)image;
```

### Keyboard Input

**Challenge**: Convert macOS key codes to Linux keycodes (what Wayland expects).

**Solution**: Key mapping table + XKB integration.

```objc
// Simple mapping example
uint32_t macKeyToLinuxKey(unsigned short macKeyCode) {
    // Map NSEvent.keyCode to Linux keycode
    // Reference: /usr/include/linux/input-event-codes.h
    switch (macKeyCode) {
        case 0x00: return 0x1e; // 'A' key
        case 0x01: return 0x1f; // 'S' key
        // ... etc
    }
}
```

---

## 📖 References & Resources

### Wayland Protocol Documentation
- [Wayland Book](https://wayland-book.com/) - Excellent tutorial
- [Wayland Protocol Spec](https://wayland.freedesktop.org/docs/html/)
- [wayland-protocols Repository](https://gitlab.freedesktop.org/wayland/wayland-protocols)

### Example Compositors (for reference)
- [tinywl](https://gitlab.freedesktop.org/wlroots/wlroots/-/tree/master/tinywl) - Minimal WLRoots compositor (we can't use WLRoots, but the logic is instructive)
- [swc](https://github.com/michaelforney/swc) - Simple Wayland Compositor (uses its own backend)
- [way-cooler](https://github.com/way-cooler/way-cooler) - Wayland compositor in Rust

### macOS Technologies
- [Core Animation Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/Introduction/Introduction.html)
- [CALayer Reference](https://developer.apple.com/documentation/quartzcore/calayer)
- [NSEvent Reference](https://developer.apple.com/documentation/appkit/nsevent)

---

## 🎯 Bottom Line

**We're building a minimal Wayland compositor from scratch using**:
- ✅ `libwayland-server` (protocol layer only)
- ✅ Objective-C + macOS frameworks (everything else)
- ✅ CALayer for rendering
- ✅ NSEvent for input
- ✅ Custom compositor logic

**We are NOT**:
- ❌ Using WLRoots (Linux-only)
- ❌ Using any Linux-specific libraries
- ❌ Trying to port Linux code

**This is achievable** - it's essentially:
1. Protocol handling (libwayland-server does most of this)
2. Buffer → Image conversion (straightforward)
3. Input translation (tedious but simple)
4. Window management (shell protocol implementation)

The Wayland protocol is **platform-agnostic**. The Linux-specific parts (DRM, libinput, etc.) are just **one way** to implement a compositor. We're implementing it **the macOS way**.

---

_Last updated: 2024-11-16_

