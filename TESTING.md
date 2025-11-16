# Testing Wawona Compositor

## Quick Start

### 1. Start the Compositor

```bash
./build.sh --run
```

The compositor will:
- Open an NSWindow titled "Wawona"
- Create a Wayland socket (e.g., `wayland-0`)
- Print connection instructions

### 2. Connect a Test Client

In a **new terminal**, set the Wayland display:

```bash
export WAYLAND_DISPLAY=wayland-0  # (or whatever socket name was printed)
```

**Note**: The test client automatically sets `XDG_RUNTIME_DIR` if not set, so you only need `WAYLAND_DISPLAY`.

### 3. Run the Test Client

**Option A: Direct run**
```bash
make -f Makefile.test_client
./test_client
```

**Option B: Using helper script**
```bash
./connect-client.sh ./test_client
```

The helper script automatically sets both `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`.

The test client will:
- Connect to the compositor
- Create a window with a colored gradient
- Display the window in the compositor's NSWindow

## What the Test Client Does

The `test_client.c` program:
1. Connects to the Wayland display
2. Gets required globals (`wl_compositor`, `wl_shm`, `xdg_wm_base`)
3. Creates a surface and xdg_toplevel
4. Allocates a shared memory buffer
5. Fills it with a red-green gradient pattern
6. Attaches and commits the buffer
7. Waits for user input before exiting

## Expected Behavior

When running the test client:
- ✅ A window should appear in the compositor's NSWindow
- ✅ The window should display a colored gradient (red-green)
- ✅ Mouse and keyboard input should work
- ✅ The window can be moved/resized (if implemented)

## Troubleshooting

### Client can't connect
- Make sure `WAYLAND_DISPLAY` matches the socket name printed by the compositor
- Check that `XDG_RUNTIME_DIR` is set (compositor sets it automatically)

### Window doesn't appear
- Check compositor logs for errors
- Verify the compositor is still running
- Check that SHM buffer was created successfully

### Input doesn't work
- Make sure the compositor window has focus
- Check that input handling was initialized (should see "Input handling active" in logs)

## Testing with Other Wayland Clients

You can test with other Wayland clients if available:

```bash
# QtWayland example (if installed)
export WAYLAND_DISPLAY=wayland-0
qtwayland5-example

# Or any other Wayland client
```

## Next Steps

- Test with multiple clients simultaneously
- Test window management (move, resize, minimize)
- Test input handling thoroughly
- Performance testing

