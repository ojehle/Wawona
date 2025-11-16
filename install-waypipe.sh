#!/bin/bash

# CALayerWayland - Waypipe Installation Script
# Automates building waypipe from source on macOS

set -o errexit
set -o pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Log file setup
LOG_DIR="${LOG_DIR:-.}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/waypipe-install.log}"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log and display
log_and_echo() {
    echo "$@" | tee -a "$LOG_FILE"
}

# Function to log errors
log_error() {
    echo -e "${RED}$@${NC}" | tee -a "$LOG_FILE"
}

# Function to log info
log_info() {
    echo -e "${BLUE}$@${NC}" | tee -a "$LOG_FILE"
}

# Function to log success
log_success() {
    echo -e "${GREEN}$@${NC}" | tee -a "$LOG_FILE"
}

# Function to log warning
log_warning() {
    echo -e "${YELLOW}$@${NC}" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
    local line_num=$1
    local exit_code=$?
    log_error ""
    log_error "❌ Installation failed at line $line_num"
    log_error "   Exit code: $exit_code"
    log_error ""
    log_error "📋 Full log saved to: $LOG_FILE"
    exit $exit_code
}

# Trap errors
trap 'error_exit $LINENO' ERR

# Initialize log file
{
    echo "=========================================="
    echo "Waypipe Installation Log"
    echo "Started: $(date)"
    echo "=========================================="
    echo ""
} > "$LOG_FILE"

log_info "🔧 CALayerWayland - Waypipe Installation Script"
log_and_echo "=========================================="
log_and_echo ""

# Default installation prefix
if [[ "$(uname -m)" == "arm64" ]] && [ -d "/opt/homebrew" ]; then
    DEFAULT_PREFIX="/opt/homebrew"
else
    DEFAULT_PREFIX="/usr/local"
fi
INSTALL_PREFIX="${INSTALL_PREFIX:-$DEFAULT_PREFIX}"
WAYPIPE_REPO="${WAYPIPE_REPO:-https://gitlab.freedesktop.org/mstoeckl/waypipe.git}"
BUILD_DIR="${BUILD_DIR:-./waypipe-build}"

log_info "Installation prefix: ${INSTALL_PREFIX}"
log_and_echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    log_warning "⚠️  Warning: This script is designed for macOS"
    log_and_echo "   Continuing anyway..."
    log_and_echo ""
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for Homebrew
if ! command_exists brew; then
    log_error "❌ Homebrew not found!"
    exit 1
fi

log_success "✓ Homebrew found"
log_and_echo ""

# Check and install build dependencies
log_info "📦 Checking build dependencies..."
log_and_echo ""

MISSING_DEPS=()

# Check meson
if ! command_exists meson; then
    MISSING_DEPS+=("meson")
else
    log_success "✓ meson: $(meson --version 2>/dev/null | head -n1 || echo 'found')"
fi

# Check ninja
if ! command_exists ninja; then
    MISSING_DEPS+=("ninja")
else
    log_success "✓ ninja: $(ninja --version 2>/dev/null || echo 'found')"
fi

# Check pkg-config
if ! command_exists pkg-config; then
    MISSING_DEPS+=("pkg-config")
else
    log_success "✓ pkg-config: $(pkg-config --version)"
fi

# Check wayland (required dependency)
if ! pkg-config --exists wayland-client wayland-server 2>/dev/null; then
    log_error "❌ wayland-client and wayland-server not found!"
    log_and_echo "   Install wayland first: make wayland"
    exit 1
else
    log_success "✓ wayland-client: $(pkg-config --modversion wayland-client)"
    log_success "✓ wayland-server: $(pkg-config --modversion wayland-server)"
fi

log_and_echo ""

# Install missing dependencies
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log_info "📥 Installing missing dependencies via Homebrew..."
    log_and_echo ""
    brew install "${MISSING_DEPS[@]}" 2>&1 | tee -a "$LOG_FILE"
    log_and_echo ""
    log_success "✓ Dependencies installed"
    log_and_echo ""
else
    log_success "✓ All dependencies already installed"
    log_and_echo ""
fi

# Check if waypipe is already installed
if command_exists waypipe; then
    log_success "✓ waypipe appears to be already installed: $(which waypipe)"
    log_and_echo "   Version: $(waypipe --version 2>/dev/null || echo 'unknown')"
    log_and_echo ""
    if [ -t 0 ]; then
        read -p "Do you want to rebuild and reinstall? (y/N): " -n 1 -r
        log_and_echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_success "✓ Skipping installation. Waypipe is already installed."
            exit 0
        fi
    fi
fi

# Clone waypipe repository
log_info "📥 Cloning waypipe repository..."
log_and_echo ""

if [ -d "waypipe" ]; then
    log_warning "⚠ waypipe directory already exists"
    if [ -t 0 ]; then
        read -p "Remove existing directory and re-clone? (y/N): " -n 1 -r
        log_and_echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_and_echo "Removing existing waypipe directory..."
            rm -rf waypipe
        else
            log_success "✓ Using existing waypipe directory (preserving local changes)"
            SKIP_CLONE=1
        fi
    else
        log_success "✓ Using existing waypipe directory (non-interactive mode, preserving local changes)"
        SKIP_CLONE=1
    fi
fi

if [ -z "$SKIP_CLONE" ]; then
    GIT_TERMINAL_PROMPT=0 git clone "$WAYPIPE_REPO" waypipe 2>&1 | tee -a "$LOG_FILE" || {
        log_error "❌ Failed to clone waypipe repository"
        log_error "   Try manually: git clone $WAYPIPE_REPO waypipe"
        exit 1
    }
    log_success "✓ Repository cloned"
    log_and_echo ""
