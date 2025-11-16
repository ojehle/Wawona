#!/bin/bash
# Weston installation logic

# Install Weston using Nix
install_weston_nix() {
    echo "📦 Installing Weston and dependencies..."
    echo "   Using Nix package manager..."
    
    # Set up nixpkgs channel if not already set up
    if [ ! -d "/root/.nix-defexpr/channels" ] || [ ! -L "/root/.nix-defexpr/channels/nixpkgs" ]; then
        echo "   Setting up nixpkgs channel..."
        mkdir -p /root/.nix-defexpr/channels
        nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs 2>/dev/null || true
        nix-channel --update nixpkgs 2>/dev/null || true
    fi
    
    # Install weston with wayland backend and Mesa (for GL rendering) using nix
    echo "   Installing Mesa (llvmpipe software GL) for GL rendering..."
    INSTALL_OUTPUT=$(nix-env -iA nixpkgs.weston nixpkgs.dbus nixpkgs.xkeyboard_config nixpkgs.mesa 2>&1)
    INSTALL_EXIT=$?
    
    if [ $INSTALL_EXIT -eq 0 ] || echo "$INSTALL_OUTPUT" | grep -q "already installed"; then
        echo "✅ Weston and Mesa installed via nix-env"
    else
        echo "⚠ Direct nix install failed, trying to find weston in nix store..."
        # Try to find weston in nix store directly (may already be available)
        WESTON_BIN=$(find /nix/store -name weston -type f -executable 2>/dev/null | head -1)
        if [ -n "$WESTON_BIN" ]; then
            WESTON_STORE=$(dirname "$WESTON_BIN" | xargs dirname)
            export PATH="$(dirname $WESTON_BIN):$PATH"
            echo "✅ Weston found in nix store at: $WESTON_BIN"
        else
            echo "❌ Failed to install or find Weston"
            echo "   Try running: nix-channel --update nixpkgs && nix-env -iA nixpkgs.weston"
            exit 1
        fi
    fi
    
    # Verify weston is accessible
    if ! command -v weston >/dev/null 2>&1; then
        echo "⚠ Weston not in PATH, searching in nix store..."
        WESTON_BIN=$(find /nix/store -name weston -type f -executable 2>/dev/null | head -1)
        if [ -n "$WESTON_BIN" ]; then
            export PATH="$(dirname $WESTON_BIN):$PATH"
            echo "   Found weston at: $WESTON_BIN"
        else
            echo "❌ Weston not found after installation"
            exit 1
        fi
    fi
}

# Install Weston using dnf (Fedora/RHEL)
install_weston_dnf() {
    echo "   Installing Mesa (llvmpipe software GL) for GL rendering..."
    dnf install -y weston wayland-protocols-devel dbus-x11 xkeyboard-config mesa-libGL mesa-dri-drivers 2>/dev/null || \
    dnf install -y weston dbus-x11 xkeyboard-config mesa-libGL mesa-dri-drivers 2>/dev/null || {
        echo "❌ Failed to install Weston and Mesa"
        exit 1
    }
}

# Install Weston using apk (Alpine)
install_weston_apk() {
    echo "   Installing Mesa (llvmpipe software GL) for GL rendering..."
    rm -f /var/cache/apk/*.lock /var/lib/apk/lock.* /var/lib/apk/lock 2>/dev/null || true
    sleep 1
    apk update && apk add --no-cache weston weston-terminal dbus xkeyboard-config mesa mesa-gl mesa-dri-gallium || {
        echo "❌ Failed to install Weston and Mesa"
        exit 1
    }
}

# Install Weston based on available package manager
install_weston() {
    if command -v weston >/dev/null 2>&1; then
        echo "✅ Weston already installed, skipping package installation"
        return 0
    fi
    
    if command -v nix-env >/dev/null 2>&1 || command -v nix >/dev/null 2>&1; then
        install_weston_nix
    elif command -v dnf >/dev/null 2>&1; then
        install_weston_dnf
    elif command -v apk >/dev/null 2>&1; then
        install_weston_apk
    else
        echo "❌ Unsupported package manager"
        exit 1
    fi
    
    echo "✅ Weston installed"
}

