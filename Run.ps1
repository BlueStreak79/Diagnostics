# ====================================
#   BLUE'S DIAGNOSTICS DASHBOARD-1
# ====================================

Clear-Host
Write-Host "===================================="
Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
Write-Host "===================================="
Write-Host ""
Write-Host "These diagnostics are created by Blue..."
Write-Host "Unlocking system secrets with just one click!"
Write-Host ""

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
# Show System Info Popup
# ---------------------------
function Show-SystemInfo {
    Add-Type -AssemblyName PresentationFramework
    $sysinfo = @(
        "System: $env:COMPUTERNAME",
        "User: $env:USERNAME",
        "Windows: $((Get-CimInstance Win32_OperatingSystem).Caption)",
        "Version: $((Get-CimInstance Win32_OperatingSystem).Version)",
        "Architecture: $env:PROCESSOR_ARCHITECTURE",
        "CPU: $((Get-CimInstance Win32_Processor).Name)",
        "RAM: $([math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB,2)) GB"
    ) -join "`n"

    [System.Windows.MessageBox]::Show($sysinfo, "💻 System Information", "OK", "Info")
}

# ---------------------------
# Menu Loop
# ---------------------------
function Show-Menu {
    while ($true) {
        Write-Host ""
        Write-Host "===================================="
        Write-Host "Available Tools:"
        Write-Host "===================================="

        # Sort keys A-Z then 0-9
        $keys = ($json.PSObject.Properties.Name | Sort-Object { if ($_ -match '^\d+$') { [int]$_ } else { [string]$_ } })
        foreach ($k in $keys) {
            $t = $json.$k
            Write-Host "[$k] $($t.Name)"
        }

        Write-Host "[9] System Information"
        Write-Host "[0] Exit"
        Write-Host ""
        $choice = Read-Host "Press a key (0 to Exit, 9 for System Info)"

        switch ($choice) {
            "0" { exit }
            "9" { Show-SystemInfo }
            default {
                if ($json.$choice) {
                    Download-And-Run $json.$choice
                } else {
                    Write-Host "❌ Invalid choice, try again." -ForegroundColor Red
                }
            }
        }
    }
}

Show-Menu
