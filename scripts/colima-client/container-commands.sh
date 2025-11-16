#!/bin/bash
# Container-side command scripts (executed inside Docker container)

# Generate waypipe server command with weston installation and execution
generate_container_waypipe_command() {
    cat << 'CONTAINER_CMD_EOF'
waypipe --socket "$WAYPIPE_SOCKET" --display "$WAYPIPE_DISPLAY" server -- sh -c '
    export XDG_RUNTIME_DIR=/run/user/1000
    export WAYLAND_DISPLAY="$WAYPIPE_DISPLAY"
    export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:$PATH"
    
    # CRITICAL: Create/fix XDG_RUNTIME_DIR permissions BEFORE anything else
    # Must be 0700 and owned by current user (UID 0 in container)
    # With tmpfs mount (tmpfs-mode=0700), the directory should already have correct permissions
    # But we ensure it's set correctly just in case
    mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    # Ensure ownership is correct (UID 0 = root)
    chown root:root "$XDG_RUNTIME_DIR" 2>/dev/null || true
    
    # Verify permissions are correct
    CURRENT_MODE=$(stat -c "%a" "$XDG_RUNTIME_DIR" 2>/dev/null || echo "unknown")
    if [ "$CURRENT_MODE" != "700" ] && [ "$CURRENT_MODE" != "unknown" ]; then
        echo "⚠ Warning: XDG_RUNTIME_DIR permissions are $CURRENT_MODE, attempting to fix..."
        chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    fi
    
    # Set up fontconfig to avoid errors
    export FONTCONFIG_FILE=/etc/fonts/fonts.conf
    if [ ! -f "$FONTCONFIG_FILE" ]; then
        # Create minimal fontconfig config if it doesn'\''t exist
        mkdir -p /etc/fonts
        cat > "$FONTCONFIG_FILE" << '\''FONTCONFIG_EOF'\''
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
    
    # Suppress cursor theme warnings (harmless - Weston will use default cursors)
    export XCURSOR_THEME=default
    export XCURSOR_PATH=/usr/share/icons:/nix/store/*/share/icons
    
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
            # Install weston with wayland backend and Mesa (for GL rendering) using nix
            echo "   Installing Mesa (llvmpipe software GL) for GL rendering..."
            # Install Mesa with full EGL support including platform extensions
            # mesa.drivers provides llvmpipe with full EGL platform support
            MESA_OUTPUT=$(nix-env -iA nixpkgs.mesa.drivers nixpkgs.mesa 2>&1)
            MESA_EXIT=$?
            if [ $MESA_EXIT -eq 0 ] || echo "$MESA_OUTPUT" | grep -q "already installed"; then
                echo "✅ Mesa installed via nix-env"
            else
                # Try installing just mesa if drivers package doesn't exist
                MESA_OUTPUT=$(nix-env -iA nixpkgs.mesa 2>&1)
                MESA_EXIT=$?
                if [ $MESA_EXIT -eq 0 ] || echo "$MESA_OUTPUT" | grep -q "already installed"; then
                    echo "✅ Mesa installed via nix-env"
                else
                    echo "⚠ Mesa installation had issues, but continuing..."
                fi
            fi
            # Now install Weston and other dependencies
            INSTALL_OUTPUT=$(nix-env -iA nixpkgs.weston nixpkgs.dbus nixpkgs.xkeyboard_config 2>&1)
            INSTALL_EXIT=$?
            if [ $INSTALL_EXIT -eq 0 ] || echo "$INSTALL_OUTPUT" | grep -q "already installed"; then
                echo "✅ Weston installed via nix-env"
            else
                echo "⚠ Direct nix install failed, trying to find weston in nix store..."
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
        elif command -v dnf >/dev/null 2>&1; then
            # Fedora/RHEL
            echo "   Installing Mesa (llvmpipe software GL) for GL rendering..."
            # Install Mesa with full EGL support including platform extensions
            dnf install -y weston wayland-protocols-devel dbus-x11 xkeyboard-config mesa-libGL mesa-libEGL mesa-dri-drivers mesa-libGLES 2>/dev/null || \
            dnf install -y weston dbus-x11 xkeyboard-config mesa-libGL mesa-libEGL mesa-dri-drivers mesa-libGLES 2>/dev/null || {
                echo "❌ Failed to install Weston and Mesa"
                exit 1
            }
        elif command -v apk >/dev/null 2>&1; then
            # Alpine
            echo "   Installing Mesa (llvmpipe software GL) for GL rendering..."
            rm -f /var/cache/apk/*.lock /var/lib/apk/lock.* /var/lib/apk/lock 2>/dev/null || true
            sleep 1
            # Install Mesa with full EGL support including platform extensions
            apk update && apk add --no-cache weston weston-terminal dbus xkeyboard-config mesa mesa-gl mesa-egl mesa-dri-gallium mesa-gles || {
                echo "❌ Failed to install Weston and Mesa"
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
    # Waypipe server creates a compositor socket - wait for it and find it
    sleep 3
    # Find the actual compositor socket created by waypipe server
    SOCKET_FOUND=false
    ACTUAL_SOCKET=""
    EXPECTED_SOCKET="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    if [ -S "$EXPECTED_SOCKET" ]; then
        SOCKET_FOUND=true
        ACTUAL_SOCKET="$EXPECTED_SOCKET"
        echo "✅ Waypipe compositor socket found at expected location: $ACTUAL_SOCKET"
    else
        # Search for any wayland socket (excluding waypipe.sock control socket)
        echo "   Searching for waypipe compositor socket..."
        for sock in $(ls -1 "$XDG_RUNTIME_DIR"/wayland-* "$XDG_RUNTIME_DIR"/waypipe-* 2>/dev/null | grep -v waypipe.sock$); do
            if [ -n "$sock" ] && [ -S "$sock" ] 2>/dev/null; then
                SOCKET_FOUND=true
                ACTUAL_SOCKET="$sock"
                SOCKET_NAME=$(basename "$sock")
                echo "✅ Found waypipe compositor socket: $ACTUAL_SOCKET"
                export WAYLAND_DISPLAY="$SOCKET_NAME"
                echo "   Updated WAYLAND_DISPLAY to: $WAYLAND_DISPLAY"
                break
            fi
        done
        # If still not found, try a simpler approach - check for wayland-0 specifically
        if [ "$SOCKET_FOUND" = false ] && [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
            SOCKET_FOUND=true
            ACTUAL_SOCKET="$XDG_RUNTIME_DIR/wayland-0"
            export WAYLAND_DISPLAY="wayland-0"
            echo "✅ Found waypipe compositor socket: $ACTUAL_SOCKET"
            echo "   Updated WAYLAND_DISPLAY to: $WAYLAND_DISPLAY"
        fi
    fi
    if [ "$SOCKET_FOUND" = false ]; then
        echo "❌ Waypipe compositor socket not found in $XDG_RUNTIME_DIR"
        echo "   Expected: $EXPECTED_SOCKET"
        echo "   Directory contents:"
        ls -la "$XDG_RUNTIME_DIR/" 2>/dev/null || echo "   Directory not accessible"
        exit 1
    fi
    echo "   Using socket: $ACTUAL_SOCKET"
    echo "   WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    # Verify the socket is actually accessible (waypipe server is ready)
    echo "   Verifying socket is ready..."
    SOCKET_READY=false
    for i in 1 2 3 4 5; do
        if [ -S "$ACTUAL_SOCKET" ] && socat -u OPEN:/dev/null UNIX-CONNECT:"$ACTUAL_SOCKET" </dev/null 2>/dev/null; then
            SOCKET_READY=true
            break
        fi
        sleep 1
    done
    if [ "$SOCKET_READY" = false ]; then
        # Try without socat check (socat might not be available)
        if [ -S "$ACTUAL_SOCKET" ]; then
            echo "   Socket exists, assuming it'\''s ready"
            SOCKET_READY=true
        fi
    fi
    if [ "$SOCKET_READY" = false ]; then
        echo "❌ Socket not ready after waiting"
        exit 1
    fi
    echo "   Socket is ready"
    echo ""
    echo "🚀 Starting Weston compositor (via waypipe proxy)..."
    echo "   Backend: wayland (nested)"
    echo "   Parent socket: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY (waypipe proxy)"
    echo ""
    # Find weston binary and set up library paths
    if ! command -v weston >/dev/null 2>&1; then
        WESTON_BIN=$(find /nix/store -name weston -type f -executable 2>/dev/null | head -1)
        if [ -n "$WESTON_BIN" ]; then
            export PATH="$(dirname $WESTON_BIN):$PATH"
        else
            echo "❌ Weston binary not found"
            exit 1
        fi
    fi
    # Set library path for NixOS (weston and Mesa will find their libraries)
    export LD_LIBRARY_PATH="/nix/var/nix/profiles/default/lib:/root/.nix-profile/lib:$LD_LIBRARY_PATH"
    
    # Configure Mesa to use llvmpipe (software GL) for GL rendering BEFORE starting Weston
    # This allows Weston to use its GL renderer instead of falling back to Pixman
    # These MUST be set before any GL/EGL initialization (before weston starts)
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export MESA_GL_VERSION_OVERRIDE=3.3
    export MESA_GLSL_VERSION_OVERRIDE=330
    export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
    
    # Find and set up Mesa EGL libraries for platform extension support
    # EGL platform extensions require libEGL.so and proper Mesa drivers
    MESA_EGL=$(find /nix/store -name 'libEGL.so*' -type f 2>/dev/null | head -1)
    MESA_GL=$(find /nix/store -name 'libGL.so*' -type f 2>/dev/null | head -1)
    MESA_GLES=$(find /nix/store -name 'libGLESv2.so*' -type f 2>/dev/null | head -1)
    
    if [ -n "$MESA_EGL" ]; then
        MESA_EGL_DIR=$(dirname "$MESA_EGL")
        export LD_LIBRARY_PATH="$MESA_EGL_DIR:$LD_LIBRARY_PATH"
        echo "   Found Mesa EGL library at: $MESA_EGL"
    fi
    if [ -n "$MESA_GL" ]; then
        MESA_GL_DIR=$(dirname "$MESA_GL")
        export LD_LIBRARY_PATH="$MESA_GL_DIR:$LD_LIBRARY_PATH"
        echo "   Found Mesa GL library at: $MESA_GL"
    fi
    if [ -n "$MESA_GLES" ]; then
        MESA_GLES_DIR=$(dirname "$MESA_GLES")
        export LD_LIBRARY_PATH="$MESA_GLES_DIR:$LD_LIBRARY_PATH"
        echo "   Found Mesa GLES library at: $MESA_GLES"
    fi
    
    # Set EGL platform environment variables to help EGL find platform extensions
    # These help EGL initialize with platform support
    export EGL_PLATFORM=wayland
    export __EGL_VENDOR_LIBRARY_FILENAMES=/nix/store/*/share/glvnd/egl_vendor.d/*.json
    
    # Verify Mesa libraries are accessible
    if [ -z "$MESA_EGL" ] && [ -z "$MESA_GL" ]; then
        echo "⚠ Mesa libraries not found - GL rendering may fall back to Pixman"
    fi
    
    echo "   Configured Mesa llvmpipe (software GL) for GL rendering"
    echo "   LIBGL_ALWAYS_SOFTWARE=1"
    echo "   GALLIUM_DRIVER=llvmpipe"
    echo "   MESA_GL_VERSION_OVERRIDE=3.3"
    echo "   MESA_LOADER_DRIVER_OVERRIDE=llvmpipe"
    
    # Start Weston - it will connect to waypipe'\''s compositor socket
    echo "   Starting Weston with wayland backend..."
    # Verify weston is available
    if ! command -v weston >/dev/null 2>&1; then
        echo "❌ Weston command not found in PATH"
        exit 1
    fi
    echo "   Using weston: $(command -v weston)"
    echo "   WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    echo "   XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    echo "   Socket path: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    
    # Create Weston config file for fullscreen mode without decorations
    # This configures Weston's wayland backend to run fullscreen
    WESTON_CONFIG_DIR="$XDG_RUNTIME_DIR/weston-config"
    mkdir -p "$WESTON_CONFIG_DIR" 2>/dev/null || true
    WESTON_CONFIG="$WESTON_CONFIG_DIR/weston.ini"
    
    cat > "$WESTON_CONFIG" << 'WESTON_CONFIG_EOF'
[core]
# Use fullscreen shell to disable window decorations
shell=fullscreen-shell.so

[output]
# Configure wayland backend output to match parent compositor
# Weston will query Wawona's wl_output and use that size
name=wayland0
mode=current
# No window decorations - fullscreen mode
WESTON_CONFIG_EOF
    
    echo "   Created Weston config: $WESTON_CONFIG"
    echo "   Configuring for fullscreen mode (no decorations)"
    
    # Suppress harmless warnings by redirecting stderr for known issues
    # We'\''ll still see important errors but filter out:
    # - Cursor theme warnings (harmless)
    # - Fontconfig errors (we'\''ve set up fontconfig above)
    # - XDG_RUNTIME_DIR warnings (we'\''ve fixed permissions above)
    # Execute weston with config file - waypipe server will run this command
    # Weston connects to the waypipe compositor socket via WAYLAND_DISPLAY
    # With Mesa llvmpipe configured, Weston should use GL renderer instead of Pixman
    # Weston's wayland backend will query Wawona's wl_output and create matching fullscreen output
    weston --backend=wayland --socket=weston-0 --config="$WESTON_CONFIG" 2>&1 | grep -v "could not load cursor" | grep -v "Fontconfig error" | grep -v "XDG_RUNTIME_DIR.*is not configured correctly" || true
' &
WAYPIPE_SERVER_PID=$!
# Wait for waypipe server to start
sleep 2
# Keep container running
wait $WAYPIPE_SERVER_PID
CONTAINER_CMD_EOF
}

