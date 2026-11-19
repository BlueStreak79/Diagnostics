<#
.SYNOPSIS
    Fully unattended WinGet (App Installer) installer for Windows 10 (1809+) and Windows 11.

.DESCRIPTION
    - Runs elevated (self-elevates; use -NoElevate to fail instead of prompting UAC)
    - Forces Windows PowerShell 5.1 (Appx cmdlets need it)
    - Forces TLS 1.2 / 1.3
    - Zero prompts: no Read-Host, no confirmations, progress bar off
    - Downloads: msixbundle + VCLibs + UI.Xaml from official Microsoft/GitHub/NuGet links
    - Multiple download methods (Invoke-WebRequest -> BITS -> WebClient) with retries
    - Multiple fallbacks (Dependencies zip -> direct appx -> NuGet -> PSGallery WinGet module)
    - Provisions for all users + registers for current user
    - Verifies winget actually runs, accepts source agreements, refreshes sources
    - Log + transcript in C:\ProgramData\WingetSetup\Logs

.PARAMETER Force
    Reinstall even if winget already works.
.PARAMETER NoElevate
    Do not try to self-elevate; exit with code 5 if not admin.
.PARAMETER SkipSourceUpdate
    Skip "winget source update" at the end.
.PARAMETER WorkDir
    Temp download folder.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Winget.ps1

.NOTES
    Exit codes: 0 OK | 1 failed | 3 OS too old | 5 not admin | 6 script not saved to disk
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$NoElevate,
    [switch]$SkipSourceUpdate,
    [string]$WorkDir = (Join-Path $env:TEMP 'WingetSetup')
)

