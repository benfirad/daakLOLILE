#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$KeepData
)

$ErrorActionPreference = 'Stop'
$installRoot = 'C:\ProgramData\daakLOLILE'
$hardwareTask = 'daakLOLILE Hardware Monitor'
$dashboardTask = 'daakLOLILE Dashboard'
$powerTask = 'daakLOLILE Power Manager'
$memoryTask = 'daakLOLILE Memory Maintenance'
$boincHeadlessTask = 'daakLOLILE BOINC Headless Guard'
$firewallRule = 'daakLOLILE Dashboard (Tailscale only)'

$answer = Read-Host 'Remove daakLOLILE tasks, firewall rule and installed files? Type REMOVE'
if ($answer -cne 'REMOVE') {
    Write-Host 'Cancelled.'
    exit 0
}

if (Test-Path -LiteralPath (Join-Path $installRoot 'power-manager.ps1')) {
    & (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') `
        -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
        -File (Join-Path $installRoot 'power-manager.ps1') `
        -Action Restore `
        -InstallRoot $installRoot | Out-Null
}

foreach ($task in @($hardwareTask,$dashboardTask,$powerTask,$memoryTask,$boincHeadlessTask)) {
    Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue |
        Stop-ScheduledTask -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
}

Get-NetFirewallRule -DisplayName $firewallRule -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -in @('powershell.exe','node.exe') -and
        $_.CommandLine -match '(?i)C:\\ProgramData\\daakLOLILE'
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

foreach ($shortcutName in @('daakLOLILE Widget.lnk','lolile Tor Widget.lnk')) {
    $shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) $shortcutName
    if (Test-Path -LiteralPath $shortcut) {
        Remove-Item -LiteralPath $shortcut -Force
    }
}

if (Test-Path -LiteralPath (Join-Path $installRoot 'boinc-headless.ps1')) {
    & (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') `
        -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
        -File (Join-Path $installRoot 'boinc-headless.ps1') `
        -Action Restore `
        -InstallRoot $installRoot | Out-Null
}

if (-not $KeepData -and (Test-Path -LiteralPath $installRoot)) {
    $resolved = (Resolve-Path -LiteralPath $installRoot).Path
    if ($resolved -cne 'C:\ProgramData\daakLOLILE') {
        throw "Refusing to remove unexpected path: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

Write-Host 'daakLOLILE was removed. Tor, Snowflake, Tailscale and their data were not modified.' -ForegroundColor Green
