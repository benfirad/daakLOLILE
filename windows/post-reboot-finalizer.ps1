#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\ProgramData\daakLOLILE'
)

$ErrorActionPreference = 'Stop'
$resultPath = Join-Path $InstallRoot 'post-reboot-result.json'
$volunteerInstaller = Join-Path $InstallRoot 'install-volunteer-stack.ps1'
$ripeInstaller = Join-Path $InstallRoot 'install-ripe-atlas.ps1'
$powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

try {
    $volunteerProcess = Start-Process `
        -FilePath $powerShell `
        -ArgumentList @(
            '-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
            '-File',"`"$volunteerInstaller`"",
            '-InstallRoot',"`"$InstallRoot`"",
            '-EnableRipeAtlasPrerequisites'
        ) `
        -WindowStyle Hidden `
        -PassThru `
        -Wait
    if ($volunteerProcess.ExitCode -notin @(0,3010)) {
        throw "Volunteer stack installer returned exit code $($volunteerProcess.ExitCode)."
    }

    $ripeProcess = Start-Process `
        -FilePath $powerShell `
        -ArgumentList @(
            '-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
            '-File',"`"$ripeInstaller`"",
            '-InstallRoot',"`"$InstallRoot`""
        ) `
        -WindowStyle Hidden `
        -PassThru `
        -Wait
    $ripeExit = $ripeProcess.ExitCode
    $boinc = Get-Service -Name BOINC -ErrorAction SilentlyContinue
    $ripeStatePath = Join-Path $InstallRoot 'volunteer\ripe-atlas-install.json'
    $ripeState = if (Test-Path -LiteralPath $ripeStatePath) {
        Get-Content -LiteralPath $ripeStatePath -Raw | ConvertFrom-Json
    } else {
        $null
    }

    $complete = (
        $boinc -and
        $boinc.Status -eq 'Running' -and
        $boinc.StartType -eq 'Automatic' -and
        $ripeState.state -eq 'account-required'
    )
    [ordered]@{
        ok = $complete
        completedAt = [DateTime]::UtcNow.ToString('o')
        boincRunning = [bool]$boinc -and $boinc.Status -eq 'Running'
        boincAutomatic = [bool]$boinc -and $boinc.StartType -eq 'Automatic'
        ripeState = if ($ripeState) { [string]$ripeState.state } else { 'unknown' }
        ripeExitCode = $ripeExit
        registrationUrl = 'https://atlas.ripe.net/apply/swprobe/'
        remoteAccessPreserved = $true
    } | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath $resultPath -Encoding UTF8

    if ($complete) {
        Unregister-ScheduledTask -TaskName 'daakLOLILE Post-Reboot Finalizer' -Confirm:$false -ErrorAction SilentlyContinue
    }
} catch {
    [ordered]@{
        ok = $false
        failedAt = [DateTime]::UtcNow.ToString('o')
        message = $_.Exception.Message
        remoteAccessPreserved = $true
    } | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath $resultPath -Encoding UTF8
    throw
}
