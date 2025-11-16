#!/bin/bash
# Docker and Colima setup and verification

# Check if Docker/Colima are installed
check_docker_colima() {
    if ! command -v docker >/dev/null 2>&1 || ! command -v colima >/dev/null 2>&1; then
        echo -e "${YELLOW}ℹ${NC} Docker/Colima not found - installing via Homebrew..."
        echo ""
        
        # Check if Homebrew is available
        if ! command -v brew >/dev/null 2>&1; then
            echo -e "${RED}✗${NC} Homebrew not found"
            echo ""
            echo -e "${YELLOW}ℹ${NC} Install Homebrew first:"
            echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
        
        # Install Colima, Docker, and Docker Compose
        echo -e "${YELLOW}ℹ${NC} Installing Colima, Docker, and Docker Compose..."
        brew install colima docker docker-compose || {
            echo -e "${RED}✗${NC} Failed to install Colima/Docker"
            exit 1
        }
        echo -e "${GREEN}✓${NC} Colima and Docker installed"
        echo ""
    fi
}

# Check and start Colima if needed
ensure_colima_running() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${YELLOW}ℹ${NC} Docker daemon not running - starting Colima..."
        echo -e "${YELLOW}ℹ${NC} Starting Colima with VirtioFS (required for Unix domain sockets)..."
        colima start --mount-type virtiofs || {
            echo -e "${RED}✗${NC} Failed to start Colima"
            exit 1
        }
        echo -e "${GREEN}✓${NC} Colima started"
    else
        # Check if Colima is using VirtioFS
        if command -v colima >/dev/null 2>&1; then
            COLIMASTATUS=$(colima status 2>/dev/null || echo "")
            if echo "$COLIMASTATUS" | grep -q "mount.*virtiofs"; then
                echo -e "${GREEN}✓${NC} Colima running with VirtioFS"
            elif echo "$COLIMASTATUS" | grep -q "mount.*sshfs"; then
                echo -e "${YELLOW}⚠${NC} Colima is using SSHFS - Unix domain sockets may not work"
                echo -e "${YELLOW}ℹ${NC} Restart Colima with VirtioFS:"
                echo "   colima stop && colima start --mount-type virtiofs"
                echo ""
                read -p "Continue anyway? (y/N) " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            else
                echo -e "${GREEN}✓${NC} Docker daemon running"
            fi
        else
            echo -e "${GREEN}✓${NC} Docker daemon running"
        fi
    fi
    echo ""
}

# Initialize Docker/Colima setup
init_docker() {
    check_docker_colima
    ensure_colima_running
}

