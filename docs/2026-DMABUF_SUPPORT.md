# macOS 2026 DMABUF Support

This document outlines the implementation details for enabling hardware-accelerated rendering through `waypipe` on macOS using the `linux-dmabuf` protocol and `IOSurface`.

## Architecture Overview

The core challenge on macOS is that there is no native `dmabuf` support. However, `waypipe` (running locally or remotely) can be patched to intercept DMABUF requests and map them to platform-specific handles. On macOS, we use `IOSurface` as the backing store.

### Components

1.  **Waypipe (Patched)**:
    *   Intercepts `zwp_linux_dmabuf_v1` requests.
    *   Uses a custom modifier flag (high bit set) to indicate that the buffer handle is an `IOSurfaceID`.
    *   Passes the `IOSurfaceID` in the `modifier` field of the DMABUF plane.
    *   *Note*: This requires `waypipe` to be running on the same host (or a host that understands global IOSurface IDs, which is effectively local-only for now without virtualization).

2.  **Wawona Core (Rust)**:
    *   Implements `zwp_linux_dmabuf_v1` server protocol.
    *   Detects the `IOSurface` flag in the modifier.
    *   Extracts the `IOSurfaceID`.
    *   Creates a `Buffer` with `BufferType::Native(NativeBufferData { id, ... })`.
    *   Does *not* import the buffer using EGL/Vulkan/GBM at this stage. It simply stores the ID.

3.  **Wawona FFI (Rust/C interface)**:
    *   Exposes `BufferType::Native` as `BufferData::Iosurface` to the FFI layer.
    *   Populates a `CBufferData` struct with the `iosurface_id`.

4.  **Wawona Platform (Objective-C/Metal)**:
    *   `WawonaCompositorBridge` receives the committed buffer.
    *   Checks for a non-zero `iosurface_id`.
    *   calls `IOSurfaceLookup(id)` to get the `IOSurfaceRef`.
    *   Sets the `contents` property of the `CALayer` (specifically `CAMetalLayer` or `CALayer`) to the `IOSurfaceRef`.
    *   CoreAnimation handles the direct scanout/composition of the IOSurface.

## Implementation Details

### 1. Protocol Handling (`src/core/wayland/linux_dmabuf.rs`)

We implement the `zwp_linux_buffer_params_v1` interface.

*   **`add` request**: We collect plane information (FDs, offsets, strides, modifiers). We convert the `OwnedFd` to a raw FD to store it (though currently we rely on the ID in the modifier, so the FD is less critical for the IOSurface path).
*   **`create_immed` request**: This is where the buffer is created.
    *   We check if the modifier has the high bit set (`0x8000_0000_0000_0000`).
    *   If set, we extract the `IOSurfaceID` from the lower bits.
    *   We verify the ID exists using `IOSurfaceLookup` (optional safety check).
    *   We create a `Buffer` with `BufferType::Native`.

### 2. Buffer Storage (`src/core/surface/buffer.rs`)

A new struct `NativeBufferData` was added to hold platform-specific handles:

```rust
pub struct NativeBufferData {
    pub id: u64, // IOSurfaceID
    pub width: i32,
    pub height: i32,
    pub format: u32,
}
```

The `BufferType` enum acts as a variant for this:

```rust
pub enum BufferType {
    Shm(ShmBuffer),
    Native(NativeBufferData),
    // ...
}
```

### 3. FFI & Bridge (`src/ffi/`)

*   **`src/ffi/types.rs`**: Added `Iosurface` variant to `BufferData`.
*   **`src/ffi/c_api.rs`**: Added `iosurface_id` to `CBufferData`.
*   **`src/platform/macos/WawonaCompositorBridge.m`**:
    *   Imports `IOSurface` framework.
    *   In `pollAndRenderBuffers`:
        ```objective-c
        if (buffer->iosurface_id != 0) {
            IOSurfaceRef surf = IOSurfaceLookup(buffer->iosurface_id);
            window.contentView.layer.contents = (__bridge id)surf;
            CFRelease(surf); // Layer retains it
        }
        ```

## Verification workflow

To verify this implementation:

1.  Build Wawona: `cargo build`.
2.  Ensure `waypipe` is built with the macOS patch (via `macos.nix`).
3.  Run Wawona.
4.  Run a storage-based client or `weston-terminal` through `waypipe`:
    ```bash
    waypipe ssh localhost weston-terminal
    ```
5.  Check logs for:
    *   `linux-dmabuf: Importing IOSurface ID ...`
    *   `BRIDGE: Found IOSurface ID...`

## Future Improvements

*   **Texture Import**: Currently we assign the IOSurface directly to the layer contents. For more advanced composition (shaders, non-rectangular windows), we should import the IOSurface into a `MTLTexture`.
*   **Protocol Hardening**: Better validation of FDs and modifiers.
*   **Multi-plane Support**: Currently assumes single-plane IOSurfaces (which is standard for most GUI formats on macOS).
