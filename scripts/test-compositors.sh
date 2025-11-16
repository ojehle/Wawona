#!/bin/bash
# Wawona Compositor Testing Script
# Tests various nested compositors with Wawona

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

# Start Wawona compositor
start_wawona() {
    echo -e "${BLUE}Starting Wawona compositor...${NC}"
    "$COMPOSITOR_BIN" > /tmp/wawona_compositor_test.log 2>&1 &
    WAWONA_PID=$!
    sleep 2
    
    if ! kill -0 $WAWONA_PID 2>/dev/null; then
        echo -e "${RED}✗ Wawona failed to start${NC}"
        cat /tmp/wawona_compositor_test.log
        exit 1
    fi
    
    echo -e "${GREEN}✓ Wawona started (PID: $WAWONA_PID)${NC}"
    echo $WAWONA_PID
}

# Test Weston (via colima)
test_weston() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing: Weston (via Colima)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo -e "${YELLOW}ℹ Run: make colima-client${NC}"
        echo -e "${YELLOW}ℹ This will start Weston in a Docker container${NC}"
        return 0
    else
        echo -e "${YELLOW}⊘ Docker not available - skipping${NC}"
        return 1
    fi
}

# Test Sway (wlroots-based)
test_sway() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing: Sway (wlroots-based)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if command -v sway &> /dev/null; then
        echo -e "${YELLOW}ℹ Sway detected${NC}"
        echo -e "${YELLOW}ℹ Note: Sway requires DMA-BUF support (not yet implemented)${NC}"
        echo -e "${YELLOW}ℹ Run: WAYLAND_DISPLAY=wayland-0 sway${NC}"
        return 0
    else
        echo -e "${YELLOW}⊘ Sway not found - skipping${NC}"
        return 1
    fi
}

# Test GNOME (Mutter)
test_gnome() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing: GNOME (Mutter)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if command -v mutter &> /dev/null || command -v gnome-session &> /dev/null; then
        echo -e "${YELLOW}ℹ GNOME/Mutter detected${NC}"
        echo -e "${YELLOW}ℹ Note: Requires full protocol support${NC}"
        echo -e "${YELLOW}ℹ Run: WAYLAND_DISPLAY=wayland-0 mutter --nested${NC}"
        return 0
    else
        echo -e "${YELLOW}⊘ GNOME/Mutter not found - skipping${NC}"
        return 1
    fi
}

# Test KDE Plasma (KWin)
test_kde() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing: KDE Plasma (KWin)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if command -v kwin_wayland &> /dev/null || command -v kwin &> /dev/null; then
        echo -e "${YELLOW}ℹ KDE/KWin detected${NC}"
        echo -e "${YELLOW}ℹ Note: Requires full protocol support${NC}"
        echo -e "${YELLOW}ℹ Run: WAYLAND_DISPLAY=wayland-0 kwin_wayland --wayland${NC}"
        return 0
    else
        echo -e "${YELLOW}⊘ KDE/KWin not found - skipping${NC}"
        return 1
    fi
}

# Main
main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Wawona Nested Compositor Test Suite${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    WAWONA_PID=$(start_wawona)
    trap "kill $WAWONA_PID 2>/dev/null || true" EXIT
    
    PASSED=0
    FAILED=0
    SKIPPED=0
    
    test_weston && ((PASSED++)) || ((SKIPPED++))
    test_sway && ((PASSED++)) || ((SKIPPED++))
    test_gnome && ((PASSED++)) || ((SKIPPED++))
    test_kde && ((PASSED++)) || ((SKIPPED++))
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Available:${NC} $PASSED"
    echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
    echo ""
    
    kill $WAWONA_PID 2>/dev/null || true
    wait $WAWONA_PID 2>/dev/null || true
    trap - EXIT
}

main "$@"

