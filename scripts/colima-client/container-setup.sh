#!/bin/bash
# Container image and container management

# Check if container image exists, pull if needed
ensure_container_image() {
    echo -e "${YELLOW}ℹ${NC} Checking for container image..."
    if ! docker image inspect "$CONTAINER_IMAGE" >/dev/null 2>&1; then
        echo -e "${YELLOW}ℹ${NC} Container image not found - pulling..."
        docker pull "$CONTAINER_IMAGE" || {
            echo -e "${RED}✗${NC} Failed to pull container image"
            exit 1
        }
        echo -e "${GREEN}✓${NC} Container image pulled"
    else
        echo -e "${GREEN}✓${NC} Container image already available"
    fi
    echo ""
}

# Check if container exists
check_container_exists() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

# Stop existing container if running
stop_container_if_running() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}ℹ${NC} Stopping existing container..."
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        sleep 1
    fi
}

# Check if container mount and socket are accessible
check_container_mount() {
    set +e
    MOUNT_CHECK=$(docker exec "$CONTAINER_NAME" test -d /run/user/1000 2>/dev/null; echo $?)
    SOCKET_CHECK=$(docker exec "$CONTAINER_NAME" test -e /run/user/1000/$WAYLAND_DISPLAY 2>/dev/null; echo $?)
    set -e
    
    if [ "$MOUNT_CHECK" -ne 0 ] || [ "$SOCKET_CHECK" -ne 0 ]; then
        return 1
    else
        return 0
    fi
}

# Remove container if mount is invalid
remove_container_if_needed() {
    if check_container_exists; then
        if ! check_container_mount; then
            echo -e "${YELLOW}⚠${NC} Container missing mount or socket - removing and recreating..."
            docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
            docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
            return 1
        fi
    fi
    return 0
}

# Start existing container
start_existing_container() {
    echo -e "${YELLOW}ℹ${NC}  Starting existing container..."
    docker start "$CONTAINER_NAME" >/dev/null 2>&1 || true
    sleep 1
}

# Ensure runtime directories exist
ensure_runtime_directories() {
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        echo -e "${YELLOW}ℹ${NC} Creating runtime directory: $XDG_RUNTIME_DIR"
        mkdir -p "$XDG_RUNTIME_DIR" || {
            echo -e "${RED}✗${NC} Failed to create directory: $XDG_RUNTIME_DIR"
            exit 1
        }
    fi
    # Fix permissions on host side (will be inherited by bind mount)
    chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    
    if [ ! -d "$COCOMA_XDG_RUNTIME_DIR" ]; then
        echo -e "${YELLOW}ℹ${NC} Creating Colima-compatible directory: $COCOMA_XDG_RUNTIME_DIR"
        mkdir -p "$COCOMA_XDG_RUNTIME_DIR" || {
            echo -e "${RED}✗${NC} Failed to create directory: $COCOMA_XDG_RUNTIME_DIR"
            exit 1
        }
    fi
    # CRITICAL: Fix permissions on host side BEFORE bind mounting
    # This ensures the container sees 0700 permissions
    chmod 0700 "$COCOMA_XDG_RUNTIME_DIR" 2>/dev/null || true
}

# Get TTY flag for docker commands
get_tty_flag() {
    if [ -t 0 ] && [ -t 1 ]; then
        echo "-it"
    else
        echo "-i"
    fi
}

