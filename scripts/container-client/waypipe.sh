#!/bin/bash
# Waypipe setup and management functions

source "$(dirname "$0")/config.sh"

# Check and build waypipe if needed
check_waypipe() {
    if ! command -v waypipe >/dev/null 2>&1; then
        echo -e "${YELLOW}ℹ${NC} waypipe not found - checking if we can build it..."
        if [ -d "waypipe" ] && command -v cargo >/dev/null 2>&1 && command -v meson >/dev/null 2>&1; then
            echo -e "${YELLOW}ℹ${NC} Building waypipe..."
            cd waypipe
            cargo fetch --locked >/dev/null 2>&1 || true
            if [ ! -d "build" ]; then
                meson setup build >/dev/null 2>&1 || {
                    echo -e "${RED}✗${NC} Failed to build waypipe"
                    echo -e "${YELLOW}ℹ${NC} Install waypipe: brew install waypipe"
                    exit 1
                }
            fi
            meson compile -C build >/dev/null 2>&1 || {
                echo -e "${RED}✗${NC} Failed to compile waypipe"
                exit 1
            }
            export PATH="$PWD/build:$PATH"
            cd ..
            echo -e "${GREEN}✓${NC} waypipe built"
        else
            echo -e "${RED}✗${NC} waypipe not found"
            echo -e "${YELLOW}ℹ${NC} Install waypipe: brew install waypipe"
            echo -e "${YELLOW}ℹ${NC} Or build from source in waypipe/ directory"
            exit 1
        fi
    fi
}

# Set up waypipe proxy directory
setup_waypipe_directory() {
    if [ ! -d "${HOME}/.wayland-runtime" ]; then
        mkdir -p "${HOME}/.wayland-runtime"
    fi
}

# Check for socat (required for TCP proxy workaround)
check_socat() {
    if ! command -v socat >/dev/null 2>&1; then
        echo -e "${YELLOW}ℹ${NC} socat not found - installing via Homebrew..."
        if command -v brew >/dev/null 2>&1; then
            brew install socat || {
                echo -e "${RED}✗${NC} Failed to install socat"
                echo -e "${YELLOW}ℹ${NC} Install manually: brew install socat"
                exit 1
            }
        else
            echo -e "${RED}✗${NC} socat not found and Homebrew not available"
            echo -e "${YELLOW}ℹ${NC} Install socat: brew install socat"
            exit 1
        fi
    fi
}

# Start socat TCP proxy (workaround for macOS Containerization.framework limitation)
start_socat_proxy() {
    check_socat
    
    # Kill any existing socat processes on this port
    lsof -ti:${SOCAT_TCP_PORT} | xargs kill -9 2>/dev/null || true
    sleep 0.5
    
    echo -e "${YELLOW}ℹ${NC} Starting socat TCP proxy (port ${SOCAT_TCP_PORT})..."
    echo -e "${YELLOW}ℹ${NC} This bypasses macOS Containerization.framework Unix socket limitations"
    
    # Start socat: TCP listener -> Unix socket
    # Listen on all interfaces (0.0.0.0) so container can connect via gateway IP
    # Use fork and reuseaddr for connection handling
    socat TCP-LISTEN:${SOCAT_TCP_PORT},fork,reuseaddr,bind=0.0.0.0 UNIX-CONNECT:"$WAYPIPE_SOCKET" >/tmp/socat-proxy.log 2>&1 &
    SOCAT_PID=$!
    sleep 1
    
    # Verify socat started
    if ! kill -0 $SOCAT_PID 2>/dev/null; then
        echo -e "${RED}✗${NC} Failed to start socat proxy"
        echo -e "${YELLOW}ℹ${NC} Check logs: /tmp/socat-proxy.log"
        cat /tmp/socat-proxy.log 2>/dev/null | tail -10
        exit 1
    fi
    
    # Verify TCP port is listening
    if ! lsof -i:${SOCAT_TCP_PORT} >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Socat TCP port ${SOCAT_TCP_PORT} not listening"
        kill $SOCAT_PID 2>/dev/null || true
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Socat TCP proxy running (PID: $SOCAT_PID, port: ${SOCAT_TCP_PORT})"
    export SOCAT_PID
}

# Start waypipe client
start_waypipe_client() {
    # Kill any existing waypipe client processes
    pkill -f "waypipe.*client.*${WAYPIPE_SOCKET}" 2>/dev/null || true
    sleep 0.5

    # Remove existing waypipe socket if it exists
    if [ -e "$WAYPIPE_SOCKET" ]; then
        rm -f "$WAYPIPE_SOCKET"
    fi

    # Start waypipe client on host (connects to compositor)
    echo -e "${YELLOW}ℹ${NC} Starting waypipe client to proxy compositor connection..."
    WAYLAND_DISPLAY_ORIG="$WAYLAND_DISPLAY"
    XDG_RUNTIME_DIR_ORIG="$XDG_RUNTIME_DIR"
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        waypipe --socket "$WAYPIPE_SOCKET" client >/tmp/waypipe-client.log 2>&1 &
    WAYPIPE_CLIENT_PID=$!
    sleep 2

    # Verify waypipe client started
    if ! kill -0 $WAYPIPE_CLIENT_PID 2>/dev/null; then
        echo -e "${RED}✗${NC} Failed to start waypipe client"
        echo -e "${YELLOW}ℹ${NC} Check logs: /tmp/waypipe-client.log"
        cat /tmp/waypipe-client.log 2>/dev/null | tail -10
        exit 1
    fi

    # Verify waypipe socket was created
    if [ ! -S "$WAYPIPE_SOCKET" ]; then
        echo -e "${RED}✗${NC} Waypipe socket not created"
        kill $WAYPIPE_CLIENT_PID 2>/dev/null || true
        cat /tmp/waypipe-client.log 2>/dev/null | tail -10
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Waypipe client running (PID: $WAYPIPE_CLIENT_PID)"
    echo -e "${GREEN}✓${NC} Waypipe socket: $WAYPIPE_SOCKET"
    
    # Start socat TCP proxy to bypass macOS Containerization.framework limitation
    start_socat_proxy
    
    export WAYPIPE_CLIENT_PID
}

# Cleanup waypipe and socat
cleanup_waypipe() {
    if [ -n "$SOCAT_PID" ] && kill -0 $SOCAT_PID 2>/dev/null; then
        kill $SOCAT_PID 2>/dev/null || true
    fi
    # Kill any socat processes on our port
    lsof -ti:${SOCAT_TCP_PORT} | xargs kill -9 2>/dev/null || true
    if [ -n "$WAYPIPE_CLIENT_PID" ] && kill -0 $WAYPIPE_CLIENT_PID 2>/dev/null; then
        kill $WAYPIPE_CLIENT_PID 2>/dev/null || true
    fi
    if [ -e "$WAYPIPE_SOCKET" ]; then
        rm -f "$WAYPIPE_SOCKET"
    fi
}

# Initialize waypipe setup
init_waypipe() {
    check_waypipe
    setup_waypipe_directory
    start_waypipe_client
    trap cleanup_waypipe EXIT
}

