#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Install','Set','Tick','Status','Restore')]
    [string]$Action = 'Status',
    [ValidateSet('auto','eco','balanced','performance')]
    [string]$Mode = 'auto',
    [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')]
    [string]$NightStart,
    [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')]
    [string]$NightEnd,
    [string]$InstallRoot = 'C:\ProgramData\daakLOLILE'
)

$ErrorActionPreference = 'Stop'
$configPath = Join-Path $InstallRoot 'power-config.json'
$statusPath = Join-Path $InstallRoot 'power-status.json'
$fahControlPath = Join-Path $InstallRoot 'fah-control.mjs'
$boincPreferencesPath = 'C:\ProgramData\BOINC\global_prefs_override.xml'
$boincCommandPath = 'C:\Program Files\BOINC\boinccmd.exe'
$mutex = New-Object System.Threading.Mutex($false, 'Global\daakLOLILEPowerManager')

function Invoke-PowerCfg {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$BestEffort
    )
    $output = & powercfg.exe @Arguments 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $BestEffort) {
        throw "powercfg $($Arguments -join ' ') failed: $($output -join ' ')"
    }
    return ($output -join "`n")
}

function Get-ActiveScheme {
    $text = Invoke-PowerCfg -Arguments @('/getactivescheme')
    return ([regex]::Match($text, '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')).Value.ToLowerInvariant()
}

function Test-Scheme {
    param([string]$Guid)
    if ($Guid -notmatch '^[0-9a-fA-F-]{36}$') { return $false }
    $null = & powercfg.exe /query $Guid 2>$null
    return $LASTEXITCODE -eq 0
}

function New-Scheme {
    param(
        [Parameter(Mandatory)][string]$Template,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description
    )
    $output = Invoke-PowerCfg -Arguments @('/duplicatescheme',$Template)
    $guid = ([regex]::Match($output, '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')).Value.ToLowerInvariant()
    if (-not $guid) { throw "Could not create the '$Name' power scheme." }
    $null = Invoke-PowerCfg -Arguments @('/changename',$guid,$Name,$Description)
    return $guid
}

function Set-AcValue {
    param([string]$Scheme,[string]$Subgroup,[string]$Setting,[int]$Value,[switch]$BestEffort)
    $null = Invoke-PowerCfg -Arguments @('/setacvalueindex',$Scheme,$Subgroup,$Setting,[string]$Value) -BestEffort:$BestEffort
}

function Set-DcValue {
    param([string]$Scheme,[string]$Subgroup,[string]$Setting,[int]$Value,[switch]$BestEffort)
    $null = Invoke-PowerCfg -Arguments @('/setdcvalueindex',$Scheme,$Subgroup,$Setting,[string]$Value) -BestEffort:$BestEffort
}

function Set-AlwaysReachable {
    param([string]$Scheme)
    foreach ($kind in @('Ac','Dc')) {
        & "Set-$($kind)Value" -Scheme $Scheme -Subgroup 'SUB_SLEEP' -Setting 'STANDBYIDLE' -Value 0
        & "Set-$($kind)Value" -Scheme $Scheme -Subgroup 'SUB_SLEEP' -Setting 'HIBERNATEIDLE' -Value 0
        & "Set-$($kind)Value" -Scheme $Scheme -Subgroup 'SUB_SLEEP' -Setting 'HYBRIDSLEEP' -Value 0 -BestEffort
    }
}

function Set-EcoScheme {
    param([string]$Scheme)
    Set-AlwaysReachable -Scheme $Scheme
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMIN' -Value 5
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMAX' -Value 35
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PERFBOOSTMODE' -Value 0 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PERFEPP' -Value 90 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'SYSCOOLPOL' -Value 0 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'CPMINCORES' -Value 10 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'CPMAXCORES' -Value 50 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_DISK' -Setting 'DISKIDLE' -Value 600
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PCIEXPRESS' -Setting 'ASPM' -Value 2 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_VIDEO' -Setting 'VIDEOIDLE' -Value 300
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMIN' -Value 5
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMAX' -Value 35
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PERFBOOSTMODE' -Value 0 -BestEffort
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PERFEPP' -Value 95 -BestEffort
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'SYSCOOLPOL' -Value 0 -BestEffort
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'CPMINCORES' -Value 10 -BestEffort
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'CPMAXCORES' -Value 50 -BestEffort
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_DISK' -Setting 'DISKIDLE' -Value 300
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PCIEXPRESS' -Setting 'ASPM' -Value 2 -BestEffort
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_VIDEO' -Setting 'VIDEOIDLE' -Value 300
}

function Set-BalancedScheme {
    param([string]$Scheme)
    Set-AlwaysReachable -Scheme $Scheme
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMIN' -Value 5
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMAX' -Value 100
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PERFEPP' -Value 50 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'SYSCOOLPOL' -Value 1 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'CPMINCORES' -Value 10 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'CPMAXCORES' -Value 100 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_DISK' -Setting 'DISKIDLE' -Value 1200
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PCIEXPRESS' -Setting 'ASPM' -Value 1 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_VIDEO' -Setting 'VIDEOIDLE' -Value 1200
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMIN' -Value 5
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMAX' -Value 80
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_VIDEO' -Setting 'VIDEOIDLE' -Value 600
}

