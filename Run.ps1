# ================================
# Diagnostics Dashboard Tool
# Created by Blue
# Final Version with Instant Keypress & Safety Fix
# ================================

# --------------------------------
# SECTION 1: Settings & Initialization
# --------------------------------
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$toolsUrl = "https://raw.githubusercontent.com/BlueStreak79/Diagnostics/main/tools.json"

$appsFallback = @(
    [PSCustomObject]@{ Id = 1; Name = "AquaKeyTest";     Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/AquaKeyTest.exe" },
    [PSCustomObject]@{ Id = 2; Name = "BatteryInfoView"; Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/BatteryInfoView.exe" },
    [PSCustomObject]@{ Id = 3; Name = "Camera";          Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/Camera.exe" },
    [PSCustomObject]@{ Id = 4; Name = "lusrmgr";         Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/lusrmgr.exe" },
    [PSCustomObject]@{ Id = 5; Name = "MemTest64";       Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/MemTest64.exe" },
    [PSCustomObject]@{ Id = 6; Name = "LCDtest";         Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/LCDtest.exe" },
    [PSCustomObject]@{ Id = 7; Name = "OemKey";          Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/OemKey.exe" },
    [PSCustomObject]@{ Id = 8; Name = "ShowKeyPlus";     Url = "https://github.com/BlueStreak79/Diagnostics/raw/refs/heads/main/ShowKeyPlus.exe" }
)

# --------------------------------
# SECTION 2: JSON Loader
# --------------------------------
function Normalize-Apps($raw) {
    $out = @()
    if ($null -eq $raw) { return $appsFallback }

    $numericProps = $raw.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
    if ($numericProps -and $numericProps.Count -gt 0) {
        foreach ($p in $numericProps) {
            $val = $p.Value
            $id  = [int]$p.Name
            $name = if ($val.PSObject.Properties.Name -contains 'Name') { $val.Name } else { $val.'name' }
            $url  = if ($val.PSObject.Properties.Name -contains 'Url')  { $val.Url }  else { $val.'url' }
            $out += [PSCustomObject]@{ Id = $id; Name = $name; Url = $url }
        }
        return $out | Sort-Object Id
    }

    if ($raw -is [System.Array]) {
        $idx = 1
        foreach ($item in $raw) {
            $id = if ($item.PSObject.Properties.Name -contains 'Id') { [int]$item.Id } else { $idx }
            $name = if ($item.PSObject.Properties.Name -contains 'Name') { $item.Name } else { $item.'name' }
            $url  = if ($item.PSObject.Properties.Name -contains 'Url')  { $item.Url }  else { $item.'url' }
            $out += [PSCustomObject]@{ Id = [int]$id; Name = $name; Url = $url }
            $idx++
        }
        return $out | Sort-Object Id
    }

    return $appsFallback
}

try {
    $raw = Invoke-RestMethod -Uri $toolsUrl -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "⚠️ Could not load tools.json. Using fallback list." -ForegroundColor Yellow
    $raw = $null
}
$apps = Normalize-Apps $raw

# --------------------------------
# SECTION 3: Dashboard Display
# --------------------------------
function Show-Dashboard {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "`nThese diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!`n"

    foreach ($a in $apps) {
        Write-Host ("{0,-3} {1}" -f ($a.Id + "."), $a.Name)
    }
    Write-Host "9. System Information"
    Write-Host "0. Exit (cleanup)"
}

# --------------------------------
# SECTION 4: Download & Run Tool
# --------------------------------
function Download-And-Run($id) {
    try {
        $app = $apps | Where-Object { $_.Id -eq $id }
        if (-not $app) { Write-Host "Invalid selection." -ForegroundColor Red; return }

        $FilePath = Join-Path $env:TEMP "$($app.Name).exe"
        if (-not (Test-Path $FilePath)) {
            Write-Host "⬇️ Downloading $($app.Name)..."
            Invoke-WebRequest -Uri $app.Url -OutFile $FilePath -UseBasicParsing -ErrorAction Stop
            Write-Host "Download completed."
        } else {
            Write-Host "✔️ $($app.Name) already in TEMP."
        }
        Write-Host "🚀 Launching $($app.Name)..."
        Start-Process -FilePath $FilePath
    } catch {
        Write-Error "Error with $($app.Name): $_"
    }
}

# --------------------------------
# SECTION 5: System Information Popup
# --------------------------------
function Show-SystemInfo {
    $comp  = Get-CimInstance Win32_ComputerSystem
    $bios  = Get-CimInstance Win32_BIOS
    $cpu   = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ram   = "{0:N0} GB" -f ($comp.TotalPhysicalMemory / 1GB)
    $board = Get-CimInstance Win32_BaseBoard

    $disks = @()
    try { $pd = Get-PhysicalDisk -ErrorAction Stop } catch { $pd = @() }
    $diskIndex = 1
    foreach ($d in $pd) {
        $disks += [PSCustomObject]@{ Name = "Disk$diskIndex ($($d.MediaType))"; Value = ("{0:N0} GB" -f ($d.Size / 1GB)) }
        $diskIndex++
    }
    if ($disks.Count -eq 0) {
        $drives = Get-CimInstance Win32_DiskDrive | Select-Object Model,Size
        $diskIndex = 1
        foreach ($d in $drives) {
            $sizeGB = if ($d.Size) { "{0:N0} GB" -f ($d.Size / 1GB) } else { "Unknown" }
            $disks += [PSCustomObject]@{ Name = "Disk$diskIndex ($($d.Model))"; Value = $sizeGB }
            $diskIndex++
        }
    }

    $gpus = Get-CimInstance Win32_VideoController | Select-Object Name
    $gpuList = @()
    $gpuIndex = 1
    foreach ($g in $gpus) {
        $gpuList += [PSCustomObject]@{ Name = "GPU$gpuIndex"; Value = $g.Name.Trim() }
        $gpuIndex++
    }

    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    if ($os -match "11") { $winver = "Windows 11" }
    elseif ($os -match "10") { $winver = "Windows 10" }
    else { $winver = $os }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "System Information"
    $form.Size = New-Object System.Drawing.Size(700,480)
    $form.StartPosition = "CenterScreen"
    $form.Topmost = $true

    $lv = New-Object System.Windows.Forms.ListView
    $lv.View = 'Details'
    $lv.FullRowSelect = $true
    $lv.GridLines = $true
    $lv.Dock = "Fill"
    $lv.Font = 'Segoe UI,10'
    $lv.Columns.Add("Property",220) | Out-Null
    $lv.Columns.Add("Value",440)   | Out-Null

    function Add-Row($n,$v) {
        $item = New-Object System.Windows.Forms.ListViewItem($n)
        $item.SubItems.Add([string]$v) | Out-Null
        $lv.Items.Add($item) | Out-Null
    }

    Add-Row "Serial Number"  $bios.SerialNumber
    Add-Row "Model"          $comp.Model
    Add-Row "Motherboard"    $board.Manufacturer
    Add-Row "Processor"      $cpu.Name
    foreach ($g in $gpuList) { Add-Row $g.Name $g.Value }
    Add-Row "RAM"            $ram
    foreach ($d in $disks) { Add-Row $d.Name $d.Value }
    Add-Row "Windows"        $winver

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Copy Info"
    $btn.Dock = "Bottom"
    $btn.Add_Click({
        $copyText = ($lv.Items | ForEach-Object {
            "$($_.Text) : $($_.SubItems[1].Text)"
        }) -join "`r`n"
        [System.Windows.Forms.Clipboard]::SetText($copyText)
        [System.Windows.Forms.MessageBox]::Show("System info copied to clipboard!","Copied")
    })

    $form.Controls.Add($lv)
    $form.Controls.Add($btn)
    $form.ShowDialog()
}

# --------------------------------
# SECTION 6: Main Loop with Safe Instant Keypress
# --------------------------------
while ($true) {
    Show-Dashboard
    Write-Host "`nPress a number key (0 to exit, 9 for System Info)..."

    $key = [System.Console]::ReadKey($true)
    $selection = $key.KeyChar

    # SAFETY CHECK — Only digits allowed
    if ($selection -notmatch '^\d$') {
        Write-Host "`n❌ Invalid input — please press a number key." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        continue
    }

    $selInt = [int]$selection

    if ($selInt -eq 0) {
        Write-Host "`nExiting... Goodbye!" -ForegroundColor Green
        break
    }
    if ($selInt -eq 9) {
        Show-SystemInfo
        continue
    }

    $appMatch = $apps | Where-Object { $_.Id -eq $selInt }
    if ($null -ne $appMatch) {
        Download-And-Run -id $selInt
    } else {
        Write-Host "`n❌ No tool with that ID." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 1
}
