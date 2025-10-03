# ============================================
# Blue's Diagnostics Dashboard
# Rewritten & Clean Version
# ============================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# --------------------------------------------
# SECTION 1: Default App List (Fallback)
# --------------------------------------------
$appsFallback = @(
    @{ Id = 1; Name = "AquaKeyTest";     Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/AquaKeyTest.exe" },
    @{ Id = 2; Name = "BatteryInfoView"; Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/BatteryInfoView.exe" },
    @{ Id = 3; Name = "Camera";          Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/Camera.exe" },
    @{ Id = 4; Name = "lusrmgr";         Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/lusrmgr.exe" },
    @{ Id = 5; Name = "MemTest64";       Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/MemTest64.exe" },
    @{ Id = 6; Name = "LCDtest";         Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/LCDtest.exe" },
    @{ Id = 7; Name = "OemKey";          Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/OemKey.exe" },
    @{ Id = 8; Name = "ShowKeyPlus";     Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/ShowKeyPlus.exe" }
) | ForEach-Object { [PSCustomObject]$_ }

# --------------------------------------------
# SECTION 2: Load App List from JSON (or fallback)
# --------------------------------------------
function Get-AppList {
    $jsonUrl = "https://raw.githubusercontent.com/BlueStreak79/Diagnostics/main/tools.json"
    try {
        $raw = Invoke-RestMethod -Uri $jsonUrl -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "⚠️ Could not load tools.json. Using fallback list." -ForegroundColor Yellow
        return $appsFallback
    }

    if ($raw -is [System.Array]) {
        return $raw | ForEach-Object {
            [PSCustomObject]@{ Id = $_.Id; Name = $_.Name; Url = $_.Url }
        }
    }

    if ($raw.PSObject.Properties.Name -match '^\d+$') {
        return $raw.PSObject.Properties | ForEach-Object {
            [PSCustomObject]@{ Id = [int]$_.Name; Name = $_.Value.Name; Url = $_.Value.Url }
        }
    }

    return $appsFallback
}

$apps = Get-AppList

# --------------------------------------------
# SECTION 3: Dashboard UI
# --------------------------------------------
function Show-Dashboard {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "`nUnlocking system secrets with just one click!`n"

    foreach ($a in $apps | Sort-Object Id) {
        Write-Host ("{0}. {1}" -f $a.Id, $a.Name)
    }
    Write-Host "9. System Information"
    Write-Host "0. Exit"
}

# --------------------------------------------
# SECTION 4: Download & Run App
# --------------------------------------------
function Download-And-Run($id) {
    $app = $apps | Where-Object { $_.Id -eq $id }
    if (-not $app) { return }

    $path = Join-Path $env:TEMP "$($app.Name).exe"

    if (-not (Test-Path $path)) {
        Write-Host "⬇️ Downloading $($app.Name)..."
        Invoke-WebRequest -Uri $app.Url -OutFile $path -UseBasicParsing -ErrorAction Stop
        Write-Host "✔️ Download completed."
    }

    Write-Host "🚀 Launching $($app.Name)..."
    Start-Process -FilePath $path
}

# --------------------------------------------
# SECTION 5: System Information Popup
# --------------------------------------------
function Show-SystemInfo {
    $comp  = Get-CimInstance Win32_ComputerSystem
    $bios  = Get-CimInstance Win32_BIOS
    $cpu   = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ram   = "{0:N0} GB" -f ($comp.TotalPhysicalMemory / 1GB)
    $board = Get-CimInstance Win32_BaseBoard
    $os    = (Get-CimInstance Win32_OperatingSystem).Caption
    $winver = if ($os -match "11") { "Windows 11" } elseif ($os -match "10") { "Windows 10" } else { $os }

    $disks = Get-CimInstance Win32_DiskDrive | ForEach-Object {
        [PSCustomObject]@{ Name = $_.Model; Size = "{0:N0} GB" -f ($_.Size / 1GB) }
    }

    $gpus = Get-CimInstance Win32_VideoController | Select-Object Name

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object Windows.Forms.Form
    $form.Text = "System Information"
    $form.Size = New-Object Drawing.Size(700,480)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true

    $lv = New-Object Windows.Forms.ListView
    $lv.View = 'Details'
    $lv.FullRowSelect = $true
    $lv.GridLines = $true
    $lv.Dock = "Fill"
    $lv.Font = 'Segoe UI,10'
    $lv.Columns.Add("Property",220) | Out-Null
    $lv.Columns.Add("Value",440)   | Out-Null

    function Add-Row($name,$value) {
        $item = New-Object Windows.Forms.ListViewItem($name)
        $item.SubItems.Add([string]$value) | Out-Null
        $lv.Items.Add($item) | Out-Null
    }

    Add-Row "Serial Number"  $bios.SerialNumber
    Add-Row "Model"          $comp.Model
    Add-Row "Motherboard"    $board.Manufacturer
    Add-Row "Processor"      $cpu.Name
    foreach ($g in $gpus) { Add-Row "GPU" $g.Name }
    Add-R
