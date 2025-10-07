# ====================================
#   BLUE'S DIAGNOSTICS DASHBOARD-2
# ====================================

$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------------------------
# Load Tools from JSON
# ---------------------------
$toolsJsonUrl = "https://github.com/BlueStreak79/Diagnostics/raw/main/tools.json"
try {
    $json = Invoke-RestMethod -Uri $toolsJsonUrl -UseBasicParsing
    if (-not $json) { throw "Tools list is empty or invalid." }
} catch {
    Write-Host "❌ Failed to load tools.json: $_" -ForegroundColor Red
    exit
}

# ---------------------------
# Download & Run Function
# ---------------------------
function Download-And-Run($tool) {
    try {
        $url = $tool.Url
        $name = $tool.Name
        $type = if ($tool.Type) { $tool.Type.ToLower() } else { "exe" }

        $temp = "$env:TEMP\$name.$type"

        Write-Host "`n⏳ Downloading $name..."
        Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing

        if (-not (Test-Path $temp)) { throw "Download failed." }

        Write-Host "🚀 Launching $name..." -ForegroundColor Cyan

        switch ($type) {
            "exe" { Start-Process $temp }
            "ps1" { Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$temp`"" }
            "cmd" { Start-Process cmd.exe -ArgumentList "/c `"$temp`"" }
            default { Write-Host "❓ Unknown file type: $type" -ForegroundColor Yellow }
        }
    }
    catch {
        $toolName = if ($name) { $name } else { "<unknown>" }
        Write-Host ("❌ Error while launching {0}: {1}" -f $toolName, $_) -ForegroundColor Red
    }
}

# ---------------------------
# System Info Popup
# ---------------------------
function Show-SystemInfo {
    Add-Type -AssemblyName PresentationFramework

    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $board = Get-CimInstance Win32_BaseBoard
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1)
    $bios = Get-CimInstance Win32_BIOS
    $disks = Get-PhysicalDisk | ForEach-Object { "$($_.FriendlyName) ($([math]::Round($_.Size/1GB)) GB)" }

    $info = @"
💻 SYSTEM INFORMATION
────────────────────────────
Computer Name: $env:COMPUTERNAME
Model: $((Get-CimInstance Win32_ComputerSystem).Model)
Serial Number: $($bios.SerialNumber)
Motherboard: $($board.Manufacturer) - $($board.Product)
CPU: $($cpu.Name)
RAM: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)) GB
Storage: $($disks -join ", ")
GPU: $($gpu.Name)
OS: $($os.Caption)
Version: $($os.Version)
Architecture: $env:PROCESSOR_ARCHITECTURE
"@

    [System.Windows.MessageBox]::Show($info, "System Information", "OK", "Info") | Out-Null
}

# ---------------------------
# Menu Display
# ---------------------------
function Show-Menu {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "These diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!"
    Write-Host ""

    # Sort alphabetic + numeric keys properly
    $keys = ($json.PSObject.Properties.Name | Sort-Object { if ($_ -match '^\d+$') { [int]$_ } else { $_ } })

    foreach ($k in $keys) {
        $t = $json.$k
        Write-Host "[$k] $($t.Name)"
    }

    Write-Host "[9] System Information"
    Write-Host "[0] Exit"
    Write-Host ""
}

# ---------------------------
# Main Loop
# ---------------------------
while ($true) {
    Show-Menu
    $choice = Read-Host "Press a key (0 to Exit, 9 for System Info)"

    switch ($choice) {
        "0" { Write-Host "`n✅ Exiting... Goodbye!" -ForegroundColor Green; Start-Sleep 1; exit }
        "9" { Show-SystemInfo }
        default {
            if ($json.$choice) {
                Download-And-Run $json.$choice
            } else {
                Write-Host "❌ Invalid choice, try again." -ForegroundColor Red
            }
        }
    }

    Write-Host "`nPress ENTER to return to menu..."
    Read-Host
}
