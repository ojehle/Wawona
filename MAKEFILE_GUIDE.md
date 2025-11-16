# Makefile Guide

## Overview

The main `Makefile` orchestrates all operations for the Wawona compositor project.

## Quick Reference

```bash
make help              # Show all available targets
make all               # Check deps, install wayland (if needed), build compositor
make check-deps        # Check all dependencies
make install-wayland   # Build and install Wayland from source
make build             # Build the compositor
make build-client      # Build the test client
make run-compositor    # Run the compositor
make run-client        # Run the test client
make test              # Build and run test client
make clean             # Clean build artifacts
make clean-all         # Clean everything including Wayland
make rebuild           # Clean and rebuild
make quick-start       # Full setup with instructions
```

## Common Workflows

### First Time Setup

```bash
make all
```

This will:
1. Check dependencies
2. Install Wayland if not found
3. Build the compositor

### Daily Development

**Terminal 1** (Compositor):
```bash
make run-compositor
```

**Terminal 2** (Client):
```bash
make run-client
```

### Rebuild After Changes

```bash
make rebuild
```

### Clean Everything

```bash
make clean-all
```

## Target Details

### `make check-deps`
- Runs `./check-deps.sh`
- Checks for cmake, pkg-config, clang, wayland-server, pixman
- Shows what's installed and what's missing

### `make install-wayland`
- Runs `./install-wayland.sh`
- Clones Wayland repository
- Builds and installs Wayland from source
- Handles macOS-specific patches

### `make build`
- Runs `./build.sh`
- Configures CMake
- Builds the compositor binary
- Verifies binary was created

### `make build-client`
- Builds the test client using `Makefile.test_client`
- Generates xdg-shell protocol bindings if needed
- Creates `test_client` binary

### `make run-compositor`
- Builds compositor if not built
- Runs the compositor binary
- Sets up environment automatically
- Shows connection instructions

### `make run-client`
- Builds test client if not built
- Sets `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`
- Checks for compositor socket
- Runs the test client

### `make test`
- Alias for `make run-client`
- Assumes compositor is already running

### `make clean`
- Removes `build/` directory
- Cleans test client artifacts
- Keeps Wayland installation

### `make clean-all`
- Everything from `make clean`
- Plus removes Wayland source directory
- Removes Wayland install log

### `make all`
- Complete setup workflow
- Checks dependencies
- Installs Wayland if needed
- Builds compositor
- Shows next steps

### `make quick-start`
- Same as `make all`
- Plus shows quick start instructions

## Environment Variables

You can override defaults:

```bash
WAYLAND_DISPLAY=wayland-1 make run-client
XDG_RUNTIME_DIR=/custom/path make run-client
```

## Examples

### Full Setup from Scratch

```bash
make all
```

### Run Everything

**Terminal 1:**
```bash
make run-compositor
```

**Terminal 2:**
```bash
make run-client
```

### Rebuild After Code Changes

```bash
make rebuild
make run-compositor
```

### Clean Start

```bash
make clean-all
make all
```

## Tips

- Use `make help` to see all targets
- `make run-compositor` builds automatically if needed
- `make run-client` builds client automatically if needed
- Both `run-*` targets check prerequisites
- Use `make clean-all` to start completely fresh