function Set-PerformanceScheme {
    param([string]$Scheme)
    Set-AlwaysReachable -Scheme $Scheme
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMIN' -Value 20
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMAX' -Value 100
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PERFBOOSTMODE' -Value 2 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PERFEPP' -Value 20 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'SYSCOOLPOL' -Value 1 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'CPMINCORES' -Value 100 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'CPMAXCORES' -Value 100 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_DISK' -Setting 'DISKIDLE' -Value 0
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_PCIEXPRESS' -Setting 'ASPM' -Value 0 -BestEffort
    Set-AcValue -Scheme $Scheme -Subgroup 'SUB_VIDEO' -Setting 'VIDEOIDLE' -Value 1800
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMIN' -Value 5
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMAX' -Value 100
    Set-DcValue -Scheme $Scheme -Subgroup 'SUB_VIDEO' -Setting 'VIDEOIDLE' -Value 900
}

function Read-Config {
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw 'daakLOLILE power modes are not installed.'
    }
    return Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-Config {
    param($Config)
    $Config.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $Config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
}

function Test-NightWindow {
    param([string]$Start,[string]$End)
    $now = (Get-Date).TimeOfDay
    $startTime = [TimeSpan]::ParseExact($Start,'hh\:mm',$null)
    $endTime = [TimeSpan]::ParseExact($End,'hh\:mm',$null)
    if ($startTime -eq $endTime) { return $true }
    if ($startTime -lt $endTime) { return $now -ge $startTime -and $now -lt $endTime }
    return $now -ge $startTime -or $now -lt $endTime
}

function Get-EffectiveMode {
    param($Config)
    if ($Config.controlMode -ne 'auto') { return [string]$Config.controlMode }
    if (Test-NightWindow -Start $Config.nightStart -End $Config.nightEnd) { return 'eco' }
    return 'balanced'
}

function Get-ProtectedStatus {
    $services = @('tor','Tailscale','chromoting','LanmanServer') | ForEach-Object {
        $service = Get-Service -Name $_ -ErrorAction SilentlyContinue
        [pscustomobject]@{
            name = $_
            running = $service -and $service.Status -eq 'Running'
            startType = if ($service) { [string]$service.StartType } else { 'Missing' }
        }
    }
    return [pscustomobject]@{
        services = @($services)
        snowflake = [bool](Get-Process -Name 'snowflake-proxy' -ErrorAction SilentlyContinue)
        sleepDisabled = $true
    }
}

function Get-ModePolicy {
    param([string]$EffectiveMode)
    if ($EffectiveMode -eq 'eco') {
        return [pscustomobject]@{
            cpuMaxPercent = 35
            cpuBoost = $false
            diskIdleMinutes = 10
            foldingCpuThreads = 1
            foldingGpuPreserved = $false
            boincCpuPercent = 10
        }
    }
    return [pscustomobject]@{
        cpuMaxPercent = 100
        cpuBoost = $EffectiveMode -eq 'performance'
        diskIdleMinutes = if ($EffectiveMode -eq 'performance') { 0 } else { 20 }
        foldingCpuThreads = 2
        foldingGpuPreserved = $true
        boincCpuPercent = 33
    }
}

function Set-BoincCpuBudget {
    param([int]$CpuPercent)
    if (-not (Test-Path -LiteralPath $boincPreferencesPath)) { return }
    [xml]$xml = Get-Content -LiteralPath $boincPreferencesPath -Raw
    $root = $xml.SelectSingleNode('/global_preferences')
    if (-not $root) { return }
    $changed = $false
    foreach ($name in @('max_ncpus_pct','cpu_usage_limit')) {
        $node = $root.SelectSingleNode($name)
        if (-not $node) {
            $node = $xml.CreateElement($name)
            [void]$root.AppendChild($node)
            $changed = $true
        }
        $desired = '{0}.000000' -f $CpuPercent
        if ($node.InnerText -ne $desired) {
            $node.InnerText = $desired
            $changed = $true
        }
    }
    if ($changed) {
        $xml.Save($boincPreferencesPath)
    }
    if ($changed -and (Test-Path -LiteralPath $boincCommandPath)) {
        & $boincCommandPath --read_global_prefs_override 2>$null | Out-Null
    }
}

function Set-VolunteerBudget {
    param([string]$EffectiveMode)
    $policy = Get-ModePolicy -EffectiveMode $EffectiveMode
    Set-BoincCpuBudget -CpuPercent $policy.boincCpuPercent
    $fahListening = Get-NetTCPConnection -LocalPort 7396 -State Listen -ErrorAction SilentlyContinue
    if ($fahListening -and (Test-Path -LiteralPath $fahControlPath) -and (Get-Command node.exe -ErrorAction SilentlyContinue)) {
        $fahMode = if ($EffectiveMode -eq 'eco') { 'eco' } else { 'balanced' }
        & node.exe $fahControlPath $fahMode 2>$null | Out-Null
    }
    return $policy
}

