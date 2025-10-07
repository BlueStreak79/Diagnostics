# ==============================
# BLUE'S DIAGNOSTICS DASHBOARD (Auto JSON Loader)
# ==============================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ==============================
# Load tools from JSON (local or remote)
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

    # Auto-list all tools from JSON
    $keys = $apps.PSObject.Properties.Name | Sort-Object {[int]($_ -replace '[^\d]', '0')}
    foreach ($k in $keys) {
        Write-Host "[$k] $($apps.$k.Name)"
    }

    Write-Host "[9] System Information"
    Write-Host "[0] Exit"
}

# ==============================
# System Info GUI Popup
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
    $window.Width = 500

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "10"
    $stack.Orientation = "Vertical"

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "0,0,0,10"
    $grid.HorizontalAlignment = "Stretch"

    $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))

    for ($i=0; $i -lt $info.Count; $i++) {
        $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))

        $propText = New-Object System.Windows.Controls.TextBlock
        $propText.Text = $info[$i].Property
        $propText.Margin = "5"
        $propText.FontWeight = "Bold"
        $propText.FontSize = 14
        $propText.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetRow($propText, $i)
        [System.Windows.Controls.Grid]::SetColumn($propText, 0)
        $grid.Children.Add($propText)

        $valText = New-Object System.Windows.Controls.TextBlock
        $valText.Text = $info[$i].Value
        $valText.Margin = "5"
        $valText.FontSize = 14
        $valText.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetRow($valText, $i)
        [System.Windows.Controls.Grid]::SetColumn($valText, 1)
        $grid.Children.Add($valText)
    }

    $stack.Children.Add($grid)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "OK"
    $btn.Width = 100
    $btn.Height = 30
    $btn.Margin = "0,10,0,0"
    $btn.HorizontalAlignment = "Center"
    $btn.FontWeight = "Bold"
    $btn.Add_Click({ $window.Close() })
    $stack.Children.Add($btn)

    $window.Content = $stack
    $window.ShowDialog() | Out-Null
}

# ==============================
# Download & Run (Smart File Handling)
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
        $ext = [System.IO.Path]::GetExtension($url)

        if ($url -match "^https://get\.activated\.win") {
            Write-Host "🚀 Launching MassGrave Activation..." -ForegroundColor Cyan
            Start-Job -ScriptBlock { Invoke-Expression -Command "irm https://get.activated.win | iex" } | Out-Null
            return
        }

        $filePath = Join-Path $env:TEMP "$name$ext"

        if ($ext -eq ".exe") {
            if (-not (Test-Path $filePath)) {
                Write-Host "⬇️ Downloading $name..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing
            }
            Write-Host "🚀 Launching $name..." -ForegroundColor Cyan
            Start-Process -FilePath $filePath
        }
        elseif ($ext -eq ".ps1" -or $ext -eq ".cmd") {
            Write-Host "⚙️ Running script $name..." -ForegroundColor Yellow
            $code = Invoke-RestMethod -Uri $url -UseBasicParsing
            Invoke-Expression $code
        }
        else {
            Write-Host "❓ Unknown file type for $name ($ext)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error while running $key: $_" -ForegroundColor Red
    }
}

# ==============================
# Main Loop
# ==============================
while ($true) {
    Show-Dashboard
    Write-Host "`nPress a key (0 to exit, 9 for System Info)..."

    $key = [System.Console]::ReadKey($true).KeyChar
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
        Write-Host "`nInvalid selection. Please choose a valid key." -ForegroundColor Red
        Start-Sleep -Seconds 1.5
    }
}
