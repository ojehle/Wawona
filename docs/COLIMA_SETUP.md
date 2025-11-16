# Colima Setup for Wayland Container Client

## Overview

Colima is an alternative container runtime for macOS that uses Lima (Linux virtual machines) to run containers. Unlike macOS Containerization.framework, **Colima supports Unix domain sockets across bind mounts** when configured with VirtioFS.

This makes Colima a viable alternative for running Weston in containers connected to the macOS Wayland compositor.

## Installation

```bash
# Install Colima via Homebrew
brew install colima docker docker-compose

# Start Colima with VirtioFS (required for Unix domain sockets)
colima start --mount-type virtiofs

# Verify Colima is running
colima status
```

## Key Differences from Containerization.framework

1. **Unix Domain Socket Support**: ✅ Works with VirtioFS
2. **VM-based**: Uses a Linux VM (Lima) instead of native containers
3. **Docker-compatible**: Uses Docker daemon inside the VM
4. **More overhead**: VM adds some overhead compared to native containers

## Usage with Wayland Compositor

Once Colima is running with VirtioFS, you can use Docker to run Weston:

```bash
# Set environment variables
export XDG_RUNTIME_DIR=/tmp/wayland-runtime
export WAYLAND_DISPLAY=wayland-0

# Run Weston in Docker container with socket bind mount
docker run --rm -it \
  --mount type=bind,source=$XDG_RUNTIME_DIR,target=/run/user/1000 \
  -e XDG_RUNTIME_DIR=/run/user/1000 \
  -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  fedora:latest \
  sh -c "
    dnf install -y weston dbus-x11 xkeyboard-config && \
    weston --backend=wayland --socket=weston-0
  "
```

## Advantages

- ✅ **Unix domain sockets work** (with VirtioFS)
- ✅ Standard Docker interface
- ✅ Better compatibility with Linux containers
- ✅ More mature and widely used

## Disadvantages

- ⚠️ Requires VM (more resource overhead)
- ⚠️ Slower startup than native containers
- ⚠️ More complex setup than Containerization.framework

## Migration from Containerization.framework

To migrate the `container-client.sh` script to use Colima/Docker:

1. Replace `container` commands with `docker` commands
2. Ensure Colima is started with `--mount-type virtiofs`
3. Use Docker volume mounts instead of `container` mount syntax
4. Container image names remain the same (e.g., `nixos/nix:latest`)

## References

- [Colima Documentation](https://github.com/abiosoft/colima)
- [VirtioFS Mount Type](https://medium.com/@kanishks772/yeah-bind-mounts-on-macos-arm64-have-been-rough-01e5fed47cfe)

