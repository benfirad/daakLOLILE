#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\ProgramData\LOLILE',
    [int]$SampleSeconds = 2
)

$ErrorActionPreference = 'Stop'
$libraryPath = Join-Path $InstallRoot 'lib\LibreHardwareMonitorLib.dll'
$statusPath = Join-Path $InstallRoot 'hardware-status.json'
$energyPath = Join-Path $InstallRoot 'energy.json'
$logPath = Join-Path $InstallRoot 'hardware-monitor.log'
$tempStatusPath = Join-Path $InstallRoot 'hardware-status.new.json'
$tempEnergyPath = Join-Path $InstallRoot 'energy.new.json'

function Write-MonitorLog {
    param([Parameter(Mandatory)][string]$Message)

    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    if ((Get-Item -LiteralPath $logPath).Length -gt 2MB) {
        $tail = Get-Content -LiteralPath $logPath -Tail 1500
        Set-Content -LiteralPath $logPath -Value $tail -Encoding UTF8
    }
}

function Write-AtomicJson {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Temporary
    )

    $json = $Value | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText($Temporary, $json, [Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $Destination) {
        $backup = "$Destination.previous"
        [IO.File]::Replace($Temporary, $Destination, $backup, $true)
        if (Test-Path -LiteralPath $backup) {
            [IO.File]::Delete($backup)
        }
    }
    else {
        [IO.File]::Move($Temporary, $Destination)
    }
}

function Add-HardwareSensors {
    param(
        [Parameter(Mandatory)][LibreHardwareMonitor.Hardware.IHardware]$Hardware,
        [System.Collections.Generic.List[object]]$Target
    )

    $Hardware.Update()
    foreach ($sensor in $Hardware.Sensors) {
        if ($null -ne $sensor.Value) {
            $Target.Add([pscustomobject]@{
                HardwareType = $Hardware.HardwareType.ToString()
                Hardware     = $Hardware.Name
                SensorType   = $sensor.SensorType.ToString()
                Sensor       = $sensor.Name
                Value        = [double]$sensor.Value
                Identifier   = $sensor.Identifier.ToString()
            })
        }
    }

    foreach ($subHardware in $Hardware.SubHardware) {
        Add-HardwareSensors -Hardware $subHardware -Target $Target
    }
}

function Find-SensorValue {
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)][string]$SensorType,
        [Parameter(Mandatory)][string]$SensorPattern,
        [string]$HardwareType,
        [string]$HardwarePattern
    )

    $match = $Rows |
        Where-Object {
            $_.SensorType -eq $SensorType -and
            $_.Sensor -match $SensorPattern -and
            (-not $HardwareType -or $_.HardwareType -eq $HardwareType) -and
            (-not $HardwarePattern -or $_.Hardware -match $HardwarePattern)
        } |
        Select-Object -First 1

    if ($match) {
        return [double]$match.Value
    }
    return $null
}

function Clamp-Percent {
    param($Value)
    if ($null -eq $Value -or [double]::IsNaN([double]$Value) -or [double]::IsInfinity([double]$Value)) { return 0.0 }
    return [Math]::Round([Math]::Min(100, [Math]::Max(0, [double]$Value)), 1)
}

function Read-Volumes {
    @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue |
        Where-Object { $_.Size -gt 0 } |
        Sort-Object DeviceID |
        ForEach-Object {
            [ordered]@{
                name        = $_.DeviceID
                label       = [string]$_.VolumeName
                totalBytes  = [double]$_.Size
                freeBytes   = [double]$_.FreeSpace
                usedPercent = [Math]::Round((1 - ([double]$_.FreeSpace / [double]$_.Size)) * 100, 1)
            }
        })
}

function Read-DiskActivity {
    $disk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_LogicalDisk -ErrorAction SilentlyContinue |
        Where-Object Name -eq '_Total' |
        Select-Object -First 1
    if (-not $disk) {
        return [ordered]@{ activePercent = 0.0; readBytesPerSecond = 0.0; writeBytesPerSecond = 0.0 }
    }
    return [ordered]@{
        activePercent       = Clamp-Percent $disk.PercentDiskTime
        readBytesPerSecond  = [double]$disk.DiskReadBytesPersec
        writeBytesPerSecond = [double]$disk.DiskWriteBytesPersec
    }
}

