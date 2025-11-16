#!/bin/bash
# Weston installation and execution logic

# Generate container command script
generate_container_script() {
    cat <<'CONTAINER_SCRIPT'
# Set up environment first (before set -e)
export XDG_RUNTIME_DIR=/run/user/1000
export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:$PATH"

set -e

# Check if waypipe is available in container
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

# Run waypipe server in container, connecting to waypipe client via TCP proxy
# Use socat to create Unix socket that forwards to TCP (workaround for macOS limitation)
echo "🚀 Starting waypipe server in container..."
# Create writable directory for waypipe socket
mkdir -p /run/user/1000

# Install socat in container if needed (for TCP proxy workaround)
if ! command -v socat >/dev/null 2>&1; then
    echo "📦 Installing socat for TCP proxy..."
    if command -v nix-env >/dev/null 2>&1 || command -v nix >/dev/null 2>&1; then
        nix-env -iA nixpkgs.socat 2>/dev/null || {
            echo "⚠ Direct nix install failed, trying alternative..."
            # Try to find socat in nix store
            SOCAT_BIN=$(find /nix/store -name socat -type f -executable 2>/dev/null | head -1)
            if [ -n "$SOCAT_BIN" ]; then
                export PATH="$(dirname $SOCAT_BIN):$PATH"
                echo "✅ Socat found in nix store"
            else
                echo "❌ Failed to install socat"
                exit 1
            fi
        }
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache socat || {
            echo "❌ Failed to install socat"
            exit 1
        }
    else
        echo "❌ Cannot install socat - unsupported package manager"
        exit 1
    fi
fi

# Use TCP proxy instead of direct Unix socket (macOS Containerization.framework workaround)
# Match colima-client.sh approach for consistency
SOCAT_TCP_PORT="${SOCAT_TCP_PORT:-9999}"
WAYPIPE_LOCAL_SOCK="/tmp/waypipe-container.sock"

# Determine host IP - try multiple methods (same as colima-client)
HOST_IP=""

# Method 1: Try host.docker.internal first (Docker/Colima convention, may work for Containerization.framework)
if getent hosts host.docker.internal >/dev/null 2>&1; then
    HOST_IP=$(getent hosts host.docker.internal | awk '{print $1}' | head -1)
    echo "ℹ  Using host.docker.internal: $HOST_IP"
fi

# Method 2: Try to get gateway IP from route table
if [ -z "$HOST_IP" ] && command -v route >/dev/null 2>&1; then
    GATEWAY_IP=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}' | head -1)
    if [ -n "$GATEWAY_IP" ] && [ "$GATEWAY_IP" != "127.0.0.1" ]; then
        HOST_IP="$GATEWAY_IP"
        echo "ℹ  Using gateway IP from route table: $HOST_IP"
    fi
fi

# Method 3: Try common host IPs with TCP connection test
if [ -z "$HOST_IP" ]; then
    echo "ℹ  Testing common host IPs..."
    for ip in 192.168.64.1 192.168.65.1 172.17.0.1 10.0.2.2; do
        echo "   Testing $ip:$SOCAT_TCP_PORT..."
        if command -v nc >/dev/null 2>&1; then
            if nc -z -w 2 "$ip" "$SOCAT_TCP_PORT" 2>/dev/null; then
                HOST_IP="$ip"
                echo "✅ Found host IP via TCP connection test: $HOST_IP"
                break
            fi
        elif command -v bash >/dev/null 2>&1; then
            if timeout 2 bash -c "exec 3<>/dev/tcp/$ip/$SOCAT_TCP_PORT" 2>/dev/null; then
                exec 3<&-
                exec 3>&-
                HOST_IP="$ip"
                echo "✅ Found host IP via TCP connection test: $HOST_IP"
                break
            fi
        fi
    done
fi

# Use WAYPIPE_HOST_IP if explicitly set
if [ -z "$HOST_IP" ] && [ -n "$WAYPIPE_HOST_IP" ]; then
    HOST_IP="$WAYPIPE_HOST_IP"
    echo "ℹ  Using WAYPIPE_HOST_IP: $HOST_IP"
