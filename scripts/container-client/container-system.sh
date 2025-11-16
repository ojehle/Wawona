#!/bin/bash
# Container system management (start/stop/status)

source "$(dirname "$0")/config.sh"

# Check if container system is working
check_system_status() {
    SYSTEM_WORKING=false
    
    # Test if apiserver is responding (system status is faster and more reliable than images)
    set +e  # Temporarily disable exit on error for this check
    ($CONTAINER_CMD system status >/dev/null 2>&1) &
    TEST_PID=$!
    sleep 2
    if kill -0 $TEST_PID 2>/dev/null; then
        # Command is hanging - apiserver not responding
        kill $TEST_PID 2>/dev/null || true
        wait $TEST_PID 2>/dev/null || true
    else
        # Command completed - check exit code
        wait $TEST_PID 2>/dev/null
        TEST_EXIT=$?
        if [ $TEST_EXIT -eq 0 ]; then
            SYSTEM_WORKING=true
        fi
    fi
    set -e  # Re-enable exit on error
    
    echo "$SYSTEM_WORKING"
}

# Start container system if not running
ensure_container_system_running() {
    SYSTEM_WORKING=$(check_system_status)
    
    if [ "$SYSTEM_WORKING" = false ]; then
        echo -e "${YELLOW}ℹ${NC} Container system not running or apiserver not responding"
        echo -e "${YELLOW}ℹ${NC} Starting container system services..."
        echo -e "${YELLOW}ℹ${NC} Running: ${GREEN}$CONTAINER_CMD system start --enable-kernel-install${NC}"
        echo ""
        if ! $CONTAINER_CMD system start --enable-kernel-install; then
            echo -e "${RED}✗${NC} Failed to start container system"
            echo -e "${YELLOW}ℹ${NC} Check logs: ${GREEN}$CONTAINER_CMD system logs${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} Container system started"
        
        # Wait for services to fully initialize
        wait_for_system_ready
    else
        echo -e "${GREEN}✓${NC} Container system already running"
    fi
    echo ""
}

# Wait for container system to be ready
wait_for_system_ready() {
    echo -e "${YELLOW}ℹ${NC} Waiting for services to initialize (this may take a few minutes if kernel was installed)..."
    
    # Retry verification with exponential backoff (up to 2 minutes total)
    MAX_RETRIES=12
    RETRY_DELAY=5
    RETRY_COUNT=0
    PLUGINS_READY=false
    
    set +e  # Temporarily disable exit on error for retry loop
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Test if system is ready (use system status - faster and more reliable)
        # Also verify plugins directory exists
        ($CONTAINER_CMD system status >/dev/null 2>&1) &
        TEST_PID=$!
        sleep 2
        if kill -0 $TEST_PID 2>/dev/null; then
            # Command is hanging - still not ready
            kill $TEST_PID 2>/dev/null || true
            wait $TEST_PID 2>/dev/null || true
        else
            # Command completed - check exit code
            wait $TEST_PID 2>/dev/null
            TEST_EXIT=$?
            # Also verify plugins directory exists
            if [ $TEST_EXIT -eq 0 ] && [ -d "/usr/local/libexec/container/plugins" ]; then
                PLUGINS_READY=true
                break
            fi
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}ℹ${NC} Services still initializing... (attempt $RETRY_COUNT/$MAX_RETRIES)"
            sleep $RETRY_DELAY
            # Increase delay slightly for later retries
            if [ $RETRY_COUNT -gt 6 ]; then
                RETRY_DELAY=10
            fi
        fi
    done
    set -e  # Re-enable exit on error
    
    if [ "$PLUGINS_READY" = false ]; then
        echo -e "${RED}✗${NC} Container system started but plugins still unavailable after ${MAX_RETRIES} attempts"
        echo -e "${YELLOW}ℹ${NC} Check logs: ${GREEN}$CONTAINER_CMD system logs${NC}"
        echo -e "${YELLOW}ℹ${NC} Verify plugins exist in:"
        echo "   - /usr/local/libexec/container-plugins/"
        echo "   - /usr/local/libexec/container/plugins/"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Container system ready (plugins available)"
}

# Ensure container image is available
ensure_container_image() {
    echo -e "${YELLOW}ℹ${NC} Checking for container image..."
    set +e  # Temporarily disable exit on error for image check
    IMAGE_EXISTS=false
    if $CONTAINER_CMD image list 2>/dev/null | grep -q "$CONTAINER_IMAGE" 2>/dev/null; then
        IMAGE_EXISTS=true
    fi
    set -e  # Re-enable exit on error

    if [ "$IMAGE_EXISTS" = false ]; then
        echo -e "${YELLOW}ℹ${NC} Container image not found - pulling..."
        if ! $CONTAINER_CMD image pull "$CONTAINER_IMAGE"; then
            echo -e "${RED}✗${NC} Failed to pull container image"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} Container image pulled"
    else
        echo -e "${GREEN}✓${NC} Container image already available"
    fi
    echo ""
}

