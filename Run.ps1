# ==============================
# BLUE'S DIAGNOSTICS DASHBOARD
# JSON-driven version with System Info
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
# Show Menu
# ==============================
function Show-Menu {
    Clear-Host
    Write-Host "===================================="
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "===================================="
    Write-Host ""
    Write-Host "These diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!"
    Write-Host ""

    # Filter and sort only numeric keys
    $keys = $apps.PSObject.Properties.Name | Where-Object { $_ -match '^\d+$' } | Sort-Object { [int]$_ }

    foreach ($k in $keys) {
        $tool = $apps.$k
        Write-Host ("[{0}] {1}" -f $k, $tool.Name)
    }

    Write-Host "[9] System Information"
    Write-Host "[0] Exit"
    Write-Host ""
}

# ==============================
# Polished System Info Popup
# ==============================
function Show-SystemInfo {
    Add-Type -AssemblyName PresentationFramework

    $comp = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $proc = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $board = Get-CimInstance Win32_BaseBoard
    $os = Get-CimInstance Win32_OperatingSystem
    $disks = Get-PhysicalDisk | ForEach-Object { "$($_.FriendlyName) ($([math]::Round($_.Size / 1GB)) GB)" }

    $info = @(
        @{ Label = "Device Model"; Value = $comp.Model }
        @{ Label = "Serial Number"; Value = $bios.SerialNumber }
        @{ Label = "Processor"; Value = $proc.Name }
        @{ Label = "Memory (RAM)"; Value = ("{0} GB" -f [math]::Round($comp.TotalPhysicalMemory / 1GB)) }
        @{ Label = "Storage Drives"; Value = ($disks -join ", ") }
        @{ Label = "Graphics"; Value = $gpu.Name }
        @{ Label = "Motherboard"; Value = "$($board.Manufacturer) $($board.Product)" }
        @{ Label = "OS Version"; Value = "$($os.Caption) ($($os.BuildNumber))" }
    )

    $window = New-Object System.Windows.Window
    $window.Title = "🔍 System Information"
    $window.SizeToContent = "WidthAndHeight"
    $window.WindowStartupLocation = "CenterScreen"
    $window.Background = "#1E1E1E"
    $window.Foreground = "White"
    $window.FontFamily = "Segoe UI"
    $window.FontSize = 14
    $window.Padding = "15"
    $window.ResizeMode = "NoResize"

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "5"

    foreach ($item in $info) {
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Orientation = "Horizontal"
        $row.Margin = "0,3,0,3"

        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = "$($item.Label): "
        $label.FontWeight = "Bold"
        $label.Width = 180
        $label.Foreground = "LightSkyBlue"

        $value = New-Object System.Windows.Controls.TextBlock
        $value.Text = $item.Value
        $value.TextWrapping = "Wrap"
        $value.Width = 300

        $row.Children.Add($label)
        $row.Children.Add($value)
        $stack.Children.Add($row)
    }

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "OK"
    $btn.Width = 100
    $btn.Height = 32
    $btn.Margin = "0,15,0,0"
    $btn.HorizontalAlignment = "Center"
    $btn.FontWeight = "Bold"
    $btn.Add_Click({ $window.Close() })

    $stack.Children.Add($btn)
    $window.Content = $stack
    $window.ShowDialog() | Out-Null
}

# ==============================
# Download & Run (Smart Handling)
# ==============================
function Download-And-Run($tool) {
    try {
        $url = $tool.Url
        $name = $tool.Name
        $ext = [System.IO.Path]::GetExtension($url)

        $filePath = Join-Path $env:TEMP "$name$ext"

        if (-not (Test-Path $filePath)) {
            Write-Host "⬇️ Downloading $name..."
            Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing
        } else {
            Write-Host "✔️ $name already downloaded."
        }

        Write-Host "🚀 Launching $name..."
        switch ($ext) {
            ".exe" { Start-Process -FilePath $filePath }
            ".ps1" { Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$filePath`"" }
            ".cmd" { Start-Process "cmd.exe" -ArgumentList "/c `"$filePath`"" }
            default { Start-Process $filePath }
        }
    } catch {
        Write-Host ("❌ Error while launching {0}: {1}" -f $tool.Name, $_.Exception.Message) -ForegroundColor Red
    }
}

# ==============================
# Main Loop
# ==============================
while ($true) {
    Show-Menu
    Write-Host "Press a number key (0 to exit, 9 for System Info)..."
    $key = [System.Console]::ReadKey($true).KeyChar

    if ($key -eq '0') {
        Write-Host "`n✅ Exiting... Goodbye!" -ForegroundColor Green
        break
    }
    elseif ($key -eq '9') {
        Show-SystemInfo
    }
    elseif ($key -match '^\d+$') {
        $tool = $apps.$key
        if ($tool) {
            Download-And-Run $tool
            Start-Sleep -Seconds 2
        } else {
            Write-Host "`n❌ Invalid choice." -ForegroundColor Red
            Start-Sleep -Seconds 1.5
        }
    } else {
        Write-Host "`n⚠️ Invalid input. Try again." -ForegroundColor Yellow
        Start-Sleep -Seconds 1.5
    }
}
