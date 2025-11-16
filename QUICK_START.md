# Quick Start Guide

## 🚀 Get Started in 3 Steps

### Step 1: Start the Compositor

```bash
./build.sh --run
```

You'll see output like:
```
✅ Wayland socket created: wayland-0
   Clients can connect with: export WAYLAND_DISPLAY=wayland-0
```

**Keep this terminal open!**

### Step 2: Open a New Terminal

Open a **new terminal window** (the compositor keeps running in the first one).

### Step 3: Run a Client

**Easy way** (using helper script):
```bash
cd /Users/alex/Wawona
./connect-client.sh ./test_client
```

**Manual way**:
```bash
cd /Users/alex/Wawona
export WAYLAND_DISPLAY=wayland-0
./test_client
```

**Or use the helper script**:
```bash
./RUN_CLIENT.sh
```

## ✅ Expected Result

You should see:
- A window appears in the compositor's NSWindow
- The window displays a colored gradient (red-green)
- Mouse and keyboard input work

## 🔧 Troubleshooting

### "XDG_RUNTIME_DIR is invalid or not set"
✅ **Fixed!** The test client now sets this automatically.

### "Failed to connect to Wayland display"
- Make sure compositor is running (check Step 1)
- Verify `WAYLAND_DISPLAY` matches the socket name
- Check compositor logs for the exact socket name

### "Socket not found"
- Compositor must be running first
- Use the exact socket name printed by compositor
- Socket is in `$XDG_RUNTIME_DIR/wayland-*`

## 📝 Notes

- The compositor creates `XDG_RUNTIME_DIR` automatically
- The test client also sets it if missing
- Socket name might be `wayland-0`, `wayland-1`, etc. (check compositor output)
- Both compositor and client use the same runtime directory

## 🎯 Next Steps

Once the test client works:
- Try multiple clients simultaneously
- Test with other Wayland applications
- Experiment with window management

