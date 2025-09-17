# Serial URL Scanner - Windows Installation Script
# This script installs Go runtime, downloads the scanner, and sets it up to run at startup

$ErrorActionPreference = "Stop"

Write-Host "Serial URL Scanner - Windows Installation" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Configuration
$appName = "SerialURLScanner"
$downloadBaseUrl = "https://github.com/barbinbrad/serial-url-scanner/releases/latest/download"
$installDir = "$env:ProgramData\$appName"
$exeName = "serial-scanner.exe"
$exePath = "$installDir\$exeName"

# Detect architecture
$arch = if ([Environment]::Is64BitOperatingSystem) {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
} else {
    "386"
}

$downloadUrl = "$downloadBaseUrl/serial-scanner-windows-$arch.exe"

# Function to check if running as admin
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Elevate to admin if not already
if (-not (Test-Admin)) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath -Verb RunAs
    exit
}

try {
    # Step 1: Install Go runtime if not present
    Write-Host "`nStep 1: Checking for Go runtime..." -ForegroundColor Green
    $goInstalled = $false
    try {
        $goVersion = go version 2>$null
        if ($goVersion) {
            Write-Host "Go is already installed: $goVersion" -ForegroundColor Gray
            $goInstalled = $true
        }
    } catch {}

    if (-not $goInstalled) {
        Write-Host "Installing Go runtime..." -ForegroundColor Yellow

        # Download Go installer
        $goInstallerUrl = "https://go.dev/dl/go1.21.6.windows-$arch.msi"
        $goInstaller = "$env:TEMP\go-installer.msi"

        Write-Host "Downloading Go installer..."
        Invoke-WebRequest -Uri $goInstallerUrl -OutFile $goInstaller -UseBasicParsing

        Write-Host "Installing Go..."
        Start-Process msiexec.exe -ArgumentList "/i", $goInstaller, "/quiet", "/norestart" -Wait

        # Add Go to PATH
        $goPath = "C:\Program Files\Go\bin"
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$goPath*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$goPath", "Machine")
        }

        Remove-Item $goInstaller -Force
        Write-Host "Go runtime installed successfully" -ForegroundColor Green
    }

    # Step 2: Create installation directory
    Write-Host "`nStep 2: Setting up installation directory..." -ForegroundColor Green
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    # Step 3: Download the scanner executable
    Write-Host "`nStep 3: Downloading Serial URL Scanner..." -ForegroundColor Green
    Write-Host "Downloading from: $downloadUrl"

    # Stop existing process if running
    Get-Process -Name "serial-scanner" -ErrorAction SilentlyContinue | Stop-Process -Force

    # Download the executable
    Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing
    Write-Host "Scanner downloaded successfully" -ForegroundColor Green

    # Step 4: Create scheduled task for startup
    Write-Host "`nStep 4: Setting up automatic startup..." -ForegroundColor Green

    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $appName -Confirm:$false -ErrorAction SilentlyContinue

    # Create new scheduled task
    $action = New-ScheduledTaskAction -Execute $exePath
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Seconds 10)

    Register-ScheduledTask -TaskName $appName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

    Write-Host "Startup task created successfully" -ForegroundColor Green

    # Step 5: Start the scanner
    Write-Host "`nStep 5: Starting Serial URL Scanner..." -ForegroundColor Green
    Start-ScheduledTask -TaskName $appName

    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "Serial URL Scanner is now running and will start automatically on boot." -ForegroundColor Green
    Write-Host "`nLog file location: $installDir\scanner.log" -ForegroundColor Gray

} catch {
    Write-Host "`nInstallation failed: $_" -ForegroundColor Red
    exit 1
}