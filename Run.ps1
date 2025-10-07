# ==============================
# BLUE'S DIAGNOSTICS DASHBOARD
# Universal key (numbers + letters) + Smart Launcher
# ==============================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ==============================
# Load app list from JSON
# ==============================
$toolsUrl = "https://github.com/BlueStreak79/Diagnostics/raw/main/tools.json"
try {
    $apps = Invoke-RestMethod -Uri $toolsUrl -UseBasicParsing
} catch {
    Write-Host "❌ Failed to load tools list from GitHub." -ForegroundColor Red
    exit
}

# ==============================
# Show Dashboard
# ==============================
function Show-Dashboard {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "`nThese diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!`n"

    $keys = $apps.PSObject.Properties.Name | Sort-Object

    foreach ($k in $keys) {
        Write-Host "[$k] $($apps.$k.Name)"
    }

    Write-Host "[9] System Information"
    Write-Host "[0] Exit"
}

# ==============================
# System Info (Polished GUI)
# ==============================
function Show-SystemInfo {
    Add-Type -AssemblyName PresentationFramework

    $osVersion = (Get-ComputerInfo).WindowsProductName
    $winVer = if ($osVersion -match "Windows 11") { "Windows 11" } else { "Windows 10" }

    $diskInfo = Get-PhysicalDisk | ForEach-Object { "$($_.FriendlyName) ($([math]::Round($_.Size/1GB)) GB)" }
    $gpuInfo = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name

    $info = @(
        @{Property="Serial Number"; Value=(Get-CimInstance Win32_BIOS).SerialNumber}
        @{Property="Model"; Value=(Get-CimInstance Win32_ComputerSystem).Model}
        @{Property="Processor"; Value=(Get-CimInstance Win32_Processor).Name}
        @{Property="RAM"; Value=("{0} GB" -f [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB))}
        @{Property="Storage"; Value=($diskInfo -join ", ")}
        @{Property="GPU"; Value=$gpuInfo}
        @{Property="Windows Version"; Value=$winVer}
        @{Property="Motherboard"; Value=(Get-CimInstance Win32_BaseBoard).Manufacturer}
    )

    $window = New-Object System.Windows.Window
    $window.Title = "System Information"
    $window.SizeToContent = "WidthAndHeight"
    $window.WindowStartupLocation = "CenterScreen"
    $window.ResizeMode = "NoResize"
    $window.Background = "#1E1E1E"
    $window.Foreground = "White"
    $window.FontFamily = "Segoe UI"
    $window.Width = 520

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "15"

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "0,0,0,10"
    $grid.HorizontalAlignment = "Stretch"

    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = "180"
    $col2 = New-Object System.Windows.Controls.ColumnDefinition
    $col2.Width = "300"
    $grid.ColumnDefinitions.Add($col1)
    $grid.ColumnDefinitions.Add($col2)

    for ($i=0; $i -lt $info.Count; $i++) {
        $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))

        $propText = New-Object System.Windows.Controls.TextBlock
        $propText.Text = $info[$i].Property
        $propText.Margin = "5"
        $propText.FontWeight = "Bold"
        $propText.FontSize = 14
        $propText.Foreground = "LightBlue"
        [System.Windows.Controls.Grid]::SetRow($propText, $i)
        [System.Windows.Controls.Grid]::SetColumn($propText, 0)
        $grid.Children.Add($propText)

        $valText = New-Object System.Windows.Controls.TextBlock
        $valText.Text = $info[$i].Value
        $valText.Margin = "5"
        $valText.FontSize = 14
        $valText.Foreground = "White"
        [System.Windows.Controls.Grid]::SetRow($valText, $i)
        [System.Windows.Controls.Grid]::SetColumn($valText, 1)
        $grid.Children.Add($valText)
    }

    $stack.Children.Add($grid)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "OK"
    $btn.Width = 100
    $btn.Height = 32
    $btn.Margin = "0,10,0,0"
    $btn.HorizontalAlignment = "Center"
    $btn.FontWeight = "Bold"
    $btn.Background = "#0078D7"
    $btn.Foreground = "White"
    $btn.Add_Click({ $window.Close() })
    $stack.Children.Add($btn)

    $window.Content = $stack
    $window.ShowDialog() | Out-Null
}

# ==============================
# Smart Downloader & Executor
# ==============================
function Download-And-Run($key) {
    try {
        $app = $apps.$key
        if (-not $app) {
            Write-Host "❌ Invalid selection." -ForegroundColor Red
            return
        }

        $url = $app.Url
        $name = $app.Name
        $extension = [System.IO.Path]::GetExtension($url)

        $FilePath = Join-Path $env:TEMP "$name$extension"
        if (-not (Test-Path $FilePath)) {
            Write-Host "⬇️ Downloading $name..."
            Invoke-WebRequest -Uri $url -OutFile $FilePath -UseBasicParsing
        } else {
            Write-Host "✔️ $name already exists in TEMP."
        }

        if ($extension -eq ".ps1") {
            Write-Host "🚀 Executing PowerShell script $name..."
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$FilePath`""
        } elseif ($extension -eq ".exe") {
            Write-Host "🚀 Launching executable $name..."
            Start-Process -FilePath $FilePath
        } elseif ($extension -eq ".cmd") {
            Write-Host "🚀 Launching executable $name..."
            Start-Process "cmd.exe" -ArgumentList "/c `"$TempPath`""

        } else {
            Write-Host "🌐Opening Link In Browser"
            Start-Process $url
        }
    }
    catch {
        Write-Host ("❌ Error while launching {0}: {1}" -f $key, $_.Exception.Message) -ForegroundColor Red
    }
}

# ==============================
# Main Loop (Letter + Number Input)
# ==============================
while ($true) {
    Show-Dashboard
    Write-Host "`nPress a key (0 to exit, 9 for System Info)..."

    $key = [System.Console]::ReadKey($true).KeyChar.ToString().ToUpper()

    if ($key -eq '0') {
        Write-Host "`n✅ Exiting... Goodbye!" -ForegroundColor Green
        Start-Sleep -Seconds 1
        exit
    }
    elseif ($key -eq '9') {
        Show-SystemInfo
    }
    elseif ($apps.PSObject.Properties.Name -contains $key) {
        Download-And-Run -key $key
        Start-Sleep -Seconds 2
    }
    else {
        Write-Host "`n⚠️ Invalid input. Try again." -ForegroundColor Yellow
        Start-Sleep -Seconds 1.5
    }
}
