#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\ProgramData\daakLOLILE',
    [switch]$Once
)

$ErrorActionPreference = 'SilentlyContinue'
$volunteerRoot = Join-Path $InstallRoot 'volunteer'
$fahRoot = Join-Path $volunteerRoot 'fah'
$statusPath = Join-Path $InstallRoot 'volunteer-status.json'
$boincDataRoot = 'C:\ProgramData\BOINC'
$fahExe = 'C:\Program Files\FAHClient\FAHClient.exe'
$boincExe = 'C:\Program Files\BOINC\boinc.exe'
$fahControl = Join-Path $InstallRoot 'fah-control.mjs'

New-Item -ItemType Directory -Path $volunteerRoot,$fahRoot -Force | Out-Null
$createdNew = $false
$monitorMutex = New-Object System.Threading.Mutex($true, 'Global\daakLOLILEVolunteerMonitor', [ref]$createdNew)
if (-not $createdNew) {
    exit 0
}

function Write-JsonAtomic {
    param([Parameter(Mandatory)]$Value)
    $temporary = "$statusPath.tmp"
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $statusPath -Force
}

function Test-LocalPort {
    param([int]$Port)
    return [bool](Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
}

function Get-FahStatus {
    $installed = Test-Path -LiteralPath $fahExe
    $process = Get-Process -Name FAHClient -ErrorAction SilentlyContinue | Select-Object -First 1
    $logPath = Join-Path $fahRoot 'log.txt'
    $log = if (Test-Path -LiteralPath $logPath) {
        Get-Content -LiteralPath $logPath -Tail 160 -ErrorAction SilentlyContinue
    } else {
        @()
    }
    $control = $null
    if ($process -and (Test-Path -LiteralPath $fahControl)) {
        try {
            $control = (& node.exe $fahControl status 2>$null | Select-Object -Last 1) | ConvertFrom-Json
        } catch {}
    }
    $working = $control.workingUnits -gt 0 -or [bool]($log -match '(?i)(assigned|downloaded|running FahCore|percent|completed.*work|upload)')
    $completed = @($log | Where-Object { $_ -match '(?i)(work unit.*complete|upload.*complete)' }).Count
    $state = if (-not $installed) {
        'not-installed'
    } elseif (-not $process) {
        'stopped'
    } elseif ($working) {
        'working'
    } else {
        'ready'
    }
    [ordered]@{
        installed = $installed
        running = [bool]$process
        state = $state
        webControl = Test-LocalPort -Port 7396
        onIdle = if ($control) { $control.onIdle -eq $true } else { $true }
        cpuThreads = if ($control) { [int]$control.cpuThreads } else { 2 }
        gpuEnabled = if ($control) { $control.gpuEnabled -eq $true } else { $false }
        activeWorkUnits = if ($control) { [int]$control.workingUnits } else { 0 }
        progressPercent = if ($control) { [Math]::Round([double]$control.progressPercent, 2) } else { 0 }
        pointsPerDay = if ($control) { [Math]::Round([double]$control.pointsPerDay) } else { 0 }
        user = 'lolile'
        completedWorkUnitsObserved = $completed
        detail = switch ($state) {
            'not-installed' { 'İstemci henüz kurulmadı.' }
            'stopped' { 'İstemci kurulu ancak çalışmıyor.' }
            'working' { 'Bilimsel iş paketi işleniyor.' }
            default { 'İstemci hazır; uygun iş paketi bekleniyor.' }
        }
    }
}

function Get-BoincStatus {
    $installed = Test-Path -LiteralPath $boincExe
    $service = Get-Service -Name BOINC -ErrorAction SilentlyContinue
    $process = Get-Process -Name boinc -ErrorAction SilentlyContinue | Select-Object -First 1
    $clientStatePath = Join-Path $boincDataRoot 'client_state.xml'
    $projects = @()
    $activeTasks = 0
    if (Test-Path -LiteralPath $clientStatePath) {
        try {
            [xml]$state = Get-Content -LiteralPath $clientStatePath -Raw
            $projectNodes = @($state.SelectNodes('/client_state/project'))
            $activeTaskNodes = @($state.SelectNodes('/client_state/active_task_set/active_task'))
            $projects = @($projectNodes | ForEach-Object {
                [ordered]@{
                    name = if ($_.project_name) { [string]$_.project_name } else { [string]$_.master_url }
                    url = [string]$_.master_url
                }
            })
            $activeTasks = $activeTaskNodes.Count
        } catch {}
    }
    $running = [bool]$process -or $service.Status -eq 'Running'
    $stateName = if (-not $installed) {
        'not-installed'
    } elseif (-not $running) {
        'stopped'
    } elseif ($projects.Count -eq 0) {
        'account-required'
    } elseif ($activeTasks -gt 0) {
        'working'
    } else {
        'ready'
    }
    [ordered]@{
        installed = $installed
        running = $running
        state = $stateName
        serviceStartMode = if ($service) { [string]$service.StartType } else { 'Unavailable' }
        projects = $projects
        activeTasks = $activeTasks
        limits = [ordered]@{
            cpuPercent = 33
            maxCpuThreads = 4
            busyRamPercent = 25
            idleRamPercent = 40
            diskGB = 5
            gpuEnabled = $false
        }
        detail = switch ($stateName) {
            'not-installed' { 'İstemci henüz kurulmadı.' }
            'stopped' { 'İstemci kurulu ancak çalışmıyor.' }
            'account-required' { 'İstemci hazır; BOINC projesi bağlanmayı bekliyor.' }
            'working' { "$activeTasks bilimsel görev çalışıyor." }
            default { 'Projeler bağlı; yeni görev bekleniyor.' }
        }
    }
}

function Get-RipeAtlasStatus {
    $wslFeature = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue).State
    $vmFeature = (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue).State
    $distroNames = @(& wsl.exe --list --quiet 2>$null) |
        ForEach-Object { (([string]$_) -replace [char]0, '').Trim() } |
        Where-Object { $_ }
    $distro = $distroNames | Where-Object { $_ -match '(?i)(ripe|debian|ubuntu)' } | Select-Object -First 1
    $probeKeyPath = Join-Path $volunteerRoot 'ripe-atlas-probe-key.pub'
    $installStatePath = Join-Path $volunteerRoot 'ripe-atlas-install.json'
    $registeredPath = Join-Path $volunteerRoot 'ripe-atlas-registered.json'
    $installState = $null
    if (Test-Path -LiteralPath $installStatePath) {
        try { $installState = Get-Content -LiteralPath $installStatePath -Raw | ConvertFrom-Json } catch {}
    }
    $registered = Test-Path -LiteralPath $registeredPath
    $running = $false
    if ($distro) {
        & wsl.exe -d $distro -- sh -lc 'pgrep -f ripe-atlas >/dev/null' 2>$null
        $running = $LASTEXITCODE -eq 0
    }
    $stateName = if ($installState.state -eq 'firmware-virtualization-required') {
        'firmware-virtualization-required'
    } elseif ($installState.state -eq 'reboot-required' -or $installState.rebootRequired -eq $true) {
        'reboot-required'
    } elseif ($installState.state -eq 'error') {
        'error'
    } elseif ($wslFeature -ne 'Enabled' -or $vmFeature -ne 'Enabled') {
        'windows-feature-required'
    } elseif (-not $distro) {
        'distro-required'
    } elseif (-not (Test-Path -LiteralPath $probeKeyPath)) {
        'probe-install-required'
    } elseif (-not $registered) {
        'account-required'
    } elseif ($running) {
        'measuring'
    } else {
        'stopped'
    }
    [ordered]@{
        installed = [bool]$distro -and (Test-Path -LiteralPath $probeKeyPath)
        running = $running
        registered = $registered
        state = $stateName
        distro = if ($distro) { [string]$distro } else { '' }
        lowImpact = $true
        diskSharing = $false
        registrationUrl = 'https://atlas.ripe.net/apply/swprobe/'
        publicKeyPath = $probeKeyPath
        detail = switch ($stateName) {
            'firmware-virtualization-required' { if ($installState.detail) { [string]$installState.detail } else { 'RIPE Atlas için BIOS/UEFI içinde donanım sanallaştırması etkinleştirilmeli.' } }
            'reboot-required' { if ($installState.detail) { [string]$installState.detail } else { 'Kurulum güvenli bir Windows yeniden başlatması bekliyor.' } }
            'error' { if ($installState.detail) { [string]$installState.detail } else { 'RIPE Atlas kurulumu hata verdi.' } }
            'windows-feature-required' { 'WSL altyapısı kurulmayı ve yeniden başlatmayı bekliyor.' }
            'distro-required' { 'Linux ortamı kurulmayı bekliyor.' }
            'probe-install-required' { 'RIPE Atlas yazılım probu kurulmayı bekliyor.' }
            'account-required' { 'Prob hazır; RIPE hesabında kayıt bekliyor.' }
            'measuring' { 'İnternet ölçümleri aktif.' }
            default { 'Prob kurulu ancak çalışmıyor.' }
        }
    }
}

