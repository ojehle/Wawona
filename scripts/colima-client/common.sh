#!/bin/bash
# Common variables and functions for colima-client scripts

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

# Colima-compatible paths
COCOMA_XDG_RUNTIME_DIR="${HOME}/.wayland-runtime"

# Waypipe configuration
WAYPIPE_SOCKET="${HOME}/.wayland-runtime/waypipe.sock"
WAYPIPE_CLIENT_PID=""

# Get script directory (where this common.sh is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
