#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$KeepData
)

$ErrorActionPreference = 'Stop'
$installRoot = 'C:\ProgramData\RelayWatch'
$hardwareTask = 'RelayWatch Hardware Monitor'
$dashboardTask = 'RelayWatch Dashboard'
$firewallRule = 'RelayWatch Dashboard (Tailscale only)'

$answer = Read-Host 'Remove RelayWatch tasks, firewall rule and installed files? Type REMOVE'
if ($answer -cne 'REMOVE') {
    Write-Host 'Cancelled.'
    exit 0
}

foreach ($task in @($hardwareTask,$dashboardTask)) {
    Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue |
        Stop-ScheduledTask -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
}

Get-NetFirewallRule -DisplayName $firewallRule -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -in @('powershell.exe','node.exe') -and
        $_.CommandLine -match '(?i)C:\\ProgramData\\RelayWatch'
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'RelayWatch Widget.lnk'
if (Test-Path -LiteralPath $shortcut) {
    Remove-Item -LiteralPath $shortcut -Force
}

if (-not $KeepData -and (Test-Path -LiteralPath $installRoot)) {
    $resolved = (Resolve-Path -LiteralPath $installRoot).Path
    if ($resolved -cne 'C:\ProgramData\RelayWatch') {
        throw "Refusing to remove unexpected path: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

Write-Host 'RelayWatch was removed. Tor, Snowflake, Tailscale and their data were not modified.' -ForegroundColor Green
