# ====================================
#   BLUE'S DIAGNOSTICS DASHBOARD
# ====================================

$toolsJsonUrl = "https://github.com/BlueStreak79/Diagnostics/raw/main/tools.json"
$tempDir = "$env:TEMP\BlueDiag"
if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

function Download-And-Run($tool) {
    try {
        $FileName = [System.IO.Path]::GetFileName($tool.Url)
        $LocalPath = Join-Path $tempDir $FileName

        Write-Host "`n⚙️  Downloading $($tool.Name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $tool.Url -OutFile $LocalPath -ErrorAction Stop

        Write-Host "🚀 Launching $($tool.Name)..." -ForegroundColor Green

        # Determine file type
        $extension = [System.IO.Path]::GetExtension($FileName).ToLower()

        switch ($extension) {
            ".exe" {
                Start-Process $LocalPath
            }
            ".ps1" {
                Start-Job -ScriptBlock {
                    powershell -ExecutionPolicy Bypass -NoProfile -File $using:LocalPath
                } | Out-Null
            }
            ".cmd" {
                Start-Job -ScriptBlock {
                    cmd /c $using:LocalPath
                } | Out-Null
            }
            default {
                Write-Host "⚠️ Unknown file type: $extension" -ForegroundColor Yellow
            }
        }
    }
    catch {
        $errMsg = $_.Exception.Message
        if ($null -ne $FileName) {
            Write-Host ("❌ Error while launching {0}: {1}" -f $FileName, $errMsg) -ForegroundColor Red
        }
        else {
            Write-Host ("❌ Error while launching <unknown>: {0}" -f $errMsg) -ForegroundColor Red
        }
    }
}

try {
    Write-Host "Fetching tool list..." -ForegroundColor DarkCyan
    $apps = Invoke-RestMethod -Uri $toolsJsonUrl -ErrorAction Stop
}
catch {
    Write-Host "❌ Unable to fetch tool list from JSON file." -ForegroundColor Red
    exit
}

function Show-SystemInfo {
    Add-Type -AssemblyName System.Windows.Forms
    $info = Get-ComputerInfo | Select-Object CsName, WindowsProductName, WindowsVersion, OsArchitecture, CsManufacturer, CsModel, BiosVersion, BiosReleaseDate
    $message = $info | Out-String
    [System.Windows.Forms.MessageBox]::Show($message, "System Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Show-Menu {
    Clear-Host
    Write-Host "===================================="
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD"
    Write-Host "===================================="
    Write-Host ""
    Write-Host "These diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!"
    Write-Host ""

    foreach ($k in ($apps.PSObject.Properties.Name | Sort-Object { [int]$_ })) {
        $tool = $apps.$k
        Write-Host ("[{0}] {1}" -f $k, $tool.Name)
    }

    Write-Host "[9] System Information"
    Write-Host "[0] Exit"
    Write-Host ""
}

do {
    Show-Menu
    $choice = Read-Host "Press a number key (0 to exit, 9 for System Info)..."

    if ($choice -eq '0') {
        Write-Host "Exiting BlueDiag..." -ForegroundColor DarkGray
        break
    }
    elseif ($choice -eq '9') {
        Show-SystemInfo
    }
    elseif ($apps.PSObject.Properties.Name -contains $choice) {
        $tool = $apps.$choice
        Download-And-Run $tool
    }
    else {
        Write-Host "❌ Invalid selection. Try again." -ForegroundColor Red
    }

    Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
    Read-Host | Out-Null
}
while ($true)
