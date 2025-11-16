# Client Connection Commands

## ✅ Correct Way to Run the Test Client

### Method 1: Simple Script (Easiest)

```bash
./RUN_CLIENT.sh
```

This automatically sets everything up.

### Method 2: Manual Setup

**Important**: Don't include comments in the export command!

❌ **Wrong**:
```bash
export WAYLAND_DISPLAY=wayland-0  # Use the socket name
```

✅ **Correct**:
```bash
export WAYLAND_DISPLAY=wayland-0
./test_client
```

### Method 3: Source Environment Script

```bash
source SET_ENV.sh wayland-0
./test_client
```

Or in one line:
```bash
source SET_ENV.sh wayland-0 && ./test_client
```

## Finding the Socket Name

When you start the compositor, it prints:
```
✅ Wayland socket created: wayland-0
```

Use that exact name (might be `wayland-0`, `wayland-1`, etc.)

## Complete Example

**Terminal 1** (Compositor):
```bash
./build.sh --run
# Note the socket name: wayland-0
```

**Terminal 2** (Client):
```bash
export WAYLAND_DISPLAY=wayland-0
./test_client
```

Or simply:
```bash
./RUN_CLIENT.sh
```

## Troubleshooting

### "export: not an identifier"
- You included a comment in the export command
- Remove the `# comment` part
- Run: `export WAYLAND_DISPLAY=wayland-0` (no comment)

### "Failed to connect"
- Make sure compositor is running
- Check socket name matches exactly
- Verify `XDG_RUNTIME_DIR` is set (test client sets it automatically)

