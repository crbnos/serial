#!/bin/bash
# Serial URL Scanner - Linux Installation Script
# This script installs Go runtime, downloads the scanner, and sets it up to run at startup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}Serial URL Scanner - Linux Installation${NC}"
echo -e "${CYAN}=========================================${NC}"

# Configuration
APP_NAME="serial-scanner"
DOWNLOAD_BASE_URL="https://github.com/barbinbrad/serial-url-scanner/releases/latest/download"
INSTALL_DIR="/opt/serial-scanner"
EXE_NAME="serial-scanner"
EXE_PATH="$INSTALL_DIR/$EXE_NAME"
SERVICE_PATH="/etc/systemd/system/serial-scanner.service"
LOG_PATH="/var/log/serial-scanner.log"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This script needs to run as root. Restarting with sudo...${NC}"
    exec sudo "$0" "$@"
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
else
    echo -e "${RED}Unsupported architecture: $ARCH${NC}"
    exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}Cannot detect Linux distribution${NC}"
    exit 1
fi

DOWNLOAD_URL="$DOWNLOAD_BASE_URL/serial-scanner-linux-$ARCH"

# Step 1: Install Go runtime if not present
echo -e "\n${GREEN}Step 1: Checking for Go runtime...${NC}"
if command -v go &> /dev/null; then
    echo "Go is already installed: $(go version)"
else
    echo -e "${YELLOW}Installing Go runtime...${NC}"

    GO_VERSION="1.21.6"
    GO_TAR="go${GO_VERSION}.linux-${ARCH}.tar.gz"
    GO_URL="https://go.dev/dl/${GO_TAR}"

    # Download and install Go
    echo "Downloading Go ${GO_VERSION}..."
    wget -q --show-progress "$GO_URL" -O "/tmp/${GO_TAR}"

    echo "Installing Go..."
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "/tmp/${GO_TAR}"
    rm "/tmp/${GO_TAR}"

    # Add Go to PATH
    if ! grep -q "/usr/local/go/bin" /etc/profile; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    fi

    # Make Go available in current session
    export PATH=$PATH:/usr/local/go/bin

    echo -e "${GREEN}Go runtime installed successfully${NC}"
fi

# Step 2: Create installation directory
echo -e "\n${GREEN}Step 2: Setting up installation directory...${NC}"
mkdir -p "$INSTALL_DIR"

# Step 3: Download the scanner executable
echo -e "\n${GREEN}Step 3: Downloading Serial URL Scanner...${NC}"
echo "Downloading from: $DOWNLOAD_URL"

# Stop existing service if running
systemctl stop serial-scanner 2>/dev/null || true

# Download the executable
wget -q --show-progress "$DOWNLOAD_URL" -O "$EXE_PATH"
chmod +x "$EXE_PATH"
echo -e "${GREEN}Scanner downloaded successfully${NC}"

# Step 4: Add user to dialout group for serial port access
echo -e "\n${GREEN}Step 4: Configuring serial port permissions...${NC}"
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" != "root" ]; then
    usermod -a -G dialout "$CURRENT_USER" 2>/dev/null || true
    echo "User $CURRENT_USER added to dialout group for serial port access"
fi

# Step 5: Create systemd service
echo -e "\n${GREEN}Step 5: Setting up automatic startup...${NC}"

cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Serial URL Scanner
After=network.target

[Service]
Type=simple
ExecStart=$EXE_PATH
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
User=root
Group=dialout

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable serial-scanner
echo -e "${GREEN}Startup service created successfully${NC}"

# Step 6: Start the scanner
echo -e "\n${GREEN}Step 6: Starting Serial URL Scanner...${NC}"
systemctl start serial-scanner

echo -e "\n${CYAN}=========================================${NC}"
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${GREEN}Serial URL Scanner is now running and will start automatically on boot.${NC}"

# Show service status
echo -e "\nService status:"
systemctl status serial-scanner --no-pager || true

echo -e "\nUseful commands:"
echo "  View logs:     sudo journalctl -u serial-scanner -f"
echo "  Check status:  sudo systemctl status serial-scanner"
echo "  Restart:       sudo systemctl restart serial-scanner"
echo "  Stop:          sudo systemctl stop serial-scanner"

if [ "$CURRENT_USER" != "root" ]; then
    echo -e "\n${YELLOW}Note: You may need to log out and back in for serial port permissions to take effect.${NC}"
fi