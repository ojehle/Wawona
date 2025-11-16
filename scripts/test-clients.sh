#!/bin/bash
# Wawona Client Testing Script
# Tests various Wayland clients and compositors with Wawona

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
COMPOSITOR_BIN="$BUILD_DIR/Wawona"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
mkdir -p "$XDG_RUNTIME_DIR"

# Start compositor in background
start_compositor() {
    echo -e "${BLUE}Starting Wawona compositor...${NC}"
    "$COMPOSITOR_BIN" > /tmp/wawona_test.log 2>&1 &
    COMPOSITOR_PID=$!
    sleep 2
    
    if ! kill -0 $COMPOSITOR_PID 2>/dev/null; then
        echo -e "${RED}✗ Compositor failed to start${NC}"
        cat /tmp/wawona_test.log
        exit 1
    fi
    
    echo -e "${GREEN}✓ Compositor started (PID: $COMPOSITOR_PID)${NC}"
    echo $COMPOSITOR_PID
}

# Stop compositor
stop_compositor() {
    local pid=$1
    if [ -n "$pid" ] && kill -0 $pid 2>/dev/null; then
        kill $pid 2>/dev/null || true
        wait $pid 2>/dev/null || true
        echo -e "${GREEN}✓ Compositor stopped${NC}"
    fi
}

# Test a client
test_client() {
    local name=$1
    shift
    local cmd="$@"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing: $name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Command: $cmd"
    
    if timeout 10 bash -c "$cmd" > /tmp/client_test_${name}.log 2>&1; then
        echo -e "${GREEN}✓ $name - Test passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $name - Test failed${NC}"
        cat /tmp/client_test_${name}.log | tail -20
        return 1
    fi
}

# Test compositor
test_compositor() {
    local name=$1
    shift
    local cmd="$@"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing Compositor: $name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Command: $cmd"
    
    # Compositors run longer, use longer timeout
    if timeout 30 bash -c "$cmd" > /tmp/compositor_test_${name}.log 2>&1; then
        echo -e "${GREEN}✓ $name - Test passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $name - Test failed${NC}"
        cat /tmp/compositor_test_${name}.log | tail -20
        return 1
    fi
}

# Main test suite
main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Wawona Client & Compositor Test Suite${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    COMPOSITOR_PID=$(start_compositor)
    trap "stop_compositor $COMPOSITOR_PID" EXIT
    
    PASSED=0
    FAILED=0
    SKIPPED=0
    
    # Test simple clients (if available)
    echo ""
    echo -e "${YELLOW}Testing Simple Wayland Clients${NC}"
    
    if command -v wayland-info &> /dev/null; then
        test_client "wayland-info" "wayland-info" && ((PASSED++)) || ((FAILED++))
    else
        echo -e "${YELLOW}⊘ wayland-info not found - skipping${NC}"
        ((SKIPPED++))
    fi
    
    # Test terminal emulators
    if command -v foot &> /dev/null; then
        test_client "foot" "foot --version" && ((PASSED++)) || ((FAILED++))
    else
        echo -e "${YELLOW}⊘ foot not found - skipping${NC}"
        ((SKIPPED++))
    fi
    
    # Test compositors (via colima if available)
    echo ""
    echo -e "${YELLOW}Testing Nested Compositors${NC}"
    
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo -e "${YELLOW}Docker available - can test nested compositors${NC}"
        echo -e "${YELLOW}Run 'make colima-client' to test Weston${NC}"
    else
        echo -e "${YELLOW}⊘ Docker not available - skipping compositor tests${NC}"
        ((SKIPPED++))
    fi
    
    # Summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Passed:${NC}  $PASSED"
    echo -e "${RED}Failed:${NC}  $FAILED"
    echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
    echo ""
    
    stop_compositor $COMPOSITOR_PID
    trap - EXIT
    
    if [ $FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"

