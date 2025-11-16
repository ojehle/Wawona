# How Wayland Works: Complete Guide for macOS

## Table of Contents
1. [What is Wayland?](#what-is-wayland)
2. [Core Components](#core-components)
3. [The Wayland Protocol](#the-wayland-protocol)
4. [Architecture Overview](#architecture-overview)
5. [How It Works on macOS](#how-it-works-on-macos)
6. [Component Breakdown](#component-breakdown)
7. [The Complete Flow](#the-complete-flow)
8. [macOS-Specific Details](#macos-specific-details)

---

## What is Wayland?

**Wayland** is a **display server protocol** and **communication standard** between:
- **Compositors** (the display server)
- **Clients** (applications that want to display windows)

Think of it like HTTP for windows: clients make requests, the server responds, and they communicate over a socket.

**Key Point**: Wayland is NOT a running service. It's a **protocol specification** and **libraries** that implement that protocol.

---

## Core Components

### 1. **Wayland Compositor** (The Server)
- **What it is**: A program that manages windows, handles input, and renders everything to the screen
- **Examples**: GNOME Mutter, KDE KWin, Sway, **your Wawona**
- **Responsibilities**:
  - Creates a Unix socket (e.g., `/tmp/wayland-0`)
  - Listens for client connections
  - Manages windows/surfaces
  - Handles input (keyboard, mouse, touch)
  - Composites (combines) all windows into final output
  - Renders to display hardware

### 2. **Wayland Clients** (Applications)
- **What they are**: Programs that want to display windows
- **Examples**: Qt applications, GTK applications, terminal emulators
- **How they work**:
  - Connect to compositor's socket
  - Request surfaces (windows) from compositor
  - Draw content into buffers
  - Send buffers to compositor for display

### 3. **Wayland Libraries**
- **`libwayland-server`**: Server-side protocol implementation
  - Provides `wl_display` (the server object)
  - Socket creation (`wl_display_add_socket_auto`)
  - Protocol message handling
  - Event loop integration
  
- **`libwayland-client`**: Client-side protocol implementation
  - Connects to compositor socket
  - Sends requests to compositor
  - Receives events from compositor

### 4. **WLRoots** (Compositor Toolkit)
- **What it is**: A library that makes building compositors easier
- **Provides**:
  - Backend abstraction (DRM, X11, headless, **macOS**)
  - Output management
  - Input device handling
  - Buffer management (SHM, EGL, DMA-BUF)
  - Renderer abstraction
- **Why we use it**: Instead of implementing Wayland protocol from scratch, WLRoots handles the hard parts

### 5. **Protocol Extensions**
- **Core protocol**: Basic window management
- **Extensions**: Additional features
  - `wlr-output-management`: Display configuration
  - `wlr-input-method`: Input method (IME)
  - `wlr-layer-shell`: Overlay layers
  - `xdg-shell`: Desktop shell integration

---

## The Wayland Protocol

### Communication Model

```
┌─────────────────────────────────────────┐
│         Wayland Compositor              │
│  ┌───────────────────────────────────┐  │
│  │   wl_display (server)             │  │
│  │   Creates: /tmp/wayland-0        │  │
│  │   Listens for connections        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │   wlr_backend (macOS)             │  │
│  │   - Output management             │  │
│  │   - Input handling                │  │
│  │   - Buffer rendering              │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
           ▲                    │
           │                    │
    [Unix Socket]         [Rendering]
           │                    │
           │                    ▼
┌──────────┴────────────────────┴──────────┐
│                                           │
│  ┌────────────────────────────────────┐  │
│  │   Wayland Client (Qt App)         │  │
│  │   - Connects to socket            │  │
│  │   - Creates surfaces              │  │
│  │   - Sends buffers                 │  │
│  └────────────────────────────────────┘  │
│                                           │
└───────────────────────────────────────────┘
```

### Message Types

1. **Requests**: Client → Compositor
   - "Create a surface"
   - "Attach buffer to surface"
   - "Commit surface changes"

2. **Events**: Compositor → Client
   - "Surface configured (size, position)"
   - "Keyboard focus changed"
   - "Pointer entered surface"

3. **Objects**: Both sides create objects
   - `wl_surface`: A window/surface
   - `wl_seat`: Input device (keyboard/mouse)
   - `wl_output`: Display output

---

## Architecture Overview

### Traditional X11 Model (for comparison)
```
App → X11 Server → Kernel (DRM) → Hardware
```
- X11 server is separate process
- Apps send drawing commands
- Server renders everything

### Wayland Model
```
App → Compositor (which also renders) → Hardware
```
- Compositor IS the display server
- Apps send pixel buffers
- Compositor composites (combines) buffers

### Key Difference
- **X11**: Apps tell server "draw a line here"
- **Wayland**: Apps render themselves, send pixels, compositor combines them

---

## How It Works on macOS

### The macOS Wayland Stack

```
┌─────────────────────────────────────────────────────┐
│              macOS System                            │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  Wawona (Your Compositor)        │   │
│  │                                               │   │
│  │  ┌──────────────────────────────────────┐    │   │
│  │  │  wl_display (Wayland Server)        │    │   │
│  │  │  Socket: /tmp/wayland-0             │    │   │
│  │  └──────────────────────────────────────┘    │   │
│  │                                               │   │
│  │  ┌──────────────────────────────────────┐    │   │
│  │  │  wlr_backend (macOS Backend)        │    │   │
│  │  │  - NSWindow management               │    │   │
│  │  │  - CALayer rendering                 │    │   │
│  │  │  - Input event handling              │    │   │
│  │  └──────────────────────────────────────┘    │   │
│  │                                               │   │
│  │  ┌──────────────────────────────────────┐    │   │
│  │  │  NSWindow + CALayer                  │    │   │
│  │  │  (macOS native window)                │    │   │
│  │  └──────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  Wayland Clients                             │   │
│  │  - QtWayland apps                            │   │
│  │  - GTK Wayland apps                          │   │
│  │  - Terminal emulators                        │   │
│  │  Connect via: WAYLAND_DISPLAY=wayland-0      │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### What Runs Where

1. **Your Compositor** (`Wawona`)
   - Runs as normal macOS app
   - Creates NSWindow
   - Creates Wayland socket
   - Handles all Wayland protocol

2. **Wayland Clients**
   - Run as normal macOS apps
   - Connect to your compositor's socket
   - Render their own content
   - Send buffers to compositor

3. **No Separate Services**
   - No `wayland-server` daemon
   - No X11 server
   - No display manager
   - Just your compositor + clients

---

## Component Breakdown

### 1. Wayland Display Server (`wl_display`)

**Server Side** (`libwayland-server`):
```c
struct wl_display *display = wl_display_create();
wl_display_add_socket_auto(display);  // Creates /tmp/wayland-0
wl_display_run(display);              // Event loop
```

**What it does**:
- Creates Unix domain socket
- Listens for client connections
- Routes protocol messages
- Manages object lifecycle
- Handles event loop

**Client Side** (`libwayland-client`):
```c
struct wl_display *display = wl_display_connect("wayland-0");
// Now connected to compositor
```

### 2. Surfaces (`wl_surface`)

**What they are**: Windows/rectangles that hold content

**Lifecycle**:
1. Client creates surface: `wl_compositor_create_surface()`
2. Client attaches buffer: `wl_surface_attach(buffer, x, y)`
3. Client commits: `wl_surface_commit()`
4. Compositor receives buffer
5. Compositor renders buffer to screen
6. Compositor sends frame callback when done

### 3. Buffers

**Types**:
- **SHM (Shared Memory)**: Simple pixel buffers
  - Client allocates shared memory
  - Fills with pixels
  - Sends to compositor
  - Compositor reads pixels
  
- **EGL**: GPU-accelerated buffers
  - Client renders with OpenGL/Vulkan
  - Creates EGL buffer
  - Sends to compositor
  - Compositor can use GPU directly

- **DMA-BUF**: Linux-specific, zero-copy GPU buffers

**On macOS**: We'll use SHM buffers → convert to CGImage → render to CALayer

### 4. Input (`wl_seat`)

**What it handles**:
- Keyboard events
- Pointer (mouse) events
- Touch events

**Flow**:
1. User moves mouse → macOS sends NSEvent
2. Compositor converts to Wayland event
3. Compositor sends to focused client
4. Client handles event

### 5. Output (`wl_output`)

**What it represents**: A physical or virtual display

**On macOS**:
- Your NSWindow is an output
- Can have multiple outputs (multiple windows)
- Each output has resolution, refresh rate, etc.

---

## The Complete Flow

### Startup Sequence

1. **Compositor Starts**
   ```
   ./Wawona
   ```
   - Creates `wl_display`
   - Creates socket `/tmp/wayland-0`
   - Initializes macOS backend
   - Creates NSWindow + CALayer
   - Starts event loop

2. **Client Starts**
   ```
   export WAYLAND_DISPLAY=wayland-0
   ./MyQtApp -platform wayland
   ```
   - Reads `WAYLAND_DISPLAY` environment variable
   - Connects to `/tmp/wayland-0`
   - Establishes Wayland connection

### Window Creation Flow

1. **Client requests surface**:
   ```
   Client → Compositor: "Create surface"
   Compositor → Client: "Here's your surface (id: 42)"
   ```

2. **Client renders content**:
   ```
   Client: Renders pixels to buffer
   Client → Compositor: "Attach buffer to surface 42"
   Client → Compositor: "Commit surface 42"
   ```

3. **Compositor receives buffer**:
   ```
   Compositor: Receives buffer from client
   Compositor: Converts buffer (SHM → CGImage)
   Compositor: Creates CALayer for surface
   Compositor: Adds CALayer to window's layer tree
   ```

4. **Compositor renders**:
   ```
   Compositor: CALayer tree renders to NSWindow
   macOS: NSWindow displays on screen
   ```

5. **Compositor notifies client**:
   ```
   Compositor → Client: "Frame done (you can render next frame)"
   ```

### Input Flow

1. **User presses key**:
   ```
   macOS → Compositor: NSEvent (keyDown)
   ```

2. **Compositor processes**:
   ```
   Compositor: Determines focused surface
   Compositor: Converts NSEvent → Wayland event
   ```

3. **Compositor sends to client**:
   ```
   Compositor → Client: "Key pressed on surface 42"
   ```

4. **Client handles**:
   ```
   Client: Processes key event
   Client: Updates UI
   Client: Renders new frame
   Client → Compositor: "New buffer for surface 42"
   ```

---

## macOS-Specific Details

### Why This Works on macOS

1. **Unix Domain Sockets**: macOS supports them (same as Linux)
   - Wayland uses Unix sockets for IPC
   - Works identically on macOS

2. **No Kernel Dependencies**: Wayland is userspace
   - Doesn't need DRM (Direct Rendering Manager)
   - Doesn't need GBM (Generic Buffer Management)
   - Doesn't need libinput (we use NSEvent)
   - Pure userspace protocol

3. **Native Rendering**: CALayer is macOS's compositing system
   - Similar to how Linux uses DRM/KMS
   - We render Wayland surfaces as CALayers
   - macOS handles final display

### What We're Building

**macOS Backend for WLRoots**:
- Similar to `wlr/backend/headless.c` (virtual backend)
- Similar to `wlr/backend/x11.c` (X11 backend)
- But renders to CALayer instead

**Components**:
1. **Output Backend**: Creates/manages NSWindow + CALayer
2. **Input Backend**: Converts NSEvent → Wayland events
3. **Renderer**: Converts Wayland buffers → CALayer content
4. **Frame Loop**: CADisplayLink for 60fps rendering

### Dependencies Explained

**`libwayland-server`**:
- Wayland protocol server implementation
- Provides `wl_display`, socket handling, message routing
- **Not a service** - just a library linked into your compositor

**`libwayland-client`**:
- Wayland protocol client implementation
- Used by QtWayland, GTK, etc.
- Connects to compositor socket

**`wlroots`**:
- Compositor toolkit
- Provides backend abstraction
- Handles buffer management, output/input abstraction
- We implement macOS backend for it

**`pixman`**:
- Low-level pixel manipulation library
- Used for buffer operations, format conversion
- Required by wlroots

---

## Key Takeaways

1. **Wayland is a protocol**, not a service
2. **Your compositor IS the Wayland server**
3. **No separate daemons needed** - everything runs in your app
4. **Clients connect via Unix socket** to your compositor
5. **On macOS**: We use CALayer for rendering instead of DRM
6. **Everything runs natively** - no Linux, VM, or container needed

---

## Next Steps

Now that you understand the architecture:

1. **Build the skeleton** (already done)
2. **Implement macOS backend**:
   - Output creation (NSWindow + CALayer)
   - Buffer conversion (SHM → CGImage → CALayer)
   - Input handling (NSEvent → Wayland events)
   - Frame loop (CADisplayLink)

3. **Test with clients**:
   - Build QtWayland app
   - Connect to your compositor
   - See windows appear!

---

## Resources

- **Wayland Protocol Spec**: https://wayland.freedesktop.org/docs/html/
- **WLRoots Documentation**: https://gitlab.freedesktop.org/wlroots/wlroots
- **Wayland Book**: https://wayland-book.com/
- **macOS CALayer Docs**: https://developer.apple.com/documentation/quartzcore/calayer