# ============================================================================
# 0. ELEVATION + POWERSHELL 5.1 ENFORCEMENT
# ============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -or $PSVersionTable.PSEdition -eq 'Core') {
    if (-not $isAdmin -and $NoElevate) {
        Write-Error 'Administrator rights are required (-NoElevate was specified).'
        exit 5
    }
    if (-not $PSCommandPath) {
        Write-Error 'Save this script to a .ps1 file and run it from disk (cannot self-elevate from memory).'
        exit 6
    }
    $argList = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Force)            { $argList += '-Force' }
    if ($SkipSourceUpdate) { $argList += '-SkipSourceUpdate' }
    if ($WorkDir)          { $argList += @('-WorkDir', "`"$WorkDir`"") }

    $sp = @{
        FilePath     = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        ArgumentList = $argList
        Wait         = $true
        PassThru     = $true
    }
    if (-not $isAdmin) { $sp['Verb'] = 'RunAs' } else { $sp['NoNewWindow'] = $true }
    try {
        $p = Start-Process @sp
        exit $p.ExitCode
    } catch {
        Write-Error "Elevation failed or was declined: $($_.Exception.Message)"
        exit 5
    }
}

# ============================================================================
# 1. ENVIRONMENT HARDENING
# ============================================================================
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # huge speed-up for Invoke-WebRequest on PS 5.1
$ConfirmPreference     = 'None'
$WarningPreference     = 'Continue'

# TLS 1.2 (+1.3 where the OS supports it)
try {
    $proto = [Net.SecurityProtocolType]::Tls12
    try { $proto = $proto -bor [Net.SecurityProtocolType]::Tls13 } catch { }
    [Net.ServicePointManager]::SecurityProtocol = $proto
} catch {
    [Net.ServicePointManager]::SecurityProtocol = 3072   # raw Tls12 value
}
[Net.ServicePointManager]::Expect100Continue = $false
[Net.ServicePointManager]::DefaultConnectionLimit = 16

# Logging
$LogDir  = Join-Path $env:ProgramData 'WingetSetup\Logs'
$null = New-Item -ItemType Directory -Path $LogDir  -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $WorkDir -Force -ErrorAction SilentlyContinue
$Stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile = Join-Path $LogDir "Install-Winget-$Stamp.log"
try { Start-Transcript -Path (Join-Path $LogDir "Transcript-$Stamp.txt") -Force | Out-Null } catch { }

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','OK','WARN','ERROR')][string]$Level = 'INFO')
    $line = '[{0}] [{1,-5}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    $color = switch ($Level) { 'OK' {'Green'} 'WARN' {'Yellow'} 'ERROR' {'Red'} default {'Gray'} }
    Write-Host $line -ForegroundColor $color
    try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch { }
}

# ============================================================================
# 2. DOWNLOAD LINKS (official sources)
# ============================================================================
$Url = @{
    # Latest App Installer / winget bundle
    Bundle      = @(
        'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle',
        'https://aka.ms/getwinget'
    )
    # Official dependency pack (contains x64 / x86 / arm64 VCLibs + UI.Xaml)
    DepsZip     = @(
        'https://github.com/microsoft/winget-cli/releases/latest/download/DesktopAppInstaller_Dependencies.zip'
    )
    # Direct fallbacks per dependency
    VCLibs_x64  = @('https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx')
    VCLibs_x86  = @('https://aka.ms/Microsoft.VCLibs.x86.14.00.Desktop.appx')
    VCLibs_arm64= @('https://aka.ms/Microsoft.VCLibs.arm64.14.00.Desktop.appx')
    UIXaml_Nupkg= @(
        'https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6',
        'https://globalcdn.nuget.org/packages/microsoft.ui.xaml.2.8.6.nupkg'
    )
    UIXaml_Direct = @{
        x64   = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'
        x86   = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x86.appx'
        arm64 = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.arm64.appx'
    }
}

# ============================================================================
# 3. HELPERS
# ============================================================================
function Get-OsArch {
    $a = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    switch ($a.ToUpper()) {
        'AMD64' { 'x64' }
        'ARM64' { 'arm64' }
        'X86'   { 'x86' }
        default { 'x64' }
    }
}

function Get-RemoteFile {
    <# Tries every URL x (IWR -> BITS -> WebClient) x retries. Returns path or $null. #>
    param(
        [Parameter(Mandatory)][string[]]$Uri,
        [Parameter(Mandatory)][string]$OutFile,
        [int]$MinBytes = 20000,
        [int]$Retries  = 3
    )
    foreach ($u in $Uri) {
        for ($i = 1; $i -le $Retries; $i++) {
            foreach ($method in 'IWR', 'BITS', 'WebClient') {
                try {
                    if (Test-Path $OutFile) { Remove-Item $OutFile -Force -ErrorAction SilentlyContinue }
                    Write-Log "Download [$method] try $i/$Retries : $u"
                    switch ($method) {
                        'IWR' {
                            Invoke-WebRequest -Uri $u -OutFile $OutFile -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
                        }
                        'BITS' {
                            if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
                                Start-BitsTransfer -Source $u -Destination $OutFile -ErrorAction Stop
                            } else { throw 'BITS not available' }
                        }
                        'WebClient' {
                            $wc = New-Object System.Net.WebClient
                            $wc.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WingetSetup/1.0')
                            try { $wc.DownloadFile($u, $OutFile) } finally { $wc.Dispose() }
                        }
                    }
                    if ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -ge $MinBytes)) {
                        Unblock-File -Path $OutFile -ErrorAction SilentlyContinue
                        Write-Log ("Downloaded {0} ({1:N0} bytes)" -f (Split-Path $OutFile -Leaf), (Get-Item $OutFile).Length) 'OK'
                        return $OutFile
                    }
                    Write-Log "File missing or too small after $method." 'WARN'
                } catch {
                    Write-Log "$method failed: $($_.Exception.Message)" 'WARN'
                }
            }
            Start-Sleep -Seconds (2 * $i)
        }
    }
    return $null
}

function Test-ZipHeader {
    param([string]$Path)
    try {
        $fs = [IO.File]::OpenRead($Path)
        try { $b = New-Object byte[] 2; [void]$fs.Read($b, 0, 2) } finally { $fs.Dispose() }
        return ($b[0] -eq 0x50 -and $b[1] -eq 0x4B)   # "PK" - appx/msix/zip are all ZIP containers
    } catch { return $false }
}

function Get-WingetPath {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $p = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path $p) { return $p }
    try {
        $dirs = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Directory `
                    -Filter 'Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe' -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending
        foreach ($d in $dirs) {
            $e = Join-Path $d.FullName 'winget.exe'
            if (Test-Path $e) { return $e }
        }
    } catch { }
    return $null
}