fi

# Error if still no host IP
if [ -z "$HOST_IP" ]; then
    echo "❌ Could not determine host IP address"
    echo "   Tried: host.docker.internal, route table, common IPs"
    echo "   Please set WAYPIPE_HOST_IP environment variable"
    exit 1
fi

echo "ℹ  Connecting to waypipe client via TCP ($HOST_IP:$SOCAT_TCP_PORT)..."
echo "ℹ  This bypasses macOS Containerization.framework Unix socket limitations"

# Use socat to proxy TCP to Unix socket for waypipe server (match colima-client.sh exactly)
# waypipe server expects Unix socket, so we create a local socket and proxy TCP to it
rm -f "$WAYPIPE_LOCAL_SOCK"

# Start socat proxy before waypipe server (match colima-client.sh syntax)
# Use TCP: instead of TCP-CONNECT: and add unlink-early like colima-client
socat UNIX-LISTEN:"$WAYPIPE_LOCAL_SOCK",fork,reuseaddr,unlink-early TCP:"$HOST_IP:$SOCAT_TCP_PORT" >/tmp/socat-container.log 2>&1 &
SOCAT_PID=$!

# Wait for socat to create the socket and establish TCP connection (match colima-client timing)
sleep 3

# Verify socket exists before starting waypipe
if [ ! -S "$WAYPIPE_LOCAL_SOCK" ]; then
    echo "❌ Socat failed to create socket: $WAYPIPE_LOCAL_SOCK"
    cat /tmp/socat-container.log 2>/dev/null | tail -10
    kill $SOCAT_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Socket proxy ready: $WAYPIPE_LOCAL_SOCK"

# Verify TCP connection is actually working before starting waypipe
echo "ℹ  Verifying TCP connection to host..."
if command -v nc >/dev/null 2>&1; then
    if nc -z -w 3 "$HOST_IP" "$SOCAT_TCP_PORT" 2>/dev/null; then
        echo "✅ TCP connection to host verified"
    else
        echo "⚠ TCP connection test failed - connection may not be ready"
        echo "   This may cause waypipe to fail"
    fi
fi

WAYPIPE_DISPLAY="waypipe-server"

# Start waypipe server - it will create a compositor socket
# and connect to the waypipe client socket via the proxy
# Ensure runtime directory exists and is writable
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

