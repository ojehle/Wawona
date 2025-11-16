#!/bin/bash
# Socket detection and verification

# Detect waypipe compositor socket
detect_waypipe_socket() {
    local XDG_RUNTIME_DIR="$1"
    local WAYLAND_DISPLAY="$2"
    
    # Wait for waypipe server to create the socket
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
        # Use ls to find sockets, as glob might not work in single-quoted string
        for sock in $(ls -1 "$XDG_RUNTIME_DIR"/wayland-* "$XDG_RUNTIME_DIR"/waypipe-* 2>/dev/null | grep -v waypipe.sock$); do
            if [ -n "$sock" ] && [ -S "$sock" ] 2>/dev/null; then
                SOCKET_FOUND=true
                ACTUAL_SOCKET="$sock"
                SOCKET_NAME=$(basename "$sock")
                echo "✅ Found waypipe compositor socket: $ACTUAL_SOCKET"
                # Update WAYLAND_DISPLAY to match the actual socket name
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
}

# Verify socket is ready
verify_socket_ready() {
    local ACTUAL_SOCKET="$1"
    
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
            echo "   Socket exists, assuming it's ready"
            SOCKET_READY=true
        fi
    fi
    
    if [ "$SOCKET_READY" = false ]; then
        echo "❌ Socket not ready after waiting"
        exit 1
    fi
    
    echo "   Socket is ready"
}

