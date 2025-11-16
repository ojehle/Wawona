#!/bin/bash
# Container client script for macOS Containerization.framework
# Runs Weston nested compositor in NixOS container, connected to host compositor
# Uses waypipe to bypass VM boundary limitations with Unix domain sockets
#
# This script now delegates to the modular version in scripts/container-client/

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute the modular main script
exec "$SCRIPT_DIR/container-client/main.sh" "$@"
