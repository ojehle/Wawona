#!/bin/bash
# Test various Wayland clients via Colima/Docker
# Supports: foot, GTK apps, Qt apps, etc.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/waypipe-setup.sh"
source "$SCRIPT_DIR/docker-setup.sh"
source "$SCRIPT_DIR/container-setup.sh"

CLIENT_TYPE="${1:-foot}"

case "$CLIENT_TYPE" in
    foot|terminal)
        echo "Testing foot terminal..."
        CLIENT_CMD="foot --version"
        ;;
    gtk|gedit|nautilus)
        echo "Testing GTK application..."
        CLIENT_CMD="gedit --version || nautilus --version || echo 'GTK app not available'"
        ;;
    qt|qtcreator)
        echo "Testing Qt application..."
        CLIENT_CMD="qtcreator --version || echo 'Qt app not available'"
        ;;
    *)
        echo "Unknown client type: $CLIENT_TYPE"
        echo "Usage: $0 [foot|gtk|qt]"
        exit 1
        ;;
esac

# Use existing colima-client infrastructure
check_compositor_socket
ensure_runtime_directories
setup_waypipe

# Run client in container
docker run --rm -it \
    --network host \
    -v "$COCOMA_XDG_RUNTIME_DIR:/host-wayland-runtime:ro" \
    -v "/run/user/1000:/run/user/1000:rw" \
    -e WAYLAND_DISPLAY="wayland-0" \
    -e XDG_RUNTIME_DIR="/host-wayland-runtime" \
    nixos/nix:latest \
    sh -c "$CLIENT_CMD"

