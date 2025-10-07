# ===============================
#   BLUE'S DIAGNOSTICS DASHBOARD
# ===============================
#   Created by BlueStreak79
# ===============================

$ErrorActionPreference = "Stop"
$ToolsJsonUrl = "https://github.com/BlueStreak79/Diagnostics/raw/main/tools.json"
$ToolsFolder = "$env:TEMP\BlueDiagnostics"
if (!(Test-Path $ToolsFolder)) { New-Item -Path $ToolsFolder -ItemType Directory | Out-Null }

# --- Function: Download JSON & Parse ---
function Get-ToolsList {
    try {
        Write-Host "`n🔄 Fetching tools list..." -ForegroundColor Cyan
        $json = Invoke-RestMethod -Uri $ToolsJsonUrl -UseBasicParsing
        return $json
    }
    catch {
        Write-Host "❌ Failed to load tools list: $_" -ForegroundColor Red
        exit
    }
}

# --- Function: Download & Run any file ---
function Download-And-Run($tool) {
    try {
        $FileName = $tool.Name
        $Url = $tool.Url
        $FilePath = Join-Path $ToolsFolder $FileName

        # Determine extension
        $ext = [IO.Path]::GetExtension($FileName).ToLower()

        Write-Host "`n⬇️  Downloading $FileName ..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $FilePath -UseBasicParsing

        Write-Host "🚀 Launching $FileName..." -ForegroundColor Green

        switch ($ext) {
            ".exe" { Start-Process -FilePath $FilePath -Wait }
            ".ps1" { Start-Job -ScriptBlock { & powershell -ExecutionPolicy Bypass -File $using:FilePath } | Out-Null }
            ".cmd" { Start-Job -ScriptBlock { & cmd /c $using:FilePath } | Out-Null }
            default { Write-Host "⚠️ Unsupported file type: $ext" -ForegroundColor DarkYellow }
        }
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Host ("❌ Error while launching {0}: {1}" -f ($FileName ?? "<unknown>"), $errMsg) -ForegroundColor Red
    }
}

# --- Function: System Info Popup ---
function Show-SystemInfo {
    Add-Type -AssemblyName PresentationFramework
    $sys = Get-ComputerInfo | Select-Object CsName, WindowsProductName, OsArchitecture, CsManufacturer, CsModel, CsTotalPhysicalMemory
    $info = @"
System Name: $($sys.CsName)
Product:     $($sys.WindowsProductName)
Architecture:$($sys.OsArchitecture)
Manufacturer:$($sys.CsManufacturer)
Model:       $($sys.CsModel)
RAM:         $([math]::Round($sys.CsTotalPhysicalMemory / 1GB, 2)) GB
"@
    [System.Windows.MessageBox]::Show($info, "🖥️ System Information")
}

# --- Load Tools ---
$apps = Get-ToolsList

# --- Display Menu ---
function Show-Menu {
    Clear-Host
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "   BLUE'S DIAGNOSTICS DASHBOARD" -ForegroundColor Blue
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "`nThese diagnostics are created by Blue..."
    Write-Host "Unlocking system secrets with just one click!`n" -ForegroundColor Yellow

    foreach ($key in ($apps.PSObject.Properties.Name | Sort-Object {[int]($_ -replace '\D','') -as [int]})) {
        $tool = $apps.$key
        Write-Host "[$key] $($tool.Name)"
    }

    Write-Host "`n[9] System Information"
    Write-Host "[0] Exit"
    Write-Host ""
}

# --- Main Loop ---
do {
    Show-Menu
    $choice = Read-Host "Press a number key (0 to exit, 9 for System Info)"

    switch ($choice) {
        "0" { break }
        "9" { Show-SystemInfo }
        default {
            if ($apps.PSObject.Properties.Name -contains $choice) {
                Download-And-Run $apps.$choice
            }
            else {
                Write-Host "⚠️ Invalid choice, try again!" -ForegroundColor DarkYellow
            }
        }
    }

    Pause
} while ($true)

Write-Host "`n👋 Exiting Blue's Diagnostics Dashboard..." -ForegroundColor Cyan