echo "ℹ  Starting waypipe server (connecting via TCP proxy)..."
waypipe --socket "$WAYPIPE_LOCAL_SOCK" --display "$WAYPIPE_DISPLAY" server -- sh -c '
    export XDG_RUNTIME_DIR=/run/user/1000
    export WAYLAND_DISPLAY=waypipe-server
    export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:$PATH"
    
    # Check if Weston is already installed
    if command -v weston >/dev/null 2>&1; then
        echo "✅ Weston already installed, skipping package installation"
    else
        echo "📦 Installing Weston and dependencies..."
        # Detect package manager and install accordingly
        if command -v nix-env >/dev/null 2>&1 || command -v nix >/dev/null 2>&1; then
            # NixOS/Nix
            echo "   Using Nix package manager..."
            # Set up nixpkgs channel if not already set up
            if [ ! -d "/root/.nix-defexpr/channels" ] || [ ! -L "/root/.nix-defexpr/channels/nixpkgs" ]; then
                echo "   Setting up nixpkgs channel..."
                mkdir -p /root/.nix-defexpr/channels
                nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs 2>/dev/null || true
                nix-channel --update nixpkgs 2>/dev/null || true
            fi
            # Install weston with wayland backend using nix (note: xkeyboard_config not xkeyboard-config)
            INSTALL_OUTPUT=$(nix-env -iA nixpkgs.weston nixpkgs.dbus nixpkgs.xkeyboard_config 2>&1)
            INSTALL_EXIT=$?
            if [ $INSTALL_EXIT -eq 0 ] || echo "$INSTALL_OUTPUT" | grep -q "already installed"; then
                echo "✅ Weston installed via nix-env"
            else
                echo "⚠ Direct nix install failed, trying nix-build approach..."
                # Use nix-build to get weston (escape single quotes)
                WESTON_STORE=$(nix-build '\''<nixpkgs>'\'' -A weston --no-out-link 2>/dev/null || echo "")
                if [ -n "$WESTON_STORE" ] && [ -f "$WESTON_STORE/bin/weston" ]; then
                    export PATH="$WESTON_STORE/bin:$PATH"
                    echo "✅ Weston found in nix store"
                else
                    echo "❌ Failed to install or find Weston"
                    exit 1
                fi
            fi
            # PATH already set at top of script
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
        elif command -v dnf >/dev/null 2>&1; then
            # Fedora/RHEL
            dnf install -y weston wayland-protocols-devel dbus-x11 xkeyboard-config 2>/dev/null || \
            dnf install -y weston dbus-x11 xkeyboard-config 2>/dev/null || {
                echo "❌ Failed to install Weston"
                exit 1
            }
        elif command -v apk >/dev/null 2>&1; then
            # Alpine
            rm -f /var/cache/apk/*.lock /var/lib/apk/lock.* /var/lib/apk/lock 2>/dev/null || true
            sleep 1
            apk update && apk add --no-cache weston weston-terminal dbus xkeyboard-config || {
                echo "❌ Failed to install Weston"
                exit 1
            }
        else
            echo "❌ Unsupported package manager"
            exit 1
        fi
        echo "✅ Weston installed"
    fi
    echo ""
    echo "🔍 Verifying Wayland socket (waypipe proxy)..."
    # Wait longer for waypipe server to fully initialize (match colima-client timing)
    sleep 3
    SOCKET_FOUND=false
    ACTUAL_SOCKET=""
    EXPECTED_SOCKET="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    
    # First check for the expected socket (waypipe-server)
    if [ -S "$EXPECTED_SOCKET" ]; then
        SOCKET_FOUND=true
        ACTUAL_SOCKET="$EXPECTED_SOCKET"
        echo "✅ Waypipe compositor socket found at expected location: $ACTUAL_SOCKET"
    else
        echo "   Searching for waypipe compositor socket..."
        # Prefer waypipe-* sockets over wayland-* (waypipe server creates waypipe-server)
        for sock in $(ls -1 "$XDG_RUNTIME_DIR"/waypipe-* "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | grep -v waypipe.sock$); do
            if [ -n "$sock" ] && [ -S "$sock" ] 2>/dev/null; then
                SOCKET_NAME=$(basename "$sock")
                # Skip wayland-0 if it's not the waypipe server socket
                if [ "$SOCKET_NAME" = "wayland-0" ] && [ -S "$XDG_RUNTIME_DIR/waypipe-server" ]; then
                    continue
                fi
                SOCKET_FOUND=true
                ACTUAL_SOCKET="$sock"
                echo "✅ Found waypipe compositor socket: $ACTUAL_SOCKET"
                export WAYLAND_DISPLAY="$SOCKET_NAME"
                echo "   Updated WAYLAND_DISPLAY to: $WAYLAND_DISPLAY"
                break
            fi
        done
        # Fallback: if waypipe-server exists, use it
        if [ "$SOCKET_FOUND" = false ] && [ -S "$XDG_RUNTIME_DIR/waypipe-server" ]; then
            SOCKET_FOUND=true
            ACTUAL_SOCKET="$XDG_RUNTIME_DIR/waypipe-server"
            export WAYLAND_DISPLAY="waypipe-server"
            echo "✅ Found waypipe compositor socket: $ACTUAL_SOCKET"
            echo "   Updated WAYLAND_DISPLAY to: $WAYLAND_DISPLAY"
        fi
    fi
    
    if [ "$SOCKET_FOUND" = false ]; then
        echo "❌ Waypipe compositor socket not found in $XDG_RUNTIME_DIR"
        ls -la "$XDG_RUNTIME_DIR/" 2>/dev/null || echo "   Directory not accessible"
        exit 1
    fi
    
    echo "   Using socket: $ACTUAL_SOCKET"
    echo "   WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    echo "   Verifying socket is ready..."
    # Wait for waypipe server to fully initialize and bind to socket
    sleep 4
    
    # Check if socket exists - waypipe server creates it when ready
    if [ ! -S "$ACTUAL_SOCKET" ]; then
        echo "❌ Socket not found: $ACTUAL_SOCKET"
        echo "   Directory contents:"
        ls -la "$XDG_RUNTIME_DIR/" 2>/dev/null || echo "   Directory not accessible"
        exit 1
    fi
    
    # Socket exists - waypipe server is ready
    # Try optional socat verification (non-blocking)
    if command -v socat >/dev/null 2>&1; then
        if socat -u OPEN:/dev/null UNIX-CONNECT:"$ACTUAL_SOCKET" </dev/null 2>/dev/null; then
            echo "   Socket verified with socat"
        else
            echo "   Socket exists, socat verification skipped (socket may still be initializing)"
        fi
    else
        echo "   Socket exists, assuming ready (socat not available)"
    fi
    echo "   Socket is ready"
    echo ""
    echo "🚀 Starting Weston compositor (via waypipe proxy)..."
    echo "   Backend: wayland (nested)"
    echo "   Parent socket: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY (waypipe proxy)"
    echo ""
    
    # CRITICAL: Create/fix XDG_RUNTIME_DIR permissions BEFORE anything else
    # Must be 0700 and owned by current user (UID 0 in container)
    if [ -d "$XDG_RUNTIME_DIR" ]; then
        # Try to fix permissions - if it fails, remove and recreate
        if ! chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null; then
            rm -rf "$XDG_RUNTIME_DIR"/* 2>/dev/null || true
            rmdir "$XDG_RUNTIME_DIR" 2>/dev/null || true
        fi
    fi
    # Create directory with correct permissions from the start
    mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chown root:root "$XDG_RUNTIME_DIR" 2>/dev/null || true
    
    # Set up fontconfig to avoid errors
    export FONTCONFIG_FILE=/etc/fonts/fonts.conf
    if [ ! -f "$FONTCONFIG_FILE" ]; then
        mkdir -p /etc/fonts
        cat > "$FONTCONFIG_FILE" << 'FONTCONFIG_EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <dir>/usr/share/fonts</dir>
    <dir>/nix/store/*/share/fonts</dir>
    <cachedir>/tmp/fontconfig-cache</cachedir>
    <include ignore_missing="yes">conf.d</include>