if (-not (Test-Path -LiteralPath $libraryPath)) {
    throw "LibreHardwareMonitor library is missing: $libraryPath"
}
if ($SampleSeconds -lt 1) {
    $SampleSeconds = 2
}

Set-Location -LiteralPath $InstallRoot
[void][Reflection.Assembly]::LoadFrom($libraryPath)

$computer = [LibreHardwareMonitor.Hardware.Computer]::new()
$computer.IsCpuEnabled = $true
$computer.IsGpuEnabled = $true
$computer.IsMemoryEnabled = $true
$computer.IsMotherboardEnabled = $true
$computer.IsStorageEnabled = $true
$computer.IsNetworkEnabled = $true

$computerSystem = Get-CimInstance Win32_ComputerSystem
$processorInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
$operatingSystem = Get-CimInstance Win32_OperatingSystem
$logicalProcessors = [Math]::Max(1, [int]$computerSystem.NumberOfLogicalProcessors)
$machineName = $env:COMPUTERNAME
$cpuName = [string]$processorInfo.Name
$cpuTdpWatts = 95.0
$baseSystemWatts = 32.0
$psuEfficiency = 0.87

$energy = [ordered]@{
    day       = (Get-Date -Format 'yyyy-MM-dd')
    month     = (Get-Date -Format 'yyyy-MM')
    todayWh   = 0.0
    monthWh   = 0.0
    updatedAt = (Get-Date).ToString('o')
}
if (Test-Path -LiteralPath $energyPath) {
    try {
        $saved = Get-Content -LiteralPath $energyPath -Raw | ConvertFrom-Json
        $energy.day = [string]$saved.day
        $energy.month = [string]$saved.month
        $energy.todayWh = [double]$saved.todayWh
        $energy.monthWh = [double]$saved.monthWh
        $energy.updatedAt = [string]$saved.updatedAt
    }
    catch {
        Write-MonitorLog 'Energy history could not be read and was reset.'
    }
}

$previousProcessCpu = @{}
$previousSampleAt = Get-Date
$previousWallWatts = $null
$lastEnergySave = [DateTime]::MinValue

