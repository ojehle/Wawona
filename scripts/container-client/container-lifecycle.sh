#!/bin/bash
# Container lifecycle management (create/start/stop)

source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/weston.sh"

# Check if container exists
container_exists() {
    set +e
    if $CONTAINER_CMD inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
        set -e
        return 0
    fi
    set -e
    return 1
}

# Stop container if running
stop_container_if_running() {
    if container_exists; then
        set +e
        if $CONTAINER_CMD ps 2>/dev/null | grep -q "$CONTAINER_NAME"; then
            echo "ℹ  Stopping existing container..."
            $CONTAINER_CMD stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
            sleep 1
        fi
        set -e
    fi
}

# Get TTY flag based on terminal availability
get_tty_flag() {
    if [ -t 0 ] && [ -t 1 ]; then
        echo "-it"
    else
        echo "-i"
    fi
}

# Verify container mounts
verify_container_mounts() {
    set +e
    MOUNT_CHECK=$($CONTAINER_CMD exec "$CONTAINER_NAME" test -d /run/user/1000 2>/dev/null; echo $?)
    WAYPIPE_SOCKET_CHECK=$($CONTAINER_CMD exec "$CONTAINER_NAME" test -e /run/user/1000/waypipe.sock 2>/dev/null; echo $?)
    set -e
    if [ "$MOUNT_CHECK" -ne 0 ] || [ "$WAYPIPE_SOCKET_CHECK" -ne 0 ]; then
        return 1
    fi
    return 0
}

# Start existing container and run Weston
start_existing_container() {
    TTY_FLAG=$(get_tty_flag)
    
    echo "ℹ  Starting existing container..."
    $CONTAINER_CMD start "$CONTAINER_NAME" >/dev/null 2>&1 || true
    sleep 1
    
    if ! verify_container_mounts; then
        echo -e "${YELLOW}⚠${NC} Container missing mount or waypipe socket - removing and recreating..."
        $CONTAINER_CMD stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        $CONTAINER_CMD rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
        return 1
    fi
    
    # Execute Weston in existing container
    $CONTAINER_CMD exec $TTY_FLAG \
        -e "XDG_RUNTIME_DIR=/run/user/1000" \
        -e "HOME=/root" \
        "$CONTAINER_NAME" \
        sh -c "$(generate_container_script)"
}

# Create and run new container
create_new_container() {
    TTY_FLAG=$(get_tty_flag)
    
    echo "ℹ  Creating new container (packages will be cached for future runs)..."
    
    # Set socket permissions
    chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chmod 666 "$SOCKET_PATH" 2>/dev/null || true
    
    # Run container with Weston
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶${NC} Starting Weston Container"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "ℹ  Container: $CONTAINER_NAME"
    echo "ℹ  Image: $CONTAINER_IMAGE"
    echo "ℹ  Wayland socket: $SOCKET_PATH -> /run/user/1000/$WAYLAND_DISPLAY"
    echo ""
    
    # Ensure mount source directory exists and has the socket
    if [ ! -d "$COCOMA_XDG_RUNTIME_DIR" ]; then
        echo -e "${RED}✗${NC} Mount source directory does not exist: $COCOMA_XDG_RUNTIME_DIR"
        exit 1
    fi
    
    # Use absolute path for mount source (required by some container systems)
    MOUNT_SOURCE=$(cd "$COCOMA_XDG_RUNTIME_DIR" && pwd)
    
    echo "ℹ  Mount source: $MOUNT_SOURCE"
    echo "ℹ  Mount target: /host-wayland-runtime"
    echo "ℹ  Socket should be at: $MOUNT_SOURCE/waypipe.sock"
    
    # Export TCP proxy configuration for container
    # macOS Containerization.framework doesn't support --network host
    # Use default networking and connect to host via gateway IP
    export SOCAT_TCP_PORT="$SOCAT_TCP_PORT"
    
    # Pass WAYPIPE_HOST_IP if it was determined on host side
    CONTAINER_ENV_ARGS="-e XDG_RUNTIME_DIR=/run/user/1000 -e HOME=/root -e SOCAT_TCP_PORT=$SOCAT_TCP_PORT"
    if [ -n "$WAYPIPE_HOST_IP" ]; then
        CONTAINER_ENV_ARGS="$CONTAINER_ENV_ARGS -e WAYPIPE_HOST_IP=$WAYPIPE_HOST_IP"
    fi
    
    # macOS Containerization.framework uses default bridge networking
    # Container can access host via gateway IP (determined inside container or passed from host)
    # No need for --network host or port mapping
    
    $CONTAINER_CMD run --name "$CONTAINER_NAME" $TTY_FLAG \
        --mount "type=bind,source=$MOUNT_SOURCE,target=/host-wayland-runtime" \
        --mount "type=tmpfs,target=/run/user/1000" \
        $CONTAINER_ENV_ARGS \
        "$CONTAINER_IMAGE" \
        sh -c "$(generate_container_script)" || {
        # If container run failed because container already exists, use existing container
        if container_exists; then
            echo -e "${YELLOW}ℹ${NC} Container already exists, using existing container..."
            $CONTAINER_CMD start "$CONTAINER_NAME" >/dev/null 2>&1 || true
            sleep 1
            start_existing_container
        else
            echo -e "${RED}✗${NC} Failed to create/run container"
            exit 1
        fi
    }
}

# Manage container lifecycle
manage_container() {
    if container_exists; then
        if start_existing_container; then
            return 0
        fi
        # If start failed, fall through to create new container
    fi
    
    create_new_container
}

