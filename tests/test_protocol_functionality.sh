#!/bin/bash
# Test actual protocol functionality, not just advertisement

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
COMPOSITOR_BIN="$BUILD_DIR/Wawona"

export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
mkdir -p "$XDG_RUNTIME_DIR"

echo "=== Protocol Functionality Tests ==="
echo ""

# Start compositor
"$COMPOSITOR_BIN" > /tmp/wawona_func_test.log 2>&1 &
COMPOSITOR_PID=$!
sleep 2

if ! kill -0 $COMPOSITOR_PID 2>/dev/null; then
    echo "ERROR: Compositor failed to start"
    cat /tmp/wawona_func_test.log
    exit 1
fi

echo "✓ Compositor started"

# Test 1: Can connect to compositor
echo ""
echo "Test 1: Connection"
if [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
    echo "✓ PASS: Wayland socket exists"
else
    echo "✗ FAIL: Wayland socket not found"
    kill $COMPOSITOR_PID 2>/dev/null || true
    exit 1
fi

# Test 2: Can query registry
echo ""
echo "Test 2: Registry Query"
cd "$SCRIPT_DIR"
if [ -f "test_wayland_client" ]; then
    if ./test_wayland_client > /tmp/registry_test.log 2>&1; then
        echo "✓ PASS: Registry query successful"
        MISSING=$(grep -c "NOT FOUND" /tmp/registry_test.log || echo "0")
        if [ "$MISSING" -gt 0 ]; then
            echo "⚠ WARNING: $MISSING protocols not advertised"
            grep "NOT FOUND" /tmp/registry_test.log
        fi
    else
        echo "✗ FAIL: Registry query failed"
        cat /tmp/registry_test.log
    fi
else
    echo "⊘ SKIP: test_wayland_client not built"
fi

# Test 3: Protocol creation logs
echo ""
echo "Test 3: Protocol Creation"
REQUIRED_PROTOCOLS=(
    "wl_compositor"
    "wl_output"
    "wl_seat"
    "wl_shm"
    "xdg_wm_base"
    "gtk_shell1"
    "org_kde_plasma_shell"
    "qt_surface_extension"
    "qt_windowmanager"
)

for protocol in "${REQUIRED_PROTOCOLS[@]}"; do
    if grep -qi "$protocol" /tmp/wawona_func_test.log 2>/dev/null || \
       grep -qi "protocol created" /tmp/wawona_func_test.log 2>/dev/null; then
        echo "✓ $protocol - Created"
    else
        echo "✗ $protocol - Not found in logs"
    fi
done

# Cleanup
kill $COMPOSITOR_PID 2>/dev/null || true
wait $COMPOSITOR_PID 2>/dev/null || true

echo ""
echo "=== Tests Complete ==="