function Ensure-VolunteerProcesses {
    if ((Test-Path -LiteralPath $fahExe) -and -not (Get-Process -Name FAHClient -ErrorAction SilentlyContinue)) {
        $arguments = @(
            '--user=lolile',
            "--machine-name=$env:COMPUTERNAME",
            '--cpus=2',
            '--on-idle',
            '--http-addresses=127.0.0.1:7396',
            "--log=$(Join-Path $fahRoot 'log.txt')",
            '--log-rotate-max=7',
            '--log-to-screen=false'
        )
        Start-Process -FilePath $fahExe -ArgumentList $arguments -WorkingDirectory $fahRoot -WindowStyle Hidden
        $deadline = (Get-Date).AddSeconds(12)
        do {
            Start-Sleep -Milliseconds 500
        } while (-not (Test-LocalPort -Port 7396) -and (Get-Date) -lt $deadline)
        if ((Test-LocalPort -Port 7396) -and (Test-Path -LiteralPath $fahControl)) {
            & node.exe $fahControl configure 2>$null | Out-Null
        }
    }

    $boincService = Get-Service -Name BOINC -ErrorAction SilentlyContinue
    if ($boincService -and $boincService.Status -ne 'Running') {
        Start-Service -Name BOINC
    }
}

do {
    Ensure-VolunteerProcesses
    $status = [ordered]@{
        updatedAt = [DateTime]::UtcNow.ToString('o')
        folding = Get-FahStatus
        boinc = Get-BoincStatus
        ripeAtlas = Get-RipeAtlasStatus
        policy = [ordered]@{
            preservesRemoteAccess = $true
            noPublicDiskSharing = $true
            snowflakeAlwaysOn = $true
            unattended = $true
        }
    }
    Write-JsonAtomic -Value $status
    if (-not $Once) {
        Start-Sleep -Seconds 30
    }
} while (-not $Once)