try {
    $computer.Open()
    Write-MonitorLog 'Hardware monitor started.'

    while ($true) {
        $sampleStarted = Get-Date
        try {
            $rows = [System.Collections.Generic.List[object]]::new()
            foreach ($hardware in $computer.Hardware) {
                Add-HardwareSensors -Hardware $hardware -Target $rows
            }
            $sensorRows = @($rows)

            $cpuLoad = Clamp-Percent (Find-SensorValue -Rows $sensorRows -SensorType 'Load' -SensorPattern '^CPU Total$' -HardwareType 'Cpu')
            $cpuCoreMax = Clamp-Percent (Find-SensorValue -Rows $sensorRows -SensorType 'Load' -SensorPattern '^CPU Core Max$' -HardwareType 'Cpu')
            $cpuTemperature = Find-SensorValue -Rows $sensorRows -SensorType 'Temperature' -SensorPattern 'Tctl|Tdie|CPU Package|Core Average' -HardwareType 'Cpu'
            if ($null -ne $cpuTemperature -and $cpuTemperature -le 1) { $cpuTemperature = $null }
            $cpuPowerSensor = Find-SensorValue -Rows $sensorRows -SensorType 'Power' -SensorPattern '^Package$|CPU Package' -HardwareType 'Cpu'
            if ($null -ne $cpuPowerSensor -and $cpuPowerSensor -le 1) { $cpuPowerSensor = $null }
            $cpuClocks = @($sensorRows | Where-Object {
                $_.HardwareType -eq 'Cpu' -and $_.SensorType -eq 'Clock' -and $_.Sensor -match '^CPU Core #'
            } | Select-Object -ExpandProperty Value)
            $cpuClock = if ($cpuClocks.Count) {
                [Math]::Round(($cpuClocks | Measure-Object -Average).Average, 0)
            } else { $null }

            $cpuEstimatedWatts = [Math]::Round(15 + (($cpuTdpWatts - 15) * [Math]::Pow($cpuLoad / 100, 1.28)), 1)
            $cpuWatts = if ($null -ne $cpuPowerSensor) { [Math]::Round($cpuPowerSensor, 1) } else { $cpuEstimatedWatts }
            $cpuPowerSource = if ($null -ne $cpuPowerSensor) { 'sensor' } else { 'estimate' }

            $gpuHardware = $sensorRows | Where-Object HardwareType -match '^Gpu' | Select-Object -First 1
            $gpuName = if ($gpuHardware) { [string]$gpuHardware.Hardware } else { 'GPU' }
            $gpuLoad = Clamp-Percent (Find-SensorValue -Rows $sensorRows -SensorType 'Load' -SensorPattern '^GPU Core$' -HardwareType 'GpuAmd')
            $gpuTemperature = Find-SensorValue -Rows $sensorRows -SensorType 'Temperature' -SensorPattern '^GPU Core$|GPU Temperature' -HardwareType 'GpuAmd'
            $gpuPowerSensor = Find-SensorValue -Rows $sensorRows -SensorType 'Power' -SensorPattern 'GPU Package|GPU Board' -HardwareType 'GpuAmd'
            if ($null -ne $gpuPowerSensor -and $gpuPowerSensor -le 1) { $gpuPowerSensor = $null }
            $gpuEstimatedWatts = [Math]::Round(22 + (163 * [Math]::Pow($gpuLoad / 100, 1.18)), 1)
            $gpuWatts = if ($null -ne $gpuPowerSensor) { [Math]::Round($gpuPowerSensor, 1) } else { $gpuEstimatedWatts }
            $gpuPowerSource = if ($null -ne $gpuPowerSensor) { 'sensor' } else { 'estimate' }
            $gpuFan = Find-SensorValue -Rows $sensorRows -SensorType 'Fan' -SensorPattern '^GPU Fan$' -HardwareType 'GpuAmd'
            $vramUsedMB = Find-SensorValue -Rows $sensorRows -SensorType 'SmallData' -SensorPattern '^GPU Memory Used$' -HardwareType 'GpuAmd'
            $vramTotalMB = Find-SensorValue -Rows $sensorRows -SensorType 'SmallData' -SensorPattern '^GPU Memory Total$' -HardwareType 'GpuAmd'

            $memoryLoad = Clamp-Percent (Find-SensorValue -Rows $sensorRows -SensorType 'Load' -SensorPattern '^Memory$' -HardwareType 'Memory' -HardwarePattern '^Total Memory$')
            $memoryUsedGB = Find-SensorValue -Rows $sensorRows -SensorType 'Data' -SensorPattern '^Memory Used$' -HardwareType 'Memory' -HardwarePattern '^Total Memory$'
            $memoryAvailableGB = Find-SensorValue -Rows $sensorRows -SensorType 'Data' -SensorPattern '^Memory Available$' -HardwareType 'Memory' -HardwarePattern '^Total Memory$'

            $ethernetDown = Find-SensorValue -Rows $sensorRows -SensorType 'Throughput' -SensorPattern '^Download Speed$' -HardwareType 'Network' -HardwarePattern '^Ethernet$'
            $ethernetUp = Find-SensorValue -Rows $sensorRows -SensorType 'Throughput' -SensorPattern '^Upload Speed$' -HardwareType 'Network' -HardwarePattern '^Ethernet$'
            $tailscaleDown = Find-SensorValue -Rows $sensorRows -SensorType 'Throughput' -SensorPattern '^Download Speed$' -HardwareType 'Network' -HardwarePattern '^Tailscale$'
            $tailscaleUp = Find-SensorValue -Rows $sensorRows -SensorType 'Throughput' -SensorPattern '^Upload Speed$' -HardwareType 'Network' -HardwarePattern '^Tailscale$'

            $componentWatts = $cpuWatts + $gpuWatts + $baseSystemWatts
            $wallWatts = [Math]::Round($componentWatts / $psuEfficiency, 1)
            $wallLow = [Math]::Round($wallWatts * 0.78, 0)
            $wallHigh = [Math]::Round($wallWatts * 1.22, 0)

            $elapsedHours = [Math]::Min(30, [Math]::Max(0, ($sampleStarted - $previousSampleAt).TotalSeconds)) / 3600
            if ($null -ne $previousWallWatts -and $elapsedHours -gt 0) {
                $addedWh = (($previousWallWatts + $wallWatts) / 2) * $elapsedHours
                $energy.todayWh = [double]$energy.todayWh + $addedWh
                $energy.monthWh = [double]$energy.monthWh + $addedWh
            }
            $today = $sampleStarted.ToString('yyyy-MM-dd')
            $month = $sampleStarted.ToString('yyyy-MM')
            if ($energy.day -ne $today) {
                $energy.day = $today
                $energy.todayWh = 0.0
            }
            if ($energy.month -ne $month) {
                $energy.month = $month
                $energy.monthWh = 0.0
            }
            $energy.updatedAt = $sampleStarted.ToString('o')

            $processes = @(Get-Process -ErrorAction SilentlyContinue)
            $processMetrics = foreach ($process in $processes) {
                $cpuSeconds = if ($null -ne $process.CPU) { [double]$process.CPU } else { 0.0 }
                $previousCpu = $previousProcessCpu[$process.Id]
                $processCpu = 0.0
                $elapsedSeconds = [Math]::Max(0.1, ($sampleStarted - $previousSampleAt).TotalSeconds)
                if ($null -ne $previousCpu -and $cpuSeconds -ge $previousCpu) {
                    $processCpu = (($cpuSeconds - $previousCpu) / $elapsedSeconds / $logicalProcessors) * 100
                }
                [pscustomobject]@{
                    id          = $process.Id
                    name        = $process.ProcessName
                    cpuPercent  = [Math]::Round([Math]::Min(100, [Math]::Max(0, $processCpu)), 1)
                    memoryBytes = [double]$process.WorkingSet64
                    cpuSeconds  = $cpuSeconds
                }
            }
            $previousProcessCpu = @{}
            foreach ($processMetric in $processMetrics) {
                $previousProcessCpu[$processMetric.id] = $processMetric.cpuSeconds
            }
            $topProcesses = @($processMetrics |
                Sort-Object @{Expression='cpuPercent';Descending=$true}, @{Expression='memoryBytes';Descending=$true} |
                Select-Object -First 6 |
                ForEach-Object {
                    [ordered]@{
                        id          = $_.id
                        name        = $_.name
                        cpuPercent  = $_.cpuPercent
                        memoryBytes = $_.memoryBytes
                    }
                })

            $bootTime = if ($operatingSystem.LastBootUpTime -is [DateTime]) {
                [DateTime]$operatingSystem.LastBootUpTime
            }
            else {
                [Management.ManagementDateTimeConverter]::ToDateTime([string]$operatingSystem.LastBootUpTime)
            }
            $uptimeSeconds = [Math]::Max(0, ($sampleStarted - $bootTime).TotalSeconds)
            $disk = Read-DiskActivity
            $memoryUsedBytes = if ($null -ne $memoryUsedGB) { [double]$memoryUsedGB * 1GB } else { 0.0 }
            $memoryAvailableBytes = if ($null -ne $memoryAvailableGB) { [double]$memoryAvailableGB * 1GB } else { 0.0 }

            $status = [ordered]@{
                available = $true
                updatedAt = $sampleStarted.ToString('o')
                sampleIntervalSeconds = $SampleSeconds
                source = [ordered]@{
                    name = 'LibreHardwareMonitor'
                    version = '0.9.6'
                    repository = 'https://github.com/LibreHardwareMonitor/LibreHardwareMonitor'
                }
                machine = [ordered]@{
                    name = $machineName
                    model = ('{0} {1}' -f $computerSystem.Manufacturer, $computerSystem.Model).Trim()
                    uptimeSeconds = [Math]::Round($uptimeSeconds)
                }
                power = [ordered]@{
                    wallEstimateWatts = $wallWatts
                    wallEstimateLowWatts = $wallLow
                    wallEstimateHighWatts = $wallHigh
                    componentWatts = [Math]::Round($cpuWatts + $gpuWatts, 1)
                    systemBaseEstimateWatts = $baseSystemWatts
                    psuEfficiencyEstimate = $psuEfficiency
                    todayKWh = [Math]::Round([double]$energy.todayWh / 1000, 4)
                    monthKWh = [Math]::Round([double]$energy.monthWh / 1000, 4)
                    accuracy = if ($cpuPowerSource -eq 'sensor' -and $gpuPowerSource -eq 'sensor') { 'mixed-estimate' } else { 'estimated' }
                    note = 'Estimate only: no wall power meter is connected.'
                }
                cpu = [ordered]@{
                    name = $cpuName.Trim()
                    loadPercent = $cpuLoad
                    maxCorePercent = $cpuCoreMax
                    temperatureC = if ($null -ne $cpuTemperature) { [Math]::Round($cpuTemperature, 1) } else { $null }
                    clockMHz = $cpuClock
                    powerWatts = $cpuWatts
                    powerSource = $cpuPowerSource
                    tdpWatts = $cpuTdpWatts
                }
                gpu = [ordered]@{
                    name = $gpuName
                    loadPercent = $gpuLoad
                    temperatureC = if ($null -ne $gpuTemperature) { [Math]::Round($gpuTemperature, 1) } else { $null }
                    powerWatts = $gpuWatts
                    powerSource = $gpuPowerSource
                    fanRpm = if ($null -ne $gpuFan) { [Math]::Round($gpuFan) } else { $null }
                    memoryUsedBytes = if ($null -ne $vramUsedMB) { [double]$vramUsedMB * 1MB } else { 0.0 }
                    memoryTotalBytes = if ($null -ne $vramTotalMB) { [double]$vramTotalMB * 1MB } else { 0.0 }
                }
                memory = [ordered]@{
                    loadPercent = $memoryLoad
                    usedBytes = $memoryUsedBytes
                    availableBytes = $memoryAvailableBytes
                    totalBytes = $memoryUsedBytes + $memoryAvailableBytes
                }
                disk = [ordered]@{
                    activePercent = $disk.activePercent
                    readBytesPerSecond = $disk.readBytesPerSecond
                    writeBytesPerSecond = $disk.writeBytesPerSecond
                    volumes = @(Read-Volumes)
                }
                network = [ordered]@{
                    ethernet = [ordered]@{
                        downloadBytesPerSecond = if ($null -ne $ethernetDown) { [double]$ethernetDown } else { 0.0 }
                        uploadBytesPerSecond = if ($null -ne $ethernetUp) { [double]$ethernetUp } else { 0.0 }
                    }
                    tailscale = [ordered]@{
                        downloadBytesPerSecond = if ($null -ne $tailscaleDown) { [double]$tailscaleDown } else { 0.0 }
                        uploadBytesPerSecond = if ($null -ne $tailscaleUp) { [double]$tailscaleUp } else { 0.0 }
                    }
                }
                processes = $topProcesses
            }

            Write-AtomicJson -Value $status -Destination $statusPath -Temporary $tempStatusPath
            if (($sampleStarted - $lastEnergySave).TotalSeconds -ge 30) {
                Write-AtomicJson -Value $energy -Destination $energyPath -Temporary $tempEnergyPath
                $lastEnergySave = $sampleStarted
            }

            $previousSampleAt = $sampleStarted
            $previousWallWatts = $wallWatts
        }
        catch {
            Write-MonitorLog ("Sample error: {0}" -f $_.Exception.Message)
        }

        $elapsed = ((Get-Date) - $sampleStarted).TotalMilliseconds
        $remaining = [Math]::Max(150, ($SampleSeconds * 1000) - $elapsed)
        Start-Sleep -Milliseconds ([int]$remaining)
    }
}
finally {
    try { $computer.Close() } catch {}
    Write-MonitorLog 'Hardware monitor stopped.'
}
