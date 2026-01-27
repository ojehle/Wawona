# Wawona Wayland Display

## XDG_RUNTIME_DIR

The XDG_RUNTIME_DIR environment variable is used to specify the directory where runtime files are stored. It is a standard environment variable used by many applications to store runtime files, and it is typically set to a directory in the user's home directory.

On linux, this is typically set to `/run/user/<UID>`, but on macOS and iOS, it is not set by default.

Wawona will create a runtime directory in `/tmp/<UID>-runtime` if XDG_RUNTIME_DIR is not set.
We also need chmod 700 to be safe.

## WAYLAND_DISPLAY

The WAYLAND_DISPLAY environment variable is used to specify the display to connect to. It is a standard environment variable used by many applications to connect to a Wayland display.

On linux, this is typically set to `wayland-0`, but on macOS and iOS, it is not set by default.

Wawona will create a socket in `/tmp/<UID>-runtime/wayland-0` if WAYLAND_DISPLAY is not set.

## Summary

- Wawona will create a runtime directory in `/tmp/<UID>-runtime` if XDG_RUNTIME_DIR is not set. 
- Wawona will create a socket in `/tmp/<UID>-runtime/wayland-0` if WAYLAND_DISPLAY is not set.

When using cli tools, you can set XDG_RUNTIME_DIR and WAYLAND_DISPLAY to connect to the compositor using these values by default.