function Test-WingetWorks {
    param([string]$Exe)
    if (-not $Exe -or -not (Test-Path $Exe)) { return $false }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $out = & $Exe --version 2>&1 | Out-String
        return (($LASTEXITCODE -eq 0) -and ($out -match 'v?\d+\.\d+'))
    } catch { return $false }
    finally { $ErrorActionPreference = $old }
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
    $wa = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (($env:Path -split ';') -notcontains $wa) { $env:Path += ";$wa" }
}

function Install-AppxSafe {
    <# Add-AppxPackage that treats "already installed / newer present" as success. #>
    param([string]$Path, [string[]]$Dependencies = @())
    try {
        $p = @{ Path = $Path; ErrorAction = 'Stop' }
        if ($Dependencies.Count -gt 0) { $p['DependencyPath'] = $Dependencies }
        Add-AppxPackage @p
        Write-Log "Installed: $(Split-Path $Path -Leaf)" 'OK'
        return $true
    } catch {
        $m = $_.Exception.Message
        if ($m -match '0x80073D06|0x80073CFB|higher version|already installed|newer version') {
            Write-Log "Already present / newer version installed: $(Split-Path $Path -Leaf)" 'OK'
            return $true
        }
        Write-Log "Add-AppxPackage failed for $(Split-Path $Path -Leaf): $m" 'WARN'
        return $false
    }
}

function Get-Dependencies {
    <# Returns an array of dependency .appx paths (VCLibs + UI.Xaml) for this arch. #>
    param([string]$Arch)
    $deps = @()

    # --- Method A: official Dependencies zip
    $zip = Join-Path $WorkDir 'DesktopAppInstaller_Dependencies.zip'
    if (Get-RemoteFile -Uri $Url.DepsZip -OutFile $zip -MinBytes 100000) {
        try {
            $dest = Join-Path $WorkDir 'deps'
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -Path $zip -DestinationPath $dest -Force
            $found = Get-ChildItem -Path $dest -Recurse -Include *.appx, *.msix -ErrorAction SilentlyContinue |
                     Where-Object { $_.FullName -match "[\\/]$Arch[\\/]" -or $_.Name -match "[._]$Arch\." }
            if ($found) {
                $deps = @($found | ForEach-Object { $_.FullName })
                Write-Log "Dependencies from official zip: $($deps.Count) file(s)" 'OK'
                return $deps
            }
        } catch { Write-Log "Dependencies zip extraction failed: $($_.Exception.Message)" 'WARN' }
    }

    # --- Method B: direct links
    Write-Log 'Falling back to direct dependency downloads...' 'WARN'
    $vcKey = "VCLibs_$Arch"
    $vc = Get-RemoteFile -Uri $Url[$vcKey] -OutFile (Join-Path $WorkDir "Microsoft.VCLibs.$Arch.14.00.Desktop.appx") -MinBytes 100000
    if ($vc -and (Test-ZipHeader $vc)) { $deps += $vc }

    $xaml = Get-RemoteFile -Uri @($Url.UIXaml_Direct[$Arch]) -OutFile (Join-Path $WorkDir "Microsoft.UI.Xaml.2.8.$Arch.appx") -MinBytes 500000
    if ($xaml -and (Test-ZipHeader $xaml)) {
        $deps += $xaml
    } else {
        # --- Method C: pull UI.Xaml out of the NuGet package
        $nupkg = Get-RemoteFile -Uri $Url.UIXaml_Nupkg -OutFile (Join-Path $WorkDir 'microsoft.ui.xaml.nupkg.zip') -MinBytes 500000
        if ($nupkg) {
            try {
                $nd = Join-Path $WorkDir 'nuget-xaml'
                if (Test-Path $nd) { Remove-Item $nd -Recurse -Force -ErrorAction SilentlyContinue }
                Expand-Archive -Path $nupkg -DestinationPath $nd -Force
                $appx = Get-ChildItem -Path $nd -Recurse -Filter 'Microsoft.UI.Xaml.2.8.appx' |
                        Where-Object { $_.FullName -match "[\\/]$Arch[\\/]" } | Select-Object -First 1
                if ($appx) { $deps += $appx.FullName; Write-Log 'UI.Xaml obtained from NuGet package.' 'OK' }
            } catch { Write-Log "NuGet UI.Xaml extraction failed: $($_.Exception.Message)" 'WARN' }
        }
    }
    return $deps
}

