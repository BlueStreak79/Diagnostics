# ======================================================================
#  Diagnostics Dashboard Script
#  Author: Mustafa
#  Description: JSON-driven tool launcher + System Info popup
# ======================================================================

# -------------------------------
# Config: JSON Tools File
# -------------------------------
$toolsUrl = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/tools.json"

# -------------------------------
# Load JSON Tools List
# -------------------------------
try {
    $apps = Invoke-RestMethod -Uri $toolsUrl -UseBasicParsing
} catch {
    Write-Host "❌ Failed to load tools list from $toolsUrl" -ForegroundColor Red
    exit
}

# -------------------------------
# Function: Show Dashboard
# -------------------------------
function Show-Dashboard {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "          🔧 Diagnostics Dashboard       " -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    foreach ($app in $apps) {
        Write-Host ("[{0}] {1}" -f $app.Id, $app.Name) -ForegroundColor Green
    }
    Write-Host "[9] System Information" -ForegroundColor Cyan
    Write-Host "[0] Exit" -ForegroundColor Red
}

# -------------------------------
# Function: Download & Run Tool
# -------------------------------
function Download-And-Run {
    param([int]$id)

    $app = $apps | Where-Object { $_.Id -eq $id }
    if ($null -eq $app) {
        Write-Host "`n❌ Invalid tool ID." -ForegroundColor Yellow
        return
    }

    $tempFile = Join-Path $env:TEMP ($app.Name + ".exe")

    Write-Host "`n⬇️ Downloading $($app.Name)..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $app.Url -OutFile $tempFile -UseBasicParsing
        Write-Host "✔ Download complete. Launching..." -ForegroundColor Green
        Start-Process $tempFile
    }
    catch {
        Write-Host "❌ Failed to download or launch $($app.Name)" -ForegroundColor Red
    }
}

# -------------------------------
# Function: Show System Info
# -------------------------------
function Show-SystemInfo {
    $sys = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor
    $ramGB = [math]::Round($sys.TotalPhysicalMemory / 1GB, 2)
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join ", "
    $os = Get-CimInstance Win32_OperatingSystem
    $disk = (Get-PhysicalDisk | ForEach-Object { "$($_.FriendlyName) $([math]::Round($_.Size/1GB))GB" }) -join ", "
    $mb = (Get-CimInstance Win32_BaseBoard).Manufacturer
    $winVersion = if ($os.Caption -match "11") { "Windows 11" } else { "Windows 10" }

    $info = @"
System Information
------------------------------
Model       : $($sys.Model)
Serial No   : $($sys.Name)
Motherboard : $mb
Processor   : $($cpu.Name)
Memory      : $ramGB GB
GPU         : $gpu
Disk(s)     : $disk
OS Version  : $winVersion
"@

    [System.Windows.Forms.MessageBox]::Show($info, "System Info", 'OK', 'Information')
}

# Enable WinForms
Add-Type -AssemblyName System.Windows.Forms

# -------------------------------
# Main Loop
# -------------------------------
while ($true) {
    Show-Dashboard
    Write-Host "`nPress a number key (0 to exit, 9 for System Info)..."

    $key = [System.Console]::ReadKey($true)
    $selection = $key.KeyChar

    # Only allow single digit 0–9
    if ($selection -notmatch '^\d$') {
        Write-Host "`n❌ Invalid input — press 0–9 only." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        continue
    }

    $selInt = [int]$selection

    switch ($selInt) {
        0 {
            Write-Host "`nExiting... Goodbye!" -ForegroundColor Green
            break
        }
        9 {
            Show-SystemInfo
        }
        default {
            Download-And-Run -id $selInt
        }
    }
    Start-Sleep -Seconds 1
}
