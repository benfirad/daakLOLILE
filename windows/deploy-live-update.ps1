#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceRoot,
    [string]$InstallRoot = 'C:\ProgramData\daakLOLILE'
)

$ErrorActionPreference = 'Stop'
$tasksToRestart = @(
    'daakLOLILE Hardware Monitor',
    'daakLOLILE Dashboard',
    'daakLOLILE Power Manager'
)

if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot 'windows\install.ps1'))) {
    throw "Source root is not a daakLOLILE checkout: $SourceRoot"
}
if (-not (Test-Path -LiteralPath $InstallRoot)) {
    throw "Live daakLOLILE installation was not found: $InstallRoot"
}

foreach ($taskName in $tasksToRestart) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}

$files = @(
    'hardware-monitor.ps1',
    'power-manager.ps1',
    'fah-control.mjs'
)
foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $SourceRoot "windows\$file") -Destination (Join-Path $InstallRoot $file) -Force
}

Copy-Item -LiteralPath (Join-Path $SourceRoot 'windows\dashboard\server.mjs') `
    -Destination (Join-Path $InstallRoot 'dashboard\server.mjs') -Force
Copy-Item -Path (Join-Path $SourceRoot 'windows\dashboard\public\*') `
    -Destination (Join-Path $InstallRoot 'dashboard\public') -Recurse -Force

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot 'power-manager.ps1') `
    -Action Install -InstallRoot $InstallRoot | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot 'power-manager.ps1') `
    -Action Set -Mode auto -NightStart '17:00' -NightEnd '22:00' -InstallRoot $InstallRoot | Out-Null

Start-ScheduledTask -TaskName 'daakLOLILE Hardware Monitor'
Start-ScheduledTask -TaskName 'daakLOLILE Dashboard'
Start-ScheduledTask -TaskName 'daakLOLILE Power Manager'

$deadline = (Get-Date).AddSeconds(30)
do {
    Start-Sleep -Milliseconds 500
    try {
        $status = Invoke-RestMethod -Uri 'http://127.0.0.1:17657/api/status' -TimeoutSec 3
    }
    catch {
        $status = $null
    }
} while (
    (-not $status -or
     $status.power.nightStart -ne '17:00' -or
     $status.power.nightEnd -ne '22:00') -and
    (Get-Date) -lt $deadline
)

if (-not $status) {
    throw 'The local daakLOLILE API did not recover after the update.'
}
if ($status.power.nightStart -ne '17:00' -or $status.power.nightEnd -ne '22:00') {
    throw 'The peak-saving schedule was not applied.'
}
if (-not $status.snowflake.running) {
    throw 'Snowflake was not running after the update.'
}

[pscustomobject]@{
    deployed = $true
    schedule = "$($status.power.nightStart)-$($status.power.nightEnd)"
    effectiveMode = [string]$status.power.effectiveMode
    snowflakeRunning = [bool]$status.snowflake.running
    snowflakeNat = [string]$status.snowflake.natType
    electricityAvailable = [bool]$status.electricity.available
    hourlyProfilePoints = @($status.electricity.hourlyProfile).Count
} | ConvertTo-Json -Depth 4
