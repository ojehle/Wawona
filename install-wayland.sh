#!/bin/bash

# CALayerWayland - Wayland Installation Script
# Automates building wayland from source on macOS
# (Homebrew formula requires Linux, but wayland builds fine on macOS)

# Don't exit on error immediately - let error handler catch it
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
LOG_FILE="${LOG_FILE:-${LOG_DIR}/wayland-install.log}"
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
    log_error ""
    log_error "Last 50 lines of log:"
    log_error "----------------------------------------"
    tail -50 "$LOG_FILE" | sed 's/^/   /' | tee -a "$LOG_FILE" >&2
    log_error "----------------------------------------"
    exit $exit_code
}

# Trap errors
trap 'error_exit $LINENO' ERR

# Initialize log file
{
    echo "=========================================="
    echo "Wayland Installation Log"
    echo "Started: $(date)"
    echo "=========================================="
    echo ""
} > "$LOG_FILE"

log_info "🔧 CALayerWayland - Wayland Installation Script"
log_and_echo "=========================================="
log_and_echo ""
log_info "📋 Log file: $LOG_FILE"
log_and_echo ""
log_warning "This script will:"
log_and_echo "  1. Check and install build dependencies"
log_and_echo "  2. Clone wayland repository"
log_and_echo "  3. Build wayland from source"
log_and_echo "  4. Install wayland libraries"
log_and_echo ""

# Default installation prefix - use Homebrew location for Apple Silicon
# Apple Silicon: /opt/homebrew
# Intel Mac: /usr/local
if [[ "$(uname -m)" == "arm64" ]] && [ -d "/opt/homebrew" ]; then
    DEFAULT_PREFIX="/opt/homebrew"
else
    DEFAULT_PREFIX="/usr/local"
fi
INSTALL_PREFIX="${INSTALL_PREFIX:-$DEFAULT_PREFIX}"
WAYLAND_VERSION="${WAYLAND_VERSION:-1.24.0}"
WAYLAND_REPO="${WAYLAND_REPO:-https://gitlab.freedesktop.org/wayland/wayland.git}"
BUILD_DIR="${BUILD_DIR:-./wayland-build}"

log_info "Installation prefix: ${INSTALL_PREFIX}"
log_and_echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${YELLOW}⚠️  Warning: This script is designed for macOS${NC}"
    echo "   Continuing anyway..."
    echo ""
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if package is installed via pkg-config
pkg_exists() {
    pkg-config --exists "$1" 2>/dev/null
}

# Check for Homebrew
if ! command_exists brew; then
    log_error "❌ Homebrew not found!"
    log_and_echo "   Please install Homebrew first:"
    log_and_echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
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
    log_warning "⚠ meson not found"
    MISSING_DEPS+=("meson")
else
    log_success "✓ meson: $(meson --version 2>/dev/null | head -n1 || echo 'found')"
fi

# Check ninja
if ! command_exists ninja; then
    log_warning "⚠ ninja not found"
    MISSING_DEPS+=("ninja")
else
    log_success "✓ ninja: $(ninja --version 2>/dev/null || echo 'found')"
fi

# Check pkg-config
if ! command_exists pkg-config; then
    log_warning "⚠ pkg-config not found"
    MISSING_DEPS+=("pkg-config")
else
    log_success "✓ pkg-config: $(pkg-config --version)"
fi

# Check expat
if ! pkg_exists expat; then
    log_warning "⚠ expat not found via pkg-config"
    MISSING_DEPS+=("expat")
else
    log_success "✓ expat: $(pkg-config --modversion expat)"
fi

# Check libffi
if ! pkg_exists libffi; then
    log_warning "⚠ libffi not found via pkg-config"
    MISSING_DEPS+=("libffi")
else
    log_success "✓ libffi: $(pkg-config --modversion libffi)"
fi

# Check libxml2
if ! pkg_exists libxml-2.0; then
    log_warning "⚠ libxml2 not found via pkg-config"
    MISSING_DEPS+=("libxml2")
