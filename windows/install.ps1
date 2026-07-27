#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$TorRoot = 'C:\ProgramData\TorRelay',
    [ValidateRange(1, 65535)]
    [int]$TorOrPort = 9001,
    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string]$TorServiceName = 'tor',
    [ValidateRange(1024, 65535)]
    [int]$DashboardPort = 17657,
    [switch]$InstallWidget
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$sourceRoot = Split-Path -Parent $PSScriptRoot
$installRoot = 'C:\ProgramData\LOLILE'
$dashboardRoot = Join-Path $installRoot 'dashboard'
$publicRoot = Join-Path $dashboardRoot 'public'
$libraryRoot = Join-Path $installRoot 'lib'
$dataRoot = Join-Path $installRoot 'data'
$hardwareTask = 'LOLILE Hardware Monitor'
$dashboardTask = 'LOLILE Dashboard'
$powerTask = 'LOLILE Power Manager'
$firewallRule = 'LOLILE Dashboard (Tailscale only)'
$lhmVersion = '0.9.6'
$lhmUrl = 'https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/download/v0.9.6/LibreHardwareMonitor.zip'
$lhmSha256 = '086D9F1B5A99E643EDC2CFAAAC16051685B551E4C5AC0B32A57C58C0E529C001'

function Write-Utf8Bom {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    $content = Get-Content -LiteralPath $Source -Raw -Encoding UTF8
    Set-Content -LiteralPath $Destination -Value $content -Encoding UTF8
}

function Stop-RelayWatchTask {
    param([Parameter(Mandatory)][string]$Name)
    Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue |
        Stop-ScheduledTask -ErrorAction SilentlyContinue
}

if (-not (Test-Path -LiteralPath (Join-Path $TorRoot 'torrc'))) {
    throw "Tor configuration was not found at '$TorRoot\torrc'. Install/configure a Tor non-exit relay first or pass -TorRoot."
}

$node = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $node) {
    throw 'Node.js 22 or newer is required. Install the current Node.js LTS release and run this installer again.'
}

$nodeMajor = [int]((& $node.Source --version).TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 22) {
    throw "Node.js 22 or newer is required; found major version $nodeMajor."
}

foreach ($required in @(
    (Join-Path $sourceRoot 'windows\hardware-monitor.ps1'),
    (Join-Path $sourceRoot 'windows\power-manager.ps1'),
    (Join-Path $sourceRoot 'windows\widget.ps1'),
    (Join-Path $sourceRoot 'windows\dashboard\server.mjs'),
    (Join-Path $sourceRoot 'windows\dashboard\public\dashboard.html')
)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing package file: $required"
    }
}

New-Item -ItemType Directory -Path $installRoot,$dashboardRoot,$publicRoot,$libraryRoot,$dataRoot -Force | Out-Null

foreach ($taskName in @(
    $hardwareTask,$dashboardTask,$powerTask,
    'RelayWatch Hardware Monitor','RelayWatch Dashboard','RelayWatch Power Manager'
)) {
    Stop-RelayWatchTask -Name $taskName
}

Get-NetTCPConnection -LocalPort $DashboardPort -State Listen -ErrorAction SilentlyContinue |
    ForEach-Object {
        $listener = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        if ($listener -and $listener.Name -eq 'node') {
            Stop-Process -Id $listener.Id -Force -ErrorAction SilentlyContinue
        }
    }
Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -in @('powershell.exe','node.exe') -and
        $_.CommandLine -match '(?i)C:\\ProgramData\\(?:RelayWatch|LOLILE|TorRelayDashboard)'
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 1200

