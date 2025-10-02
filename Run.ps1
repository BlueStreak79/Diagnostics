# ==========================
# Diagnostics Dashboard Tool (robust JSON loader + ListView System Info)
# ==========================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# URL to your tools.json (raw)
$toolsUrl = "https://raw.githubusercontent.com/BlueStreak79/Diagnostics/main/tools.json"

# Fallback app list (used if JSON can't be loaded)
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

# --- Load JSON (best-effort) ---
try {
    $raw = Invoke-RestMethod -Uri $toolsUrl -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "⚠️  Could not load tools.json from GitHub. Using local fallback list." -ForegroundColor Yellow
    $raw = $null
}

# --- Normalize into array of objects with numeric Id, Name, Url ---
function Normalize-Apps($raw) {
    $out = @()
    if ($null -eq $raw) {
        return $appsFallback
    }

    # Case A: JSON is an object with numeric property names (e.g. { "1": {...}, "2": {...} })
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

    # Case B: JSON is an array of objects
    if ($raw -is [System.Array]) {
        $idx = 1
        foreach ($item in $raw) {
            # If item already has Id, respect it; otherwise assign sequential id using index
            $id = if ($item.PSObject.Properties.Name -contains 'Id') { [int]$item.Id } else { $idx }
            $name = if ($item.PSObject.Properties.Name -contains 'Name') { $item.Name } else { $item.'name' }
            $url  = if ($item.PSObject.Properties.Name -contains 'Url')  { $item.Url }  else { $item.'url' }
            $out += [PSCustomObject]@{ Id = [int]$id; Name = $name; Url = $url }
            $idx++
        }
        return $out | Sort-Object Id
    }

    # Unknown structure: fallback
    return $appsFallback
}

$apps = Normalize-Apps $raw

# --- UI & functions ---
function Show-Dashboard {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "`nThese diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!`n"

    foreach ($a in $apps) {
        Write-Host ("{0,-3} {1}" -f ($a.Id + ".") , $a.Name)
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
            Write-Host "⬇️ Downloading $($app.Name)..."
            Invoke-WebRequest -Uri $app.Url -OutFile $FilePath -UseBasicParsing -ErrorAction Stop
            Write-Host "Download completed."
        } else {
            Write-Host "✔️ $($app.Name) already in TEMP. Skipping download."
        }
        Write-Host "🚀 Launching $($app.Name)..."
        Start-Process -FilePath $FilePath
        Write-Host "$($app.Name) started.`n"
    } catch {
        Write-Error "Error with $($app.Name): $_"
    }
}

# System Info (ListView) - GPU and Disks expanded
function Show-SystemInfo {
    # --- Collect system info ---
    $comp  = Get-CimInstance Win32_ComputerSystem
    $bios  = Get-CimInstance Win32_BIOS
    $cpu   = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ram   = "{0:N0} GB" -f ($comp.TotalPhysicalMemory / 1GB)
    $board = Get-CimInstance Win32_BaseBoard

    # Disks (split into Disk1, Disk2...)
    $disks = @()
    try { $pd = Get-PhysicalDisk -ErrorAction Stop } catch { $pd = @() }
    $diskIndex = 1
    foreach ($d in $pd) {
        $disks += [PSCustomObject]@{ Name = "Disk$diskIndex ($($d.MediaType))"; Value = ("{0:N0} GB" -f ($d.Size / 1GB)) }
        $diskIndex++
    }
    # if Get-PhysicalDisk returns nothing (older OS), fallback to Win32_DiskDrive
    if ($disks.Count -eq 0) {
        $drives = Get-CimInstance Win32_DiskDrive | Select-Object Model,Size
        $diskIndex = 1
        foreach ($d in $drives) {
            $sizeGB = if ($d.Size) { "{0:N0} GB" -f ($d.Size / 1GB) } else { "Unknown" }
            $disks += [PSCustomObject]@{ Name = "Disk$diskIndex ($($d.Model -replace '\s+',' '))"; Value = $sizeGB }
            $diskIndex++
        }
    }

    # GPU(s)
    $gpusRaw = Get-CimInstance Win32_VideoController | Select-Object Name
    $gpuList = @()
    $gpuIndex = 1
    foreach ($g in $gpusRaw) {
        $gpuList += [PSCustomObject]@{ Name = "GPU$gpuIndex"; Value = $g.Name.Trim() }
        $gpuIndex++
    }

    # Windows version
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    if ($os -match "11") { $winver = "Windows 11" }
    elseif ($os -match "10") { $winver = "Windows 10" }
    else { $winver = $os }

    # --- Build UI ---
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

    # Copy Info button
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

# ==========================
# Main Loop (robust selection handling)
# ==========================
while ($true) {
    Show-Dashboard
    $selection = Read-Host "Select a diagnostic tool (number) or 0 to exit"
    $selection = $selection.Trim()

    if ($selection -eq '0') {
        Write-Host "Exiting... Goodbye!" -ForegroundColor Green
        Start-Sleep -Seconds 1
        exit
    }

    if ($selection -eq '9') {
        Show-SystemInfo
        continue
    }

    # Try parse as integer
    $selRef = 0
    if (-not [int]::TryParse($selection, [ref]$selRef)) {
        Write-Host "❌ Please enter a numeric ID (available: $(( $apps | ForEach-Object { $_.Id }) -join ', ' ) or 9 for System Info)." -ForegroundColor Yellow
        Start-Sleep -Seconds 1.5
        continue
    }
    $selInt = [int]$selRef

    $appMatch = $apps | Where-Object { $_.Id -eq $selInt }
    if ($null -ne $appMatch) {
        Download-And-Run -id $selInt
        Start-Sleep -Seconds 1.5
        continue
    } else {
        Write-Host "❌ No tool found with ID $selInt. Available IDs: $(( $apps | ForEach-Object { $_.Id }) -join ', ' ) and 9 for System Info." -ForegroundColor Yellow
        Start-Sleep -Seconds 1.5
        continue
    }
}