</fontconfig>
FONTCONFIG_EOF
        mkdir -p /tmp/fontconfig-cache
    fi
    
    # Suppress cursor theme warnings (harmless)
    export XCURSOR_THEME=default
    export XCURSOR_PATH=/usr/share/icons:/nix/store/*/share/icons
    
    # Find weston binary and set up library paths
    WESTON_CMD="weston"
    if ! command -v weston >/dev/null 2>&1; then
        WESTON_BIN=$(find /nix/store -name weston -type f -executable 2>/dev/null | head -1)
        if [ -n "$WESTON_BIN" ]; then
            WESTON_CMD="$WESTON_BIN"
            export PATH="$(dirname $WESTON_BIN):$PATH"
        else
            echo "❌ Weston binary not found"
            exit 1
        fi
    fi
    # Set library path for NixOS (weston will find its own libraries)
    export LD_LIBRARY_PATH="/nix/var/nix/profiles/default/lib:/root/.nix-profile/lib:$LD_LIBRARY_PATH"
    # Start Weston - it will connect to waypipe'\''s compositor socket
    echo "   Starting Weston with wayland backend..."
    if [ -z "$WESTON_CMD" ]; then
        WESTON_CMD=weston
    fi
    # Suppress harmless warnings while keeping important errors visible
    "$WESTON_CMD" --backend=wayland --socket=weston-0 2>&1 | grep -v "could not load cursor" | grep -v "Fontconfig error" | grep -v "XDG_RUNTIME_DIR.*is not configured correctly" || true
' &
WAYPIPE_SERVER_PID=$!
# Wait for waypipe server to start
sleep 2
# Keep container running
wait $WAYPIPE_SERVER_PID
CONTAINER_SCRIPT
}