else
    log_success "✓ libxml2: $(pkg-config --modversion libxml-2.0)"
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

# Check if wayland is already installed
if pkg_exists wayland-server && pkg_exists wayland-client && command_exists wayland-scanner; then
    log_success "✓ Wayland appears to be already installed:"
    log_and_echo "   wayland-server: $(pkg-config --modversion wayland-server)"
    log_and_echo "   wayland-client: $(pkg-config --modversion wayland-client)"
    log_and_echo "   wayland-scanner: $(which wayland-scanner)"
    log_and_echo ""
    if [ -t 0 ]; then
        # Interactive mode - ask user
        read -p "Do you want to rebuild and reinstall? (y/N): " -n 1 -r
        log_and_echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_success "✓ Skipping installation. Wayland is already installed."
            exit 0
        fi
    else
        # Non-interactive mode - continue with rebuild
        log_info "Non-interactive mode: continuing with rebuild..."
        log_and_echo ""
    fi
fi

# Clone wayland repository
log_info "📥 Cloning wayland repository..."
log_and_echo ""

if [ -d "wayland" ]; then
    log_warning "⚠ wayland directory already exists"
    if [ -t 0 ]; then
        # Interactive mode - ask user
        read -p "Remove existing directory and re-clone? (y/N): " -n 1 -r
        log_and_echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_and_echo "Removing existing wayland directory..."
            rm -rf wayland
        else
            log_success "✓ Using existing wayland directory (preserving local changes)"
            SKIP_CLONE=1
            SKIP_CHECKOUT=1
        fi
    else
        # Non-interactive mode - use existing directory and preserve local changes
        log_success "✓ Using existing wayland directory (non-interactive mode, preserving local changes)"
        SKIP_CLONE=1
        SKIP_CHECKOUT=1
    fi
fi

if [ -z "$SKIP_CLONE" ]; then
    git clone "$WAYLAND_REPO" wayland 2>&1 | tee -a "$LOG_FILE"
    log_success "✓ Repository cloned"
    log_and_echo ""
fi

# Enter wayland directory
cd wayland

# Checkout specific version if specified and not using existing directory
if [ -n "$WAYLAND_VERSION" ] && [ -z "$SKIP_CHECKOUT" ]; then
    log_info "📌 Checking out version ${WAYLAND_VERSION}..."
    # Try different tag formats
    if git checkout "wayland-${WAYLAND_VERSION}" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "✓ Checked out wayland-${WAYLAND_VERSION}"
    elif git checkout "${WAYLAND_VERSION}" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "✓ Checked out ${WAYLAND_VERSION}"
    elif git checkout "v${WAYLAND_VERSION}" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "✓ Checked out v${WAYLAND_VERSION}"
    else
        log_warning "⚠ Version ${WAYLAND_VERSION} not found, using latest (HEAD)"
        git checkout main 2>&1 | tee -a "$LOG_FILE" || git checkout master 2>&1 | tee -a "$LOG_FILE" || true
    fi
    log_and_echo ""
elif [ -n "$SKIP_CHECKOUT" ]; then
    log_info "📌 Skipping version checkout to preserve local changes"
    log_and_echo ""
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
# Note: We disable tests and documentation to avoid Linux-specific dependencies
log_and_echo "Running: meson setup build -Ddocumentation=false -Dtests=false --prefix=$INSTALL_PREFIX"
log_and_echo ""

# Set PKG_CONFIG_PATH for meson to find dependencies
export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

meson setup build \
    -Ddocumentation=false \
    -Dtests=false \
    --prefix="$INSTALL_PREFIX" 2>&1 | tee -a "$LOG_FILE"

log_success "✓ Build configured"
log_and_echo ""

# Build wayland
log_info "🔨 Building wayland..."
log_and_echo "   This may take a few minutes..."
log_and_echo "   Note: If build fails due to Linux dependencies, wayland may not be buildable on macOS."
log_and_echo ""

