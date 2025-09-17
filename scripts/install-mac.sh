#!/bin/bash
# Serial URL Scanner - macOS Installation Script
# This script installs Go runtime, downloads the scanner, and sets it up to run at startup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}Serial URL Scanner - macOS Installation${NC}"
echo -e "${CYAN}=========================================${NC}"

# Configuration
APP_NAME="SerialURLScanner"
DOWNLOAD_BASE_URL="https://github.com/crbnos/serial/releases/latest/download"
INSTALL_DIR="$HOME/.serial-scanner"
EXE_NAME="serial-scanner"
EXE_PATH="$INSTALL_DIR/$EXE_NAME"
PLIST_PATH="$HOME/Library/LaunchAgents/com.barbinbrad.serialscanner.plist"
LOG_PATH="$INSTALL_DIR/scanner.log"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
else
    echo -e "${RED}Unsupported architecture: $ARCH${NC}"
    exit 1
fi

DOWNLOAD_URL="$DOWNLOAD_BASE_URL/serial-scanner-darwin-$ARCH"

# Step 1: Install Go runtime if not present
echo -e "\n${GREEN}Step 1: Checking for Go runtime...${NC}"
if command -v go &> /dev/null; then
    echo "Go is already installed: $(go version)"
else
    echo -e "${YELLOW}Installing Go runtime via Homebrew...${NC}"

    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon Macs
        if [ "$ARCH" = "arm64" ]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi

    # Install Go
    brew install go
    echo -e "${GREEN}Go runtime installed successfully${NC}"
fi

# Step 2: Create installation directory
echo -e "\n${GREEN}Step 2: Setting up installation directory...${NC}"
mkdir -p "$INSTALL_DIR"

# Step 3: Download the scanner executable
echo -e "\n${GREEN}Step 3: Downloading Serial URL Scanner...${NC}"
echo "Downloading from: $DOWNLOAD_URL"

# Stop existing process if running
if launchctl list | grep -q com.barbinbrad.serialscanner; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

# Download the executable
curl -L "$DOWNLOAD_URL" -o "$EXE_PATH"
chmod +x "$EXE_PATH"
echo -e "${GREEN}Scanner downloaded successfully${NC}"

# Step 4: Create LaunchAgent for startup
echo -e "\n${GREEN}Step 4: Setting up automatic startup...${NC}"

# Create LaunchAgent plist
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.barbinbrad.serialscanner</string>
    <key>ProgramArguments</key>
    <array>
        <string>$EXE_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_PATH</string>
    <key>StandardErrorPath</key>
    <string>$LOG_PATH</string>
</dict>
</plist>
EOF

# Load the LaunchAgent
launchctl load "$PLIST_PATH"
echo -e "${GREEN}Startup task created successfully${NC}"

# Step 5: Start the scanner
echo -e "\n${GREEN}Step 5: Starting Serial URL Scanner...${NC}"
launchctl start com.barbinbrad.serialscanner

echo -e "\n${CYAN}=========================================${NC}"
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${GREEN}Serial URL Scanner is now running and will start automatically on login.${NC}"
echo -e "\nLog file location: $LOG_PATH"

# Check if running
sleep 2
if launchctl list | grep -q com.barbinbrad.serialscanner; then
    echo -e "\n${GREEN}✓ Service is running${NC}"
else
    echo -e "\n${YELLOW}⚠ Service may not have started. Check logs at: $LOG_PATH${NC}"
fi