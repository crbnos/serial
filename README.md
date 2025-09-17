# Serial URL Scanner

A cross-platform Go application that monitors serial ports for URLs and automatically opens them in the default browser. Perfect for QR code scanners, barcode readers, or any device that outputs URLs via serial communication.

## Features

- = Monitors all available serial ports automatically
- < Detects URLs in serial data using regex pattern matching
- =¥ Opens URLs in the default browser across Windows, macOS, and Linux
- =€ Runs as a background service/daemon on startup
- =æ Zero-configuration installation with one-line installers
- =' Self-contained executable with no external dependencies

## Quick Installation

### Windows (PowerShell - Run as Administrator)
```powershell
iwr -useb https://raw.githubusercontent.com/barbinbrad/serial-url-scanner/main/scripts/install-windows.ps1 | iex
```

### macOS (Terminal)
```bash
curl -fsSL https://raw.githubusercontent.com/barbinbrad/serial-url-scanner/main/scripts/install-mac.sh | bash
```

### Linux (Terminal)
```bash
curl -fsSL https://raw.githubusercontent.com/barbinbrad/serial-url-scanner/main/scripts/install-linux.sh | sudo bash
```

## What the Installation Does

The one-liner installation scripts automatically:

1. **Install Go Runtime** - Downloads and installs the latest Go runtime if not already present
2. **Download Executable** - Fetches the latest pre-built binary for your platform and architecture
3. **Setup Auto-Start** - Configures the scanner to run automatically on system startup:
   - **Windows**: Creates a Windows Scheduled Task
   - **macOS**: Creates a LaunchAgent
   - **Linux**: Creates a systemd service
4. **Start Service** - Immediately starts the scanner in the background

## How It Works

The scanner continuously:
1. Detects all available serial ports on the system
2. Monitors each port for incoming data (9600 baud, 8N1 by default)
3. Scans received text for URL patterns (`http://` or `https://`)
4. Validates found URLs and opens them in the default browser
5. Logs all activity for debugging purposes

## Supported Platforms

- **Windows** (x64, ARM64)
- **macOS** (Intel, Apple Silicon)
- **Linux** (x64, ARM64)

## Serial Port Configuration

The scanner uses these default serial settings:
- Baud Rate: 9600
- Data Bits: 8
- Stop Bits: 1
- Parity: None

These settings work with most QR code scanners and barcode readers. If you need different settings, you can modify the source code and rebuild.

## Logs and Troubleshooting

### View Logs

**Windows:**
```powershell
Get-Content "$env:ProgramData\SerialURLScanner\scanner.log" -Tail 50 -Wait
```

**macOS:**
```bash
tail -f ~/.serial-scanner/scanner.log
```

**Linux:**
```bash
sudo journalctl -u serial-scanner -f
```

### Service Management

**Windows:**
```powershell
# Check status
Get-ScheduledTask -TaskName "SerialURLScanner"

# Stop/Start
Stop-ScheduledTask -TaskName "SerialURLScanner"
Start-ScheduledTask -TaskName "SerialURLScanner"
```

**macOS:**
```bash
# Check status
launchctl list | grep serialscanner

# Stop/Start
launchctl stop com.barbinbrad.serialscanner
launchctl start com.barbinbrad.serialscanner
```

**Linux:**
```bash
# Check status
sudo systemctl status serial-scanner

# Stop/Start/Restart
sudo systemctl stop serial-scanner
sudo systemctl start serial-scanner
sudo systemctl restart serial-scanner
```

## Building from Source

If you prefer to build from source:

```bash
git clone https://github.com/barbinbrad/serial-url-scanner.git
cd serial-url-scanner
go build -o serial-scanner main.go
```

## Uninstallation

**Windows:**
```powershell
Unregister-ScheduledTask -TaskName "SerialURLScanner" -Confirm:$false
Remove-Item -Recurse -Force "$env:ProgramData\SerialURLScanner"
```

**macOS:**
```bash
launchctl unload ~/Library/LaunchAgents/com.barbinbrad.serialscanner.plist
rm ~/Library/LaunchAgents/com.barbinbrad.serialscanner.plist
rm -rf ~/.serial-scanner
```

**Linux:**
```bash
sudo systemctl stop serial-scanner
sudo systemctl disable serial-scanner
sudo rm /etc/systemd/system/serial-scanner.service
sudo rm -rf /opt/serial-scanner
sudo systemctl daemon-reload
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.