#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Maintain','Status')]
    [string]$Action = 'Maintain',
    [string]$InstallRoot = 'C:\ProgramData\daakLOLILE',
    [ValidateRange(70, 98)]
    [int]$PressureThresholdPercent = 85,
    [ValidateRange(512, 16384)]
    [int]$MinimumFreeMB = 2048,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$statusPath = Join-Path $InstallRoot 'memory-status.json'

function Get-MemorySnapshot {
    $operatingSystem = Get-CimInstance Win32_OperatingSystem
    $totalBytes = [int64]$operatingSystem.TotalVisibleMemorySize * 1KB
    $freeBytes = [int64]$operatingSystem.FreePhysicalMemory * 1KB
    $usedBytes = [Math]::Max([int64]0, [int64]($totalBytes - $freeBytes))
    $loadPercent = if ($totalBytes -gt 0) {
        [Math]::Round(($usedBytes / $totalBytes) * 100, 1)
    } else {
        0
    }
    [pscustomobject][ordered]@{
        totalBytes = $totalBytes
        usedBytes = $usedBytes
        freeBytes = $freeBytes
        loadPercent = $loadPercent
    }
}

function Write-Status {
    param([Parameter(Mandatory)]$Value)
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    $json = $Value | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($statusPath, $json, [Text.UTF8Encoding]::new($true))
}

function Get-ManagedProcesses {
    $escapedRoot = [regex]::Escape($InstallRoot)
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.ProcessId -ne $PID -and
            $_.Name -in @('node.exe','powershell.exe','pwsh.exe','LibreHardwareMonitor.exe') -and
            $_.CommandLine -match $escapedRoot
        }
}

function Invoke-WorkingSetTrim {
    param([Parameter(Mandatory)][int]$ProcessId)

    if (-not ('DaakLolile.NativeMemory' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace DaakLolile {
    public static class NativeMemory {
        private const uint PROCESS_SET_QUOTA = 0x0100;
        private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(uint access, bool inheritHandle, int processId);

        [DllImport("psapi.dll", SetLastError = true)]
        private static extern bool EmptyWorkingSet(IntPtr process);

        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr handle);

        public static bool Trim(int processId) {
            IntPtr handle = OpenProcess(
                PROCESS_SET_QUOTA | PROCESS_QUERY_LIMITED_INFORMATION,
                false,
                processId
            );
            if (handle == IntPtr.Zero) return false;
            try { return EmptyWorkingSet(handle); }
            finally { CloseHandle(handle); }
        }
    }
}
'@
    }

    [DaakLolile.NativeMemory]::Trim($ProcessId)
}

$before = Get-MemorySnapshot
$pressureDetected = (
    $before.loadPercent -ge $PressureThresholdPercent -and
    $before.freeBytes -le ([int64]$MinimumFreeMB * 1MB)
)
$trimmed = @()
$failed = @()
$decision = 'observed'
$message = 'Bellek baskısı yok; Windows önbelleği faydalı olduğu için korundu.'

if ($Action -eq 'Maintain' -and ($pressureDetected -or $Force)) {
    foreach ($process in @(Get-ManagedProcesses)) {
        try {
            if (Invoke-WorkingSetTrim -ProcessId $process.ProcessId) {
                $trimmed += [ordered]@{
                    name = $process.Name
                    processId = [int]$process.ProcessId
                }
            } else {
                $failed += $process.Name
            }
        } catch {
            $failed += $process.Name
        }
    }
    $decision = if ($trimmed.Count -gt 0) { 'trimmed-managed-only' } else { 'nothing-to-trim' }
    $message = if ($Force) {
        'Elle güvenli bakım yapıldı; yalnızca daakLOLILE yardımcı süreçleri ele alındı.'
    } else {
        'Yüksek bellek baskısı görüldü; yalnızca daakLOLILE yardımcı süreçleri küçültüldü.'
    }
}

Start-Sleep -Milliseconds 350
$after = Get-MemorySnapshot
$status = [pscustomobject][ordered]@{
    available = $true
    product = 'daakLOLILE'
    updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    action = $Action.ToLowerInvariant()
    decision = $decision
    message = $message
    pressureDetected = $pressureDetected
    thresholdPercent = $PressureThresholdPercent
    minimumFreeBytes = [int64]$MinimumFreeMB * 1MB
    before = $before
    after = $after
    reclaimedBytes = [Math]::Max([int64]0, [int64]($after.freeBytes - $before.freeBytes))
    managedProcessesTrimmed = @($trimmed)
    failedProcessNames = @($failed | Sort-Object -Unique)
    schedule = [ordered]@{
        dailyAt = '04:30'
        runsWithoutLogin = $true
    }
    policy = [ordered]@{
        automaticOnlyUnderPressure = $true
        preservesWindowsCache = -not ($pressureDetected -or $Force)
        protected = @(
            'Tor',
            'Snowflake',
            'Tailscale',
            'Chrome Remote Desktop',
            'Windows file sharing'
        )
    }
}

Write-Status -Value $status
$status
