#!/bin/bash
# Main container client script orchestrator

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
source "$SCRIPT_DIR/config.sh"

# Source modules
source "$SCRIPT_DIR/waypipe.sh"
source "$SCRIPT_DIR/container-tool.sh"
source "$SCRIPT_DIR/container-system.sh"
source "$SCRIPT_DIR/container-lifecycle.sh"

# Main execution
main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶${NC} Container Client Setup"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check compositor socket
    echo -e "${YELLOW}ℹ${NC} Checking compositor socket: ${GREEN}$SOCKET_PATH${NC}"
    if [ ! -S "$SOCKET_PATH" ] && [ ! -e "$SOCKET_PATH" ]; then
        echo -e "${RED}✗${NC} Compositor socket not found: ${RED}$SOCKET_PATH${NC}"
        echo ""
        echo -e "${YELLOW}ℹ${NC} Start the compositor first: ${GREEN}make compositor${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Compositor socket found"
    echo ""

    # Initialize waypipe
    init_waypipe
    echo ""

    # Verify waypipe socket exists and is accessible before proceeding
    if [ ! -S "$WAYPIPE_SOCKET" ]; then
        echo -e "${RED}✗${NC} Waypipe socket not found: ${RED}$WAYPIPE_SOCKET${NC}"
        echo -e "${YELLOW}ℹ${NC} Waypipe client should have created this socket"
        exit 1
    fi
    
    # Verify mount directory exists
    if [ ! -d "$COCOMA_XDG_RUNTIME_DIR" ]; then
        echo -e "${RED}✗${NC} Wayland runtime directory not found: ${RED}$COCOMA_XDG_RUNTIME_DIR${NC}"
        exit 1
    fi
    
    # Determine host IP that container can reach
    # For macOS Containerization.framework, containers typically see host as gateway
    # Try to get the IP that containers will use to reach this host
    HOST_IP_FOR_CONTAINER=""
    
    # Method 1: Check if we're on a known network (Docker Desktop, Colima, etc.)
    # These typically use 192.168.65.1 or similar
    if [ -z "$HOST_IP_FOR_CONTAINER" ]; then
        # Try common gateway IPs - test if socat is reachable
        for test_ip in 192.168.65.1 172.17.0.1 10.0.2.2; do
            if nc -z -w 1 "$test_ip" "$SOCAT_TCP_PORT" 2>/dev/null; then
                HOST_IP_FOR_CONTAINER="$test_ip"
                break
            fi
        done
    fi
    
    # Method 2: For macOS Containerization.framework, containers typically see host at 192.168.64.1
    # This is the default gateway IP for Containerization.framework bridge networks
    if [ -z "$HOST_IP_FOR_CONTAINER" ]; then
        # Try the common Containerization.framework gateway IP first
        if nc -z -w 1 192.168.64.1 "$SOCAT_TCP_PORT" 2>/dev/null; then
            HOST_IP_FOR_CONTAINER="192.168.64.1"
            echo -e "${GREEN}✓${NC} Found Containerization.framework gateway: $HOST_IP_FOR_CONTAINER"
        fi
    fi
    
    # Method 3: Use host's primary interface IP (fallback)
    if [ -z "$HOST_IP_FOR_CONTAINER" ]; then
        PRIMARY_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
        if [ -n "$PRIMARY_IP" ]; then
            # For bridge networks, host is usually at .1 of the subnet
            # Extract subnet and use .1
            SUBNET=$(echo "$PRIMARY_IP" | cut -d. -f1-3)
            HOST_IP_FOR_CONTAINER="${SUBNET}.1"
            echo -e "${YELLOW}ℹ${NC} Estimated host IP for container: $HOST_IP_FOR_CONTAINER (from $PRIMARY_IP)"
        fi
    fi
    
    # Export for container to use
    if [ -n "$HOST_IP_FOR_CONTAINER" ]; then
        export WAYPIPE_HOST_IP="$HOST_IP_FOR_CONTAINER"
        echo -e "${GREEN}✓${NC} Host IP for container: $WAYPIPE_HOST_IP"
    else
        echo -e "${YELLOW}⚠${NC} Could not determine host IP - container will auto-detect"
    fi
    
    echo -e "${GREEN}✓${NC} Waypipe socket verified: $WAYPIPE_SOCKET"
    echo -e "${GREEN}✓${NC} Mount directory verified: $COCOMA_XDG_RUNTIME_DIR"
    echo ""

    # Find or install container tool
    find_or_install_container_tool

    # Ensure container system is running
    ensure_container_system_running

    # Ensure container image is available
    ensure_container_image

    # Stop existing container if running
    stop_container_if_running

    # Manage container lifecycle (create/start and run Weston)
    manage_container
}

# Run main function
main "$@"

