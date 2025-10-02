# ==========================
# Diagnostics Dashboard Tool
# Created by Blue
# ==========================
# "These diagnostics are created by Blue - unlocking system secrets with just one click."
# ==========================

# Stop on errors
$ErrorActionPreference = "Stop"

# Enable TLS 1.2 for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Define applications list with direct download URLs
$apps = @{
    1 = @{ Name = "AquaKeyTest.exe";  Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/AquaKeyTest.exe" }
    2 = @{ Name = "BatteryInfoView.exe"; Url = "https://example.com/BatteryInfoView.exe" }
    3 = @{ Name = "Camera.exe";   Url = "https://example.com/Camera.exe" }
    4 = @{ Name = "lusrmgr.exe";  Url = "https://example.com/lusrmgr.exe" }
    5 = @{ Name = "MemTest64.exe"; Url = "https://example.com/MemTest64.exe" }
    6 = @{ Name = "LCDtest.exe";   Url = "https://example.com/LCDtest.exe" }
    7 = @{ Name = "OemKey.exe";   Url = "https://example.com/OemKey.exe" }
}

function Show-Dashboard {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "`nThese diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!`n"
    
    foreach ($k in $apps.Keys | Sort-Object) {
        Write-Host "$k. $($apps[$k].Name)"
    }
    Write-Host "0. Exit (cleanup)"
}

function Download-And-Run($number) {
    try {
        $app = $apps[$number]
        if (-not $app) {
            Write-Host "Invalid selection." -ForegroundColor Red
            return
        }

        $FilePath = Join-Path $env:TEMP $app.Name
        if (-not (Test-Path $FilePath)) {
            Write-Host "Downloading $($app.Name)..."
            Invoke-WebRequest -Uri $app.Url -OutFile $FilePath -UseBasicParsing
            if (-not (Test-Path $FilePath)) {
                throw "Download failed for $($app.Name)."
            }
            Write-Host "Download completed."
        } else {
            Write-Host "$($app.Name) already exists in TEMP. Skipping download."
        }

        Write-Host "Launching $($app.Name)..."
        # Launch without waiting, so user can run multiple apps
        Start-Process -FilePath $FilePath
        Write-Host "$($app.Name) started.`n"
    }
    catch {
        Write-Error "Error with $($app.Name): $_"
    }
}

# ==========================
# Main Loop
# ==========================
do {
    Show-Dashboard
    $choice = Read-Host "Enter your choice (0-7)"
    if ($choice -eq "0") {
        Write-Host "Cleaning up temporary files..."
        foreach ($app in $apps.Values) {
            $path = Join-Path $env:TEMP $app.Name
            if (Test-Path $path) {
                Remove-Item $path -Force
                Write-Host "Removed $($app.Name) from TEMP."
            }
        }
        Write-Host "Exiting dashboard. Goodbye!" -ForegroundColor Cyan
        break
    } else {
        Download-And-Run $choice
        Pause
    }
} while ($true)
