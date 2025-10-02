# ==========================
# Blue's Diagnostics Dashboard
# JSON-driven version (no hash check)
# ==========================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Load app list from JSON
$toolsUrl = "https://github.com/BlueStreak79/Diagnostics/raw/main/tools.json"
try {
    $apps = Invoke-RestMethod -Uri $toolsUrl -UseBasicParsing
} catch {
    Write-Host "❌ Failed to load tools list from GitHub." -ForegroundColor Red
    exit
}

function Show-Dashboard {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "`nThese diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!`n"
    foreach ($k in ($apps.PSObject.Properties.Name | Sort-Object {[int]$_})) {
        Write-Host "$k. $($apps.$k.Name)"
    }
    Write-Host "0. Exit (cleanup)"
}

function Download-And-Run($number) {
    try {
        $app = $apps.$number
        if (-not $app) {
            Write-Host "Invalid selection." -ForegroundColor Red
            return
        }
        $FilePath = Join-Path $env:TEMP "$($app.Name).exe"

        # Download if not already present
        if (-not (Test-Path $FilePath)) {
            Write-Host "⬇️ Downloading $($app.Name)..."
            Invoke-WebRequest -Uri $app.Url -OutFile $FilePath -UseBasicParsing
        } else {
            Write-Host "✔️ $($app.Name) already in TEMP."
        }

        Write-Host "🚀 Launching $($app.Name)..."
        Start-Process -FilePath $FilePath
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
    $selection = $selection.Trim()
    if ($selection -eq '0') {
        Write-Host "✅ Exiting and closing window..." -ForegroundColor Green
        Start-Sleep -Seconds 1
        Stop-Process -Id $PID -Force
        break
    }
    elseif ($selection -match '^\d+$') {
        Download-And-Run -number $selection
        Start-Sleep -Seconds 2
    }
    else {
        Write-Host "Invalid selection. Please choose a valid number." -ForegroundColor Red
        Start-Sleep -Seconds 1.5
    }
}
