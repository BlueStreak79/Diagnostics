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
$apps = @(
    @{ Id = 1; Name = "AquaKeyTest";      Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/AquaKeyTest.exe" }
    @{ Id = 2; Name = "BatteryInfoView";  Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/BatteryInfoView.exe" }
    @{ Id = 3; Name = "Camera";           Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/Camera.exe" }
    @{ Id = 4; Name = "lusrmgr";          Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/lusrmgr.exe" }
    @{ Id = 5; Name = "MemTest64";        Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/MemTest64.exe" }
    @{ Id = 6; Name = "LCDtest";          Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/LCDtest.exe" }
    @{ Id = 7; Name = "OemKey";           Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/OemKey.exe" }
    @{ Id = 8; Name = "ShowKeyPlus";      Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/ShowKeyPlus.exe" }
)

# ==========================
# Functions
# ==========================

function Show-Dashboard {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "`nThese diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!`n"
    foreach ($app in $apps) {
        Write-Host "$($app.Id). $($app.Name)"
    }
    Write-Host "9. System Information"
    Write-Host "0. Exit (cleanup)"
}

function Download-And-Run($id) {
    try {
        $app = $apps | Where-Object { $_.Id -eq $id }
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

function Show-SystemInfo {
    # --- Collect system info ---
    $comp = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $cpu  = Get-CimInstance Win32_Processor
    $ram  = "{0:N0} GB" -f ($comp.TotalPhysicalMemory / 1GB)

    # Disks
    $disks = Get-PhysicalDisk | Select-Object MediaType, Size
    $diskInfo = ""
    foreach ($d in $disks) {
        $diskInfo += "$($d.MediaType): {0:N0} GB`n" -f ($d.Size / 1GB)
    }

    # GPU(s)
    $gpus = Get-CimInstance Win32_VideoController | Select-Object Name
    $gpuInfo = ($gpus | ForEach-Object { $_.Name }) -join "`n"

    # Windows version
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    if ($os -match "11") { $winver = "Windows 11" }
    elseif ($os -match "10") { $winver = "Windows 10" }
    else { $winver = $os }

    # Motherboard
    $board = Get-CimInstance Win32_BaseBoard

    # Prepare text
    $info = @"
Serial No    : $($bios.SerialNumber)
Model        : $($comp.Model)
Motherboard  : $($board.Manufacturer)
Processor    : $($cpu.Name)
GPU(s)       :
$gpuInfo

RAM          : $ram
Disks        :
$diskInfo
Windows      : $winver
"@

    # --- Create Popup ---
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "System Information"
    $form.StartPosition = "CenterScreen"
    $form.Topmost = $true

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Multiline = $true
    $txt.ReadOnly = $true
    $txt.ScrollBars = "Vertical"
    $txt.Font = 'Consolas,10'
    $txt.Text = $info
    $txt.Dock = "Fill"

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Copy Info"
    $btn.Dock = "Bottom"
    $btn.Add_Click({
        [System.Windows.Forms.Clipboard]::SetText($info)
        [System.Windows.Forms.MessageBox]::Show("System info copied to clipboard!","Copied")
    })

    # Dynamically adjust size based on content length
    $lines = ($info -split "`n").Count
    $height = [Math]::Min(600, 120 + ($lines * 18)) # max height 600px
    $form.Size = New-Object System.Drawing.Size(500,$height)

    $form.Controls.Add($txt)
    $form.Controls.Add($btn)
    $form.ShowDialog()
}

# ==========================
# Main Loop
# ==========================
while ($true) {
    Show-Dashboard
    $selection = Read-Host "Select a diagnostic tool (0 to exit)"
    $selection = $selection.Trim()

    if ($selection -eq '0') {
        Write-Host "Exiting and closing window..." -ForegroundColor Green
        Start-Sleep -Seconds 1
        exit
    }
    elseif ($selection -match '^[1-8]$') {
        Download-And-Run -id [int]$selection
        Start-Sleep -Seconds 2
    }
    elseif ($selection -eq '9') {
        Show-SystemInfo
    }
    else {
        Write-Host "Invalid selection. Please choose a valid number." -ForegroundColor Red
        Start-Sleep -Seconds 1.5
    }
}