function Write-Status {
    param($Config,[string]$EffectiveMode,$EnergyPolicy)
    if (-not $EnergyPolicy) {
        $EnergyPolicy = Get-ModePolicy -EffectiveMode $EffectiveMode
    }
    $status = [ordered]@{
        available = $true
        product = 'daakLOLILE'
        controlMode = [string]$Config.controlMode
        effectiveMode = $EffectiveMode
        activeScheme = Get-ActiveScheme
        nightStart = [string]$Config.nightStart
        nightEnd = [string]$Config.nightEnd
        isNight = Test-NightWindow -Start $Config.nightStart -End $Config.nightEnd
        updatedAt = (Get-Date).ToUniversalTime().ToString('o')
        energyPolicy = $EnergyPolicy
        safeguards = Get-ProtectedStatus
    }
    $status | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statusPath -Encoding UTF8
    return [pscustomobject]$status
}

function Invoke-Tick {
    param($Config)
    $effective = Get-EffectiveMode -Config $Config
    $scheme = [string]$Config.schemes.$effective
    if (-not (Test-Scheme -Guid $scheme)) {
        throw "The daakLOLILE '$effective' power scheme is missing."
    }
    if ((Get-ActiveScheme) -ne $scheme.ToLowerInvariant()) {
        $null = Invoke-PowerCfg -Arguments @('/setactive',$scheme)
    }
    $policy = Set-VolunteerBudget -EffectiveMode $effective
    return Write-Status -Config $Config -EffectiveMode $effective -EnergyPolicy $policy
}

if (-not $mutex.WaitOne([TimeSpan]::FromSeconds(20))) {
    throw 'Another daakLOLILE power operation is still running.'
}

try {
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

    switch ($Action) {
        'Install' {
            $existing = $null
            try { $existing = Read-Config } catch {}
            $original = if ($existing.originalScheme) { [string]$existing.originalScheme } else { Get-ActiveScheme }
            $eco = if (Test-Scheme -Guid $existing.schemes.eco) { [string]$existing.schemes.eco } else {
                New-Scheme -Template 'SCHEME_MAX' -Name 'daakLOLILE Peak Saver' -Description 'Network and services stay online; volunteer computing uses minimum power during peak hours.'
            }
            $balanced = if (Test-Scheme -Guid $existing.schemes.balanced) { [string]$existing.schemes.balanced } else {
                New-Scheme -Template 'SCHEME_BALANCED' -Name 'daakLOLILE Balanced' -Description 'Everyday use; sleep stays disabled and remote access stays online.'
            }
            $performance = if (Test-Scheme -Guid $existing.schemes.performance) { [string]$existing.schemes.performance } else {
                New-Scheme -Template 'SCHEME_MIN' -Name 'daakLOLILE High Performance' -Description 'Full CPU performance; sleep stays disabled and remote access stays online.'
            }
            $null = Invoke-PowerCfg -Arguments @('/changename',$eco,'daakLOLILE Peak Saver','Network and services stay online; volunteer computing uses minimum power during peak hours.')
            $null = Invoke-PowerCfg -Arguments @('/changename',$balanced,'daakLOLILE Balanced','Everyday use; sleep stays disabled and remote access stays online.')
            $null = Invoke-PowerCfg -Arguments @('/changename',$performance,'daakLOLILE High Performance','Full CPU performance; sleep stays disabled and remote access stays online.')
            Set-EcoScheme -Scheme $eco
            Set-BalancedScheme -Scheme $balanced
            Set-PerformanceScheme -Scheme $performance
            $config = [pscustomobject]@{
                version = 1
                controlMode = if ($existing.controlMode) { [string]$existing.controlMode } else { 'auto' }
                nightStart = if ($existing.nightStart) { [string]$existing.nightStart } else { '17:00' }
                nightEnd = if ($existing.nightEnd) { [string]$existing.nightEnd } else { '22:00' }
                originalScheme = $original
                schemes = [pscustomobject]@{ eco=$eco; balanced=$balanced; performance=$performance }
                updatedAt = $null
            }
            Write-Config -Config $config
            Invoke-Tick -Config $config
        }
        'Set' {
            $config = Read-Config
            $config.controlMode = $Mode
            if ($PSBoundParameters.ContainsKey('NightStart')) { $config.nightStart = $NightStart }
            if ($PSBoundParameters.ContainsKey('NightEnd')) { $config.nightEnd = $NightEnd }
            Write-Config -Config $config
            Invoke-Tick -Config $config
        }
        'Tick' {
            Invoke-Tick -Config (Read-Config)
        }
        'Status' {
            $config = Read-Config
            Write-Status -Config $config -EffectiveMode (Get-EffectiveMode -Config $config)
        }
        'Restore' {
            $config = Read-Config
            if (Test-Scheme -Guid $config.originalScheme) {
                $null = Invoke-PowerCfg -Arguments @('/setactive',[string]$config.originalScheme)
            }
            Write-Status -Config $config -EffectiveMode 'restored'
        }
    }
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
