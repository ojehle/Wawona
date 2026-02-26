# Attaching a Debugger

Use `--debug` with `nix run` to launch Wawona under LLDB on macOS, iOS, or Android.

## Quick Reference

```bash
# macOS — run under LLDB from start
nix run .#wawona-macos -- --debug

# iOS Simulator — app pauses at spawn, LLDB attaches
nix run .#wawona-ios -- --debug

# Android — app waits for debugger, LLDB attaches via lldb-server
nix run .#wawona-android -- --debug
```

---

## macOS

```bash
nix run .#wawona-macos -- --debug
```

- Wawona is started **under LLDB** from the beginning
- LLDB runs the app; you can set breakpoints before `run`
- On exit, LLDB prints a full backtrace (`bt all`)
- **Alternative:** `WAWONA_LLDB=1 nix run .#wawona-macos` (same behavior)

---

## iOS Simulator

```bash
nix run .#wawona-ios -- --debug
```

1. Simulator boots and Wawona.app is installed
2. App is launched with `--wait-for-debugger` (paused at spawn)
3. LLDB attaches to the app PID
4. dSYM is loaded if present for symbols
5. Simulator logs stream in the background

After attach, type `continue` in LLDB to resume execution.

---

## Android

```bash
nix run .#wawona-android -- --debug
```

1. Emulator starts (or uses existing device)
2. App is launched with `am start -D` (waits for debugger)
3. `lldb-server` is pushed to the device and started
4. LLDB connects via `gdb-remote` on port 5039
5. Java VM resumes after ~4 seconds; native code runs under LLDB

**Requirements:** `adb` and `emulator` in PATH; device/emulator with USB debugging.

On crash, LLDB stops and gives an interactive prompt. Use `bt` for backtrace.
