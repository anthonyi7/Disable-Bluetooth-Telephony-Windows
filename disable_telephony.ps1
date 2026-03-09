#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables Hands-Free Telephony (HFP) for a Bluetooth audio device.
    Stereo audio (A2DP) is unaffected.

.PARAMETER DeviceName
    Partial name of the Bluetooth device to target. Defaults to "AirPods".

.EXAMPLE
    .\disable_telephony.ps1
    .\disable_telephony.ps1 -DeviceName "AirPods Pro"
    .\disable_telephony.ps1 -DeviceName "WH-1000XM5"
#>
param(
    [string]$DeviceName = "AirPods"
)

$hfpUuid = "{0000111e-0000-1000-8000-00805f9b34fb}"

# Find the paired device and extract its MAC from the InstanceId (BTHENUM\DEV_<MAC>\...)
$btDevice = Get-PnpDevice | Where-Object {
    $_.FriendlyName -like "*$DeviceName*" -and $_.InstanceId -like "BTHENUM\DEV_*"
}

if (-not $btDevice) {
    Write-Host "Device matching '$DeviceName' not found. Is it paired?"
    exit 1
}

$deviceMac = ($btDevice.InstanceId -replace 'BTHENUM\\DEV_([A-F0-9]{12}).*', '$1').ToLower()
Write-Host "Found: $($btDevice.FriendlyName) [$deviceMac]"

# Set Enabled=0 for the HFP service in the BTHPORT registry
$deviceBase  = "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices\$deviceMac"
$servicesKey = Get-ChildItem -Path $deviceBase -ErrorAction SilentlyContinue |
               Where-Object { $_.PSChildName -like "ServicesFor*" }

if ($servicesKey) {
    $hfpPath = Join-Path $servicesKey.PSPath "$hfpUuid\C00000000"
    if (Test-Path $hfpPath) {
        Set-ItemProperty -Path $hfpPath -Name "Enabled" -Value 0 -Type DWord
    }
}

# Remove the active HFP device node so the change takes effect immediately
$hfpDevice = Get-PnpDevice | Where-Object {
    $_.InstanceId -like "*111e*" -and $_.InstanceId -like "*$($deviceMac.ToUpper())*"
}
foreach ($dev in $hfpDevice) {
    pnputil /remove-device $dev.InstanceId | Out-Null
}

# Register as a logon startup task (runs once on first execution)
$taskName = "Disable $($btDevice.FriendlyName) Telephony"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $argument   = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -DeviceName `"$DeviceName`""
    $action     = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument
    $trigger    = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $principal  = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive
    $settings   = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
                           -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "Startup task registered: '$taskName'"
}

Write-Host "Telephony disabled. Stereo audio (A2DP) unaffected."