# Set PKG_CONFIG_PATH for build
export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

meson compile -C build 2>&1 | tee -a "$LOG_FILE"

log_and_echo ""
log_success "✓ Build complete"
log_and_echo ""

# Install wayland
log_info "📦 Installing wayland to ${INSTALL_PREFIX}..."
if [[ "$INSTALL_PREFIX" == "/opt/homebrew" ]]; then
    log_and_echo "   Installing to Homebrew prefix (no sudo needed)"
    meson install -C build 2>&1 | tee -a "$LOG_FILE"
else
    log_and_echo "   This requires sudo privileges"
    sudo meson install -C build 2>&1 | tee -a "$LOG_FILE"
fi

log_and_echo ""
log_success "✅ Wayland installation complete!"
log_and_echo ""
log_and_echo "Installed components:"
log_and_echo "  - libwayland-server"
log_and_echo "  - libwayland-client"
log_and_echo "  - wayland-scanner"
log_and_echo ""
log_and_echo "Installation prefix: ${INSTALL_PREFIX}"
log_and_echo ""

# Verify installation
log_info "🔍 Verifying installation..."
log_and_echo ""

# Update PKG_CONFIG_PATH for verification
export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH"
export PATH="${INSTALL_PREFIX}/bin:$PATH"

if pkg_exists wayland-server; then
    VERSION=$(pkg-config --modversion wayland-server)
    log_success "✓ wayland-server: ${VERSION}"
    log_and_echo "   Location: $(pkg-config --variable=libdir wayland-server)/libwayland-server.dylib"
else
    # Try manual check
    if [ -f "${INSTALL_PREFIX}/lib/libwayland-server.dylib" ] || [ -f "${INSTALL_PREFIX}/lib/libwayland-server.a" ]; then
        log_success "✓ wayland-server: Found at ${INSTALL_PREFIX}/lib/"
    else
        log_error "✗ wayland-server: NOT FOUND"
        log_error "   Check log file for build errors: $LOG_FILE"
    fi
fi

if pkg_exists wayland-client; then
    VERSION=$(pkg-config --modversion wayland-client)
    log_success "✓ wayland-client: ${VERSION}"
else
    if [ -f "${INSTALL_PREFIX}/lib/libwayland-client.dylib" ] || [ -f "${INSTALL_PREFIX}/lib/libwayland-client.a" ]; then
        log_success "✓ wayland-client: Found at ${INSTALL_PREFIX}/lib/"
    else
        log_error "✗ wayland-client: NOT FOUND"
    fi
fi

if command_exists wayland-scanner; then
    SCANNER_PATH=$(which wayland-scanner)
    log_success "✓ wayland-scanner: ${SCANNER_PATH}"
else
    if [ -f "${INSTALL_PREFIX}/bin/wayland-scanner" ]; then
        log_success "✓ wayland-scanner: Found at ${INSTALL_PREFIX}/bin/wayland-scanner"
        log_warning "   Add to PATH: export PATH=\"${INSTALL_PREFIX}/bin:\$PATH\""
    else
        log_error "✗ wayland-scanner: NOT FOUND"
    fi
fi

log_and_echo ""
log_success "🎉 Done! You can now run ./check-deps.sh to verify all dependencies."
log_and_echo ""

# Update PKG_CONFIG_PATH for current session
log_info "📋 Post-installation setup:"
log_and_echo ""
log_and_echo "To use wayland libraries, add to your shell profile (~/.zshrc or ~/.bash_profile):"
log_and_echo ""
log_and_echo "  export PKG_CONFIG_PATH=\"${INSTALL_PREFIX}/lib/pkgconfig:\$PKG_CONFIG_PATH\""
log_and_echo "  export PATH=\"${INSTALL_PREFIX}/bin:\$PATH\""
log_and_echo ""

# Try to update current session
export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH"
export PATH="${INSTALL_PREFIX}/bin:$PATH"

log_info "📋 Full installation log saved to: $LOG_FILE"
log_and_echo ""

