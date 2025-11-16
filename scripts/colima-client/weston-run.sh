#!/bin/bash
# Weston execution logic

# Setup weston binary and library paths
setup_weston_paths() {
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
    
    # Set library path for NixOS (weston will find its own libraries)
    export LD_LIBRARY_PATH="/nix/var/nix/profiles/default/lib:/root/.nix-profile/lib:$LD_LIBRARY_PATH"
}

# Verify weston is available
verify_weston() {
    if ! command -v weston >/dev/null 2>&1; then
        echo "❌ Weston command not found in PATH"
        exit 1
    fi
    echo "   Using weston: $(command -v weston)"
    echo "   WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    echo "   XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    echo "   Socket path: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
}

# Run weston with wayland backend
run_weston() {
    echo "🚀 Starting Weston compositor (via waypipe proxy)..."
    echo "   Backend: wayland (nested)"
    echo "   Parent socket: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY (waypipe proxy)"
    echo ""
    
    # Fix XDG_RUNTIME_DIR permissions (must be 0700)
    if [ -d "$XDG_RUNTIME_DIR" ]; then
        chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    else
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 0700 "$XDG_RUNTIME_DIR"
    fi
    
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
    
    setup_weston_paths
    verify_weston
    
    echo "   Starting Weston with wayland backend..."
    # Configure Mesa to use llvmpipe (software GL) for GL rendering
    # This allows Weston to use its GL renderer instead of falling back to Pixman
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export MESA_GL_VERSION_OVERRIDE=3.3
    export MESA_GLSL_VERSION_OVERRIDE=330
    export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
    
    # Set EGL platform environment variables for platform extension support
    export EGL_PLATFORM=wayland
    
    # Find and set up Mesa EGL libraries
    MESA_EGL=$(find /nix/store -name 'libEGL.so*' -type f 2>/dev/null | head -1)
    MESA_GL=$(find /nix/store -name 'libGL.so*' -type f 2>/dev/null | head -1)
    if [ -n "$MESA_EGL" ]; then
        MESA_EGL_DIR=$(dirname "$MESA_EGL")
        export LD_LIBRARY_PATH="$MESA_EGL_DIR:$LD_LIBRARY_PATH"
    fi
    if [ -n "$MESA_GL" ]; then
        MESA_GL_DIR=$(dirname "$MESA_GL")
        export LD_LIBRARY_PATH="$MESA_GL_DIR:$LD_LIBRARY_PATH"
    fi
    
    echo "   Configured Mesa llvmpipe (software GL) for GL rendering"
    echo "   LIBGL_ALWAYS_SOFTWARE=1"
    echo "   GALLIUM_DRIVER=llvmpipe"
    echo "   MESA_GL_VERSION_OVERRIDE=3.3"
    echo "   EGL_PLATFORM=wayland"
    
    # Execute weston directly - waypipe server will run this command
    # Weston connects to the waypipe compositor socket via WAYLAND_DISPLAY
    # With Mesa llvmpipe configured, Weston should use GL renderer instead of Pixman
    # Suppress harmless warnings while keeping important errors visible
    weston --backend=wayland --socket=weston-0 2>&1 | grep -v "could not load cursor" | grep -v "Fontconfig error" | grep -v "XDG_RUNTIME_DIR.*is not configured correctly" || true
}

# Generate waypipe server command with weston
generate_waypipe_server_command() {
    cat << 'WAYPIPE_CMD_EOF'
waypipe --socket "$WAYPIPE_SOCKET" --display "$WAYPIPE_DISPLAY" server -- sh -c '
    export XDG_RUNTIME_DIR=/run/user/1000
    export WAYLAND_DISPLAY="$WAYPIPE_DISPLAY"
    export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:$PATH"
    
    # Fix XDG_RUNTIME_DIR permissions (must be 0700)
    if [ -d "$XDG_RUNTIME_DIR" ]; then
        chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    else
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 0700 "$XDG_RUNTIME_DIR"
    fi
    
    # Set up fontconfig to avoid errors
    export FONTCONFIG_FILE=/etc/fonts/fonts.conf
    if [ ! -f "$FONTCONFIG_FILE" ]; then
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
    
    # Suppress cursor theme warnings (harmless)
    export XCURSOR_THEME=default
    export XCURSOR_PATH=/usr/share/icons:/nix/store/*/share/icons
    
    # Install Weston if needed
    install_weston
    
    echo ""
    echo "🔍 Verifying Wayland socket (waypipe proxy)..."
    detect_waypipe_socket "$XDG_RUNTIME_DIR" "$WAYLAND_DISPLAY"
    verify_socket_ready "$ACTUAL_SOCKET"
    
    echo ""
    run_weston
' &
WAYPIPE_CMD_EOF
}

