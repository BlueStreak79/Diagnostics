# ==========================
# Diagnostics Dashboard Tool
# Created by Blue
# ==========================
# "These diagnostics are created by Blue - unlocking system secrets with just one click."
# ==========================

$ErrorActionPreference = "Stop"

# Enable TLS 1.2 for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Define applications (official links from your repository)
$apps = @{
    1 = @{ Name = "AquaKeyTest";      Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/AquaKeyTest.exe" }
    2 = @{ Name = "BatteryInfoView";  Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/BatteryInfoView.exe" }
    3 = @{ Name = "Camera";           Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/Camera.exe" }
    4 = @{ Name = "lusrmgr";          Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/lusrmgr.exe" }
    5 = @{ Name = "MemTest64";        Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/MemTest64.exe" }
    6 = @{ Name = "LCDtest";          Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/LCDtest.exe" }
    7 = @{ Name = "OemKey";           Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/OemKey.exe" }
    8 = @{ Name = "ShowKeyPlus";      Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/ShowKeyPlus.exe" }
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
        $FilePath = Join-Path $env:TEMP "$($app.Name).exe"
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

while ($true) {
    Show-Dashboard
    $selection = Read-Host "Select a diagnostic tool (0 to exit)"
    if ($selection -eq '0') {
        Write-Host "Exiting and closing window..." -ForegroundColor Green
        Start-Sleep -Seconds 1
        # Close this PowerShell window
        $psWindow = Get-Process -Id $PID
        $psWindow.CloseMainWindow() | Out-Null
        break
    }
    elseif ($selection -match '^[1-8]$') {
        Download-And-Run -number [int]$selection
        Start-Sleep -Seconds 2
    }
    else {
        Write-Host "Invalid selection. Please choose a valid number." -ForegroundColor Red
        Start-Sleep -Seconds 1.5
    }
}
