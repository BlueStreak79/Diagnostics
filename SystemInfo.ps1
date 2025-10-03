Add-Type -AssemblyName System.Windows.Forms

function Show-SystemInfo {
    $sys = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor
    $ramGB = [math]::Round($sys.TotalPhysicalMemory / 1GB, 2)
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join ", "
    $os = Get-CimInstance Win32_OperatingSystem
    $disk = (Get-PhysicalDisk | ForEach-Object { "$($_.FriendlyName) $([math]::Round($_.Size/1GB))GB" }) -join ", "
    $mb = (Get-CimInstance Win32_BaseBoard).Manufacturer
    $winVersion = if ($os.Caption -match "11") { "Windows 11" } else { "Windows 10" }

    $info = @"
System Information
------------------------------
Model       : $($sys.Model)
Serial No   : $($sys.Name)
Motherboard : $mb
Processor   : $($cpu.Name)
Memory      : $ramGB GB
GPU         : $gpu
Disk(s)     : $disk
OS Version  : $winVersion
"@

    [System.Windows.Forms.MessageBox]::Show($info, "System Info", 'OK', 'Information')
}

Show-SystemInfo
