#!/bin/bash
# Container-side waypipe installation

# Install waypipe in container
install_container_waypipe() {
    if ! command -v waypipe >/dev/null 2>&1; then
        echo "📦 Installing waypipe..."
        # Try to install waypipe via nix
        nix-env -iA nixpkgs.waypipe 2>/dev/null || {
            echo "⚠ waypipe installation failed, trying alternative method..."
            # Set up nixpkgs channel if not already set up
            if [ ! -d "/root/.nix-defexpr/channels" ] || [ ! -L "/root/.nix-defexpr/channels/nixpkgs" ]; then
                mkdir -p /root/.nix-defexpr/channels
                nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs 2>/dev/null || true
                nix-channel --update nixpkgs 2>/dev/null || true
            fi
            nix-env -iA nixpkgs.waypipe 2>/dev/null || {
                echo "❌ Failed to install waypipe"
                echo "   Waypipe is required for VM boundary bypass"
                exit 1
            }
        }
    fi
}

# Generate container exec command for waypipe server
generate_container_exec_command() {
    cat << 'EXEC_CMD_EOF'
sh -c "
# Set up environment first (before set -e)
export XDG_RUNTIME_DIR=/run/user/1000
export PATH=\"/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:\$PATH\"

set -e

# Check if waypipe is available in container
if ! command -v waypipe >/dev/null 2>&1; then
    echo \"📦 Installing waypipe...\"
    nix-env -iA nixpkgs.waypipe 2>/dev/null || {
        echo \"⚠ waypipe installation failed, trying alternative method...\"
        if [ ! -d \"/root/.nix-defexpr/channels\" ] || [ ! -L \"/root/.nix-defexpr/channels/nixpkgs\" ]; then
            mkdir -p /root/.nix-defexpr/channels
            nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs 2>/dev/null || true
            nix-channel --update nixpkgs 2>/dev/null || true
        fi
        nix-env -iA nixpkgs.waypipe 2>/dev/null || {
            echo \"❌ Failed to install waypipe\"
            echo \"   Waypipe is required for VM boundary bypass\"
            exit 1
        }
    }
fi

# Run waypipe server in container
echo \"🚀 Starting waypipe server in container...\"
WAYPIPE_SOCKET=\"/run/user/1000/waypipe.sock\"
WAYPIPE_DISPLAY=\"waypipe-server\"

waypipe --socket \"\$WAYPIPE_SOCKET\" --display \"\$WAYPIPE_DISPLAY\" server -- sh -c '
EXEC_CMD_EOF
}

