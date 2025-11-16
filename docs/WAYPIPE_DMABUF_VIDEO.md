# Waypipe DMA-BUF and Video Codec Support

## Current Status

Waypipe shows `dmabuf: false` and `video: false` because these features need to be enabled at build time. Our compositor **already supports** DMA-BUF emulation via IOSurface and video codec encoding/decoding via Metal/VideoToolbox.

## Enabling DMA-BUF and Video in Waypipe

To enable these features in waypipe, you need to rebuild waypipe with the appropriate flags:

### Option 1: Build from Source with Features Enabled

```bash
# Clone waypipe
git clone https://gitlab.freedesktop.org/mstoeckl/waypipe.git
cd waypipe

# Configure with dmabuf and video support
meson setup build \
    -Ddmabuf=enabled \
    -Dvideo=enabled \
    -Dbuildtype=release

# Build
meson compile -C build

# Install
sudo meson install -C build
```

### Option 2: Use Our Patched Waypipe (Recommended)

Since waypipe's dmabuf/video support is designed for Linux, you'll need macOS-specific patches:

1. **DMA-BUF Support**: Waypipe needs to be patched to use IOSurface instead of Linux DMA-BUF
2. **Video Codec Support**: Waypipe needs to use VideoToolbox (H.264) instead of Linux video codecs

### Current Compositor Support

Our compositor **already implements**:

✅ **DMA-BUF Emulation** (`src/metal_dmabuf.m/h`)
- IOSurface-based buffer sharing
- Metal texture creation from IOSurface
- File descriptor support for IPC

✅ **Video Codec Support** (`src/metal_waypipe.m/h`)
- H.264 encoder (VTCompressionSession)
- H.264 decoder (VTDecompressionSession)
- CVPixelBuffer integration

✅ **Metal Integration**
- Automatic waypipe context initialization
- GPU-accelerated compositing
- Texture fallback for non-waypipe clients

## Next Steps

To fully enable waypipe with dmabuf/video:

1. **Patch waypipe** to use IOSurface instead of Linux DMA-BUF
2. **Patch waypipe** to use VideoToolbox instead of Linux video codecs
3. **Rebuild waypipe** with these patches
4. **Test** with `waypipe --version` to verify features are enabled

## Testing

Once waypipe is rebuilt with dmabuf/video support:

```bash
# Check features
waypipe --version
# Should show: dmabuf: true, video: true

# Test with waypipe
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/tmp/wayland-runtime \
  waypipe ssh user@host weston-terminal
```

## Notes

- The cursor warnings (`dnd-move`, `dnd-copy`, `dnd-none`) are harmless client-side warnings
- The `?2004` parameter warning is a terminal feature request, not an error
- Weston's `listener function for opcode 2` error should be fixed with the wl_output done event version check