function Install-ViaPSGalleryModule {
    <# Last-resort fallback: Microsoft.WinGet.Client + Repair-WinGetPackageManager #>
    Write-Log 'Trying PowerShell Gallery fallback (Microsoft.WinGet.Client)...' 'WARN'
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -ErrorAction Stop | Out-Null
        try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch { }
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers -AllowClobber -ErrorAction Stop
        Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
        try   { Repair-WinGetPackageManager -AllUsers -Force -ErrorAction Stop }
        catch { Repair-WinGetPackageManager -Force -ErrorAction Stop }
        return $true
    } catch {
        Write-Log "PSGallery fallback failed: $($_.Exception.Message)" 'WARN'
        return $false
    }
}

# ============================================================================
# 4. MAIN
# ============================================================================
$exitCode = 1
try {
    Write-Log '=== WinGet unattended installer started ==='
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    $arch = Get-OsArch
    Write-Log "OS: $($os.Caption) | Build $build | Arch $arch | PS $($PSVersionTable.PSVersion)"

    if ($build -lt 17763) {
        Write-Log 'Windows 10 1809 (build 17763) or newer is required for winget.' 'ERROR'
        $exitCode = 3; return
    }
    if ($os.ProductType -ne 1) {
        Write-Log 'Server SKU detected - winget is not officially supported here, attempting sideload anyway.' 'WARN'
    }

    # ---- Pre-flight: AppX deployment service must not be disabled (common on hardened Win10 / LTSC)
    try {
        $svc = Get-Service -Name AppXSvc -ErrorAction Stop
        if ($svc.StartType -eq 'Disabled') {
            Write-Log 'AppXSvc is Disabled - setting to Manual.' 'WARN'
            Set-Service -Name AppXSvc -StartupType Manual
        }
        if ($svc.Status -ne 'Running') { Start-Service -Name AppXSvc -ErrorAction SilentlyContinue }
    } catch { Write-Log "AppXSvc check skipped: $($_.Exception.Message)" 'WARN' }

    # ---- Pre-flight: sideloading must not be blocked by policy
    try {
        $polKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx'
        if (Test-Path $polKey) {
            $v = (Get-ItemProperty -Path $polKey -Name AllowAllTrustedApps -ErrorAction SilentlyContinue).AllowAllTrustedApps
            if ($v -eq 0) {
                Write-Log 'Policy AllowAllTrustedApps=0 blocks sideloading - setting to 1.' 'WARN'
                Set-ItemProperty -Path $polKey -Name AllowAllTrustedApps -Value 1 -Type DWord
            }
        }
    } catch { }

    # ---- Already installed?
    Update-SessionPath
    $wg = Get-WingetPath
    if (-not $Force -and (Test-WingetWorks $wg)) {
        $ver = (& $wg --version 2>&1 | Out-String).Trim()
        Write-Log "winget already installed and working ($ver) at $wg. Use -Force to reinstall." 'OK'
        $exitCode = 0
    }
    else {
        # ---- Connectivity test
        $net = $false
        foreach ($h in 'github.com', 'aka.ms') {
            try {
                $r = Invoke-WebRequest -Uri "https://$h" -UseBasicParsing -Method Head -TimeoutSec 20 -ErrorAction Stop
                if ($r.StatusCode -lt 400) { $net = $true; break }
            } catch { }
        }
        if (-not $net) { Write-Log 'No HTTPS connectivity to github.com / aka.ms (proxy/firewall?). Continuing - downloads may fail.' 'WARN' }

        # ---- Dependencies
        $deps = @(Get-Dependencies -Arch $arch)
        if ($deps.Count -eq 0) { Write-Log 'Could not obtain dependency packages; trying main package anyway.' 'WARN' }
        foreach ($d in $deps) { [void](Install-AppxSafe -Path $d) }

        # ---- Main bundle
        $bundle = Join-Path $WorkDir 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        $got = Get-RemoteFile -Uri $Url.Bundle -OutFile $bundle -MinBytes 5000000
        $installed = $false
        if ($got -and (Test-ZipHeader $bundle)) {
            $installed = Install-AppxSafe -Path $bundle -Dependencies $deps
            if (-not $installed -and $deps.Count -gt 0) {
                # retry without explicit dependency list (some builds reject DependencyPath if already satisfied)
                $installed = Install-AppxSafe -Path $bundle
            }
            # Provision for all users / new profiles (works even where per-user registration fails, e.g. SYSTEM)
            try {
                $prov = @{ Online = $true; PackagePath = $bundle; SkipLicense = $true; ErrorAction = 'Stop' }
                if ($deps.Count -gt 0) { $prov['DependencyPackagePath'] = $deps }
                Add-AppxProvisionedPackage @prov | Out-Null
                Write-Log 'Provisioned winget for all users.' 'OK'
            } catch { Write-Log "Provisioning skipped: $($_.Exception.Message)" 'WARN' }
        } else {
            Write-Log 'Main msixbundle download failed or is corrupt.' 'ERROR'
        }

        # ---- Register by family name (helps when package exists but alias is missing)
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
        } catch { }

        Update-SessionPath
        Start-Sleep -Seconds 3
        $wg = Get-WingetPath

        # ---- Fallback: PowerShell Gallery repair
        if (-not (Test-WingetWorks $wg)) {
            if (Install-ViaPSGalleryModule) {
                Update-SessionPath
                Start-Sleep -Seconds 3
                $wg = Get-WingetPath
            }
        }

        if (Test-WingetWorks $wg) {
            $ver = (& $wg --version 2>&1 | Out-String).Trim()
            Write-Log "winget installed successfully: $ver ($wg)" 'OK'
            $exitCode = 0
        } else {
            Write-Log 'winget could not be verified after all methods. See log for details.' 'ERROR'
            $exitCode = 1
        }
    }

    # ---- Post-install: accept agreements + refresh sources (non-interactive)
    if ($exitCode -eq 0 -and -not $SkipSourceUpdate) {
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try {
            Write-Log 'Accepting source agreements and refreshing sources...'
            & $wg list --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
            & $wg source update --disable-interactivity 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Log 'Source update returned non-zero; resetting sources.' 'WARN'
                & $wg source reset --force --disable-interactivity 2>&1 | Out-Null
                & $wg source update --disable-interactivity 2>&1 | Out-Null
            }
            Write-Log 'Sources ready.' 'OK'
        } catch {
            Write-Log "Source refresh warning: $($_.Exception.Message)" 'WARN'
        } finally { $ErrorActionPreference = $old }
    }
}
catch {
    Write-Log "Unhandled error: $($_.Exception.Message)" 'ERROR'
    Write-Log $_.ScriptStackTrace 'ERROR'
    $exitCode = 1
}
finally {
    try { Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    Write-Log "=== Finished with exit code $exitCode | Log: $LogFile ==="
    try { Stop-Transcript | Out-Null } catch { }
}
exit $exitCode
