#!/bin/bash
# Container tool installation and verification

source "$(dirname "$0")/config.sh"

# Find or install container tool
find_or_install_container_tool() {
    CONTAINER_CMD=""
    if command -v container >/dev/null 2>&1; then
        CONTAINER_CMD=$(command -v container)
    elif [ -f "/usr/local/bin/container" ] && [ -x "/usr/local/bin/container" ]; then
        CONTAINER_CMD="/usr/local/bin/container"
        export PATH="/usr/local/bin:$PATH"
    fi

    if [ -n "$CONTAINER_CMD" ]; then
        echo -e "${GREEN}✓${NC} Container tool installed: ${GREEN}$CONTAINER_CMD${NC}"
        echo ""
        export CONTAINER_CMD
        return 0
    fi

    echo -e "${YELLOW}ℹ${NC} Container tool not installed - building and installing..."
    echo ""
    
    # Prerequisites check
    if [ "$(uname -m)" != "arm64" ]; then
        echo -e "${RED}✗${NC} Apple container tool requires Apple silicon (arm64)"
        exit 1
    fi
    
    if ! command -v swift >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Swift compiler not found. Install Xcode Command Line Tools:"
        echo "   xcode-select --install"
        exit 1
    fi
    
    # Build from source
    CONTAINER_REPO_DIR="$HOME/Library/Caches/container-build"
    
    if [ ! -d "$CONTAINER_REPO_DIR" ]; then
        echo "ℹ  Cloning container repository..."
        mkdir -p "$CONTAINER_REPO_DIR"
        git clone https://github.com/apple/container.git "$CONTAINER_REPO_DIR" || {
            echo "✗  Failed to clone repository"
            exit 1
        }
    else
        echo "ℹ  Repository already cloned, updating..."
        cd "$CONTAINER_REPO_DIR" && git pull 2>/dev/null || true
    fi
    
    cd "$CONTAINER_REPO_DIR" || exit 1
    
    echo "ℹ  Building container tool (this may take 5-10 minutes)..."
    echo ""
    
    if [ ! -f "Makefile" ]; then
        echo "✗  Makefile not found in repository"
        exit 1
    fi
    
    # Build (use release for better performance)
    BUILD_LOG="/tmp/container-build-$$.log"
    if ! make all BUILD_CONFIGURATION=release > "$BUILD_LOG" 2>&1; then
        echo "✗  Build failed"
        echo "ℹ  Last 30 lines of build output:"
        tail -30 "$BUILD_LOG"
        echo ""
        echo "ℹ  Full build log: $BUILD_LOG"
        exit 1
    fi
    
    echo "✓  Build completed"
    
    # Find the built .pkg installer
    PKG_FILE=""
    if [ -f "bin/release/container-installer-unsigned.pkg" ]; then
        PKG_FILE="bin/release/container-installer-unsigned.pkg"
    elif [ -f "bin/debug/container-installer-unsigned.pkg" ]; then
        PKG_FILE="bin/debug/container-installer-unsigned.pkg"
    fi
    
    if [ -z "$PKG_FILE" ] || [ ! -f "$PKG_FILE" ]; then
        echo "✗  Installer package not found"
        echo "ℹ  Searched in:"
        echo "   - bin/release/container-installer-unsigned.pkg"
        echo "   - bin/debug/container-installer-unsigned.pkg"
        exit 1
    fi
    
    # Install using installer command
    echo ""
    echo -e "${YELLOW}ℹ${NC} Installing container tool from package..."
    echo -e "${YELLOW}ℹ${NC} You may be prompted for your administrator password..."
    
    if ! sudo installer -pkg "$PKG_FILE" -target /; then
        echo "✗  Installation failed"
        exit 1
    fi
    
    # Verify installation
    if [ -f "/usr/local/bin/container" ] && [ -x "/usr/local/bin/container" ]; then
        CONTAINER_CMD="/usr/local/bin/container"
        export PATH="/usr/local/bin:$PATH"
        echo -e "${GREEN}✓${NC} Container tool installed successfully"
    else
        echo "✗  Installation verification failed"
        exit 1
    fi
    
    rm -f "$BUILD_LOG"
    echo ""
    
    export CONTAINER_CMD
}

