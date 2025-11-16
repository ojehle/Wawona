#!/bin/bash
# Configuration and constants for container client

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Container configuration
CONTAINER_IMAGE="nixos/nix:latest"
CONTAINER_NAME="weston-container"

# Wayland runtime configuration
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/wayland-runtime}"
WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
SOCKET_PATH="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"

# Waypipe configuration
WAYPIPE_SOCKET="${HOME}/.wayland-runtime/waypipe.sock"
COCOMA_XDG_RUNTIME_DIR="${HOME}/.wayland-runtime"

# Socat TCP proxy configuration (workaround for macOS Containerization.framework)
# Use TCP to bypass Unix socket limitations in bind mounts
SOCAT_TCP_PORT="${SOCAT_TCP_PORT:-9999}"
SOCAT_TCP_HOST="127.0.0.1"
SOCAT_PID=""