$libraryDll = Join-Path $libraryRoot 'LibreHardwareMonitorLib.dll'
if (-not (Test-Path -LiteralPath $libraryDll)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('relaywatch-' + [guid]::NewGuid().ToString('N'))
    $archive = Join-Path $temporaryRoot 'LibreHardwareMonitor.zip'
    $extract = Join-Path $temporaryRoot 'extract'
    New-Item -ItemType Directory -Path $temporaryRoot,$extract -Force | Out-Null
    try {
        Invoke-WebRequest -Uri $lhmUrl -OutFile $archive -UseBasicParsing
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        if ($actualHash -ne $lhmSha256) {
            throw "LibreHardwareMonitor checksum mismatch. Expected $lhmSha256 but received $actualHash."
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
        $locatedDll = Get-ChildItem -LiteralPath $extract -Recurse -Filter 'LibreHardwareMonitorLib.dll' |
            Select-Object -First 1
        if (-not $locatedDll) {
            throw 'LibreHardwareMonitorLib.dll was not found in the official archive.'
        }
        Copy-Item -Path (Join-Path $locatedDll.DirectoryName '*') -Destination $libraryRoot -Recurse -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

Write-Utf8Bom `
    -Source (Join-Path $sourceRoot 'windows\hardware-monitor.ps1') `
    -Destination (Join-Path $installRoot 'hardware-monitor.ps1')
Write-Utf8Bom `
    -Source (Join-Path $sourceRoot 'windows\power-manager.ps1') `
    -Destination (Join-Path $installRoot 'power-manager.ps1')
Copy-Item `
    -LiteralPath (Join-Path $sourceRoot 'windows\dashboard\server.mjs') `
    -Destination (Join-Path $dashboardRoot 'server.mjs') `
    -Force
Copy-Item `
    -LiteralPath (Join-Path $sourceRoot 'windows\dashboard\public\dashboard.html') `
    -Destination (Join-Path $publicRoot 'dashboard.html') `
    -Force
Write-Utf8Bom `
    -Source (Join-Path $sourceRoot 'windows\widget.ps1') `
    -Destination (Join-Path $installRoot 'widget.ps1')

foreach ($legacyDataRoot in @(
    'C:\ProgramData\RelayWatch\data',
    'C:\ProgramData\TorRelayDashboard\data'
)) {
    if (Test-Path -LiteralPath $legacyDataRoot) {
        foreach ($file in @('traffic.json','snowflake-traffic.json')) {
            $source = Join-Path $legacyDataRoot $file
            $destination = Join-Path $dataRoot $file
            if ((Test-Path -LiteralPath $source) -and -not (Test-Path -LiteralPath $destination)) {
                Copy-Item -LiteralPath $source -Destination $destination
            }
        }
    }
}

$escapedTorRoot = $TorRoot.Replace("'", "''")
$escapedNode = $node.Source.Replace("'", "''")
$dashboardLauncher = @"
`$ErrorActionPreference = 'Stop'
`$env:RELAYWATCH_ROOT = '$installRoot'
`$env:RELAYWATCH_PUBLIC_ROOT = '$publicRoot'
`$env:RELAYWATCH_HARDWARE_STATUS = '$installRoot\hardware-status.json'
`$env:RELAYWATCH_PORT = '$DashboardPort'
`$env:LOLILE_POWER_MANAGER = '$installRoot\power-manager.ps1'
`$env:LOLILE_POWER_STATUS = '$installRoot\power-status.json'
`$env:TOR_ROOT = '$escapedTorRoot'
`$env:TOR_OR_PORT = '$TorOrPort'
`$env:TOR_SERVICE_NAME = '$TorServiceName'
& '$escapedNode' '$dashboardRoot\server.mjs'
"@
Set-Content -LiteralPath (Join-Path $installRoot 'start-dashboard.ps1') -Value $dashboardLauncher -Encoding UTF8

$powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew

$hardwareAction = New-ScheduledTaskAction `
    -Execute $powerShell `
    -Argument "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installRoot\hardware-monitor.ps1`" -InstallRoot `"$installRoot`"" `
    -WorkingDirectory $installRoot
$dashboardAction = New-ScheduledTaskAction `
    -Execute $powerShell `
    -Argument "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installRoot\start-dashboard.ps1`"" `
    -WorkingDirectory $installRoot
$powerAction = New-ScheduledTaskAction `
    -Execute $powerShell `
    -Argument "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installRoot\power-manager.ps1`" -Action Tick -InstallRoot `"$installRoot`"" `
    -WorkingDirectory $installRoot
$startup = New-ScheduledTaskTrigger -AtStartup
$watchdog = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

Register-ScheduledTask `
    -TaskName $hardwareTask `
    -Action $hardwareAction `
    -Trigger @($startup,$watchdog) `
    -Principal $principal `
    -Settings $settings `
    -Description "LOLILE hardware telemetry using LibreHardwareMonitor $lhmVersion." `
    -Force | Out-Null
Register-ScheduledTask `
    -TaskName $dashboardTask `
    -Action $dashboardAction `
    -Trigger @($startup,$watchdog) `
    -Principal $principal `
    -Settings $settings `
    -Description 'LOLILE Tor relay, Snowflake, PC monitor and private power-control dashboard.' `
    -Force | Out-Null
Register-ScheduledTask `
    -TaskName $powerTask `
    -Action $powerAction `
    -Trigger @($startup,$watchdog) `
    -Principal $principal `
    -Settings $settings `
    -Description 'LOLILE automatic night power mode. Sleep remains disabled and remote services stay online.' `
    -Force | Out-Null

foreach ($oldRule in @(
    $firewallRule,
    'RelayWatch Dashboard (Tailscale only)',
    'benfirad Tor Dashboard (Tailscale)',
    'lolile - Tor support dashboard (Tailscale only)'
)) {
    Get-NetFirewallRule -DisplayName $oldRule -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule
}
New-NetFirewallRule `
    -DisplayName $firewallRule `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort $DashboardPort `
    -RemoteAddress @('100.64.0.0/10','fd7a:115c:a1e0::/48') `
    -Profile Any | Out-Null

& $powerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File (Join-Path $installRoot 'power-manager.ps1') `
    -Action Install `
    -InstallRoot $installRoot | Out-Null

Start-ScheduledTask -TaskName $hardwareTask
Start-ScheduledTask -TaskName $dashboardTask
Start-ScheduledTask -TaskName $powerTask

if ($InstallWidget) {
    $launcher = Join-Path $installRoot 'launch-widget.vbs'
    @"
CreateObject("Wscript.Shell").Run "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$installRoot\widget.ps1""", 0, False
"@ | Set-Content -LiteralPath $launcher -Encoding ASCII
    $startupFolder = [Environment]::GetFolderPath('Startup')
    foreach ($legacyShortcut in @('RelayWatch Widget.lnk','benfirad Tor Paneli.lnk')) {
        Remove-Item -LiteralPath (Join-Path $startupFolder $legacyShortcut) -Force -ErrorAction SilentlyContinue
    }
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $startupFolder 'LOLILE Widget.lnk'))
    $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
    $shortcut.Arguments = "`"$launcher`""
    $shortcut.WorkingDirectory = $installRoot
    $shortcut.Description = 'LOLILE desktop widget'
    $shortcut.Save()
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\wscript.exe') -ArgumentList "`"$launcher`""
}

$deadline = (Get-Date).AddSeconds(40)
do {
    Start-Sleep -Milliseconds 750
    $status = $null
    try {
        $status = Invoke-RestMethod -Uri "http://127.0.0.1:$DashboardPort/api/status" -TimeoutSec 5
    }
    catch {}
} while (($null -eq $status -or $status.hardware.available -ne $true) -and (Get-Date) -lt $deadline)

if ($null -eq $status -or $status.hardware.available -ne $true) {
    throw "LOLILE tasks were installed, but the local API did not become healthy on port $DashboardPort."
}

Write-Host ''
Write-Host "LOLILE is ready: http://127.0.0.1:$DashboardPort" -ForegroundColor Green
Write-Host 'Remote dashboard and power control are limited to Tailscale address ranges.'
Write-Host 'Automatic night mode defaults to 00:00-08:00. Sleep, Tor, Tailscale, Chrome Remote Desktop and SMB remain enabled.'
Write-Host 'The total wall-power value is an estimate unless a supported external meter is integrated.'