fi

# Enter waypipe directory
cd waypipe

# Apply macOS-specific patches
log_info "🔧 Applying macOS compatibility patches..."
log_and_echo ""

# Fix meson.build bug: gbmfallback should only be added if libgbm is found
if grep -q "if bindgen.found() and libzstd.found()" meson.build; then
    log_info "Patching meson.build to fix gbmfallback feature detection..."
    sed -i.bak 's/if bindgen.found() and libzstd.found()/if bindgen.found() and libgbm.found()/g' meson.build
    sed -i.bak 's/has_zstd = true/has_gbm = true/g' meson.build
    log_success "✓ meson.build patched"
else
    log_info "✓ meson.build already patched or doesn't need patching"
fi

# Setup build directory
log_info "🔨 Setting up build directory..."
log_and_echo ""

# Remove existing build directory if it exists
if [ -d "build" ]; then
    log_and_echo "Removing existing build directory..."
    rm -rf build
fi

# Configure build
log_and_echo "Running: meson setup build --prefix=$INSTALL_PREFIX"
log_and_echo ""

# Set PKG_CONFIG_PATH for meson to find dependencies
export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# Ensure cargo is in PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Try to configure - may need macOS-specific patches
# Check if cargo and objcopy are available for Rust build
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/binutils/bin:$HOME/.cargo/bin:$PATH"

# Try Rust build first (preferred)
# Note: We disable gbm/dmabuf/video on macOS because:
# - These are Linux-specific APIs (DRM, GBM, Vulkan DMABUF) not available on macOS
# - The macOS compositor only supports SHM (shared memory) buffers anyway
# - waypipe will automatically fall back to SHM when forwarding to macOS compositor
# - The VM-side waypipe (installed via dnf) will have these features enabled
if command_exists cargo && (command_exists objcopy || command_exists gobjcopy); then
    log_info "Building waypipe with Rust support..."
    log_info "Note: dmabuf/video disabled (Linux-specific, macOS compositor uses SHM only)"
    meson setup build \
        --prefix="$INSTALL_PREFIX" \
        -Dbuild_rs=true \
        -Dwith_gbm=disabled \
        -Dwith_dmabuf=disabled \
        -Dwith_systemtap=false 2>&1 | tee -a "$LOG_FILE" || {
        log_warning "⚠ Rust build failed, trying C-only build..."
        rm -rf build
        meson setup build \
            --prefix="$INSTALL_PREFIX" \
            -Dbuild_rs=false \
            -Dwith_gbm=disabled \
            -Dwith_dmabuf=disabled \
            -Dbuild_c=true \
            -Dwith_systemtap=false 2>&1 | tee -a "$LOG_FILE" || {
            log_error "❌ Failed to configure waypipe (both Rust and C builds failed)"
            log_error "   Check log for details: $LOG_FILE"
            exit 1
        }
    }
else
    log_info "Building waypipe C-only version (Rust dependencies not available)..."
    meson setup build \
        --prefix="$INSTALL_PREFIX" \
        -Dbuild_rs=false \
        -Dwith_gbm=disabled \
        -Dwith_dmabuf=disabled \
        -Dbuild_c=true \
        -Dwith_systemtap=false 2>&1 | tee -a "$LOG_FILE" || {
        log_error "❌ Failed to configure waypipe"
        log_error "   Check log for details: $LOG_FILE"
        exit 1
    }
fi

log_success "✓ Build configured"
log_and_echo ""

# Build waypipe
log_info "🔨 Building waypipe..."
log_and_echo "   This may take a few minutes..."
log_and_echo ""

export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

meson compile -C build 2>&1 | tee -a "$LOG_FILE" || {
    log_warning "⚠ Full build failed, trying to build just waypipe binary..."
    meson compile -C build waypipe 2>&1 | tee -a "$LOG_FILE" || {
        log_error "❌ Failed to build waypipe"
        exit 1
    }
}

log_and_echo ""
log_success "✓ Build complete"
log_and_echo ""

# Install waypipe
log_info "📦 Installing waypipe to ${INSTALL_PREFIX}..."
if [[ "$INSTALL_PREFIX" == "/opt/homebrew" ]]; then
    log_and_echo "   Installing to Homebrew prefix (no sudo needed)"
    meson install -C build 2>&1 | tee -a "$LOG_FILE"
else
    log_and_echo "   This requires sudo privileges"
    sudo meson install -C build 2>&1 | tee -a "$LOG_FILE"
fi

log_and_echo ""
log_success "✅ Waypipe installation complete!"
log_and_echo ""

# Verify installation
log_info "🔍 Verifying installation..."
log_and_echo ""

export PATH="${INSTALL_PREFIX}/bin:$PATH"

if command_exists waypipe; then
    WAYPIPE_PATH=$(which waypipe)
    WAYPIPE_VERSION=$(waypipe --version 2>/dev/null || echo "unknown")
    log_success "✓ waypipe: ${WAYPIPE_VERSION}"
    log_and_echo "   Location: ${WAYPIPE_PATH}"
else
    if [ -f "${INSTALL_PREFIX}/bin/waypipe" ]; then
        log_success "✓ waypipe: Found at ${INSTALL_PREFIX}/bin/waypipe"
        log_warning "   Add to PATH: export PATH=\"${INSTALL_PREFIX}/bin:\$PATH\""
    else
        log_error "✗ waypipe: NOT FOUND"
        log_error "   Check log file for build errors: $LOG_FILE"
    fi
fi

log_and_echo ""
log_success "🎉 Done! Waypipe is ready to use."
log_and_echo ""
log_info "📋 Full installation log saved to: $LOG_FILE"
log_and_echo ""

