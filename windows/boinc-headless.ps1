#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Enforce','Restore','Status')]
    [string]$Action = 'Enforce',
    [string]$InstallRoot = 'C:\ProgramData\daakLOLILE'
)

$ErrorActionPreference = 'Stop'
$managerPath = 'C:\Program Files\BOINC\boincmgr.exe'
$dataRoot = Join-Path $InstallRoot 'data'
$statusPath = Join-Path $dataRoot 'boinc-headless-status.json'
$backupPath = Join-Path $dataRoot 'boinc-manager-autostart-backup.json'
$aclMarkerPath = Join-Path $dataRoot 'boinc-manager-acl-owned.json'
$usersSid = 'S-1-5-32-545'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-AutostartLocations {
    $locations = @(
        'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run',
        'Registry::HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    Get-ChildItem -LiteralPath 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^S-1-5-21-(?:\d+-){3}\d+$' } |
        ForEach-Object {
            $locations += "Registry::HKEY_USERS\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Run"
        }
    return @($locations | Select-Object -Unique)
}

function Get-BoincManagerAutostart {
    $entries = @()
    foreach ($location in Get-AutostartLocations) {
        if (-not (Test-Path -LiteralPath $location)) {
            continue
        }
        $properties = Get-ItemProperty -LiteralPath $location
        foreach ($property in $properties.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }) {
            $value = [string]$property.Value
            if ($property.Name -match '^(?i:BOINC(?: Manager)?)$' -or $value -match '(?i)boincmgr(?:\.exe)?') {
                $entries += [pscustomobject]@{
                    location = $location
                    name = $property.Name
                    value = $value
                }
            }
        }
    }
    return $entries
}

function Test-ManagerExecuteBlocked {
    if (-not (Test-Path -LiteralPath $managerPath)) {
        return $false
    }
    $acl = Get-Acl -LiteralPath $managerPath
    foreach ($rule in $acl.Access) {
        try {
            $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        } catch {
            continue
        }
        if (
            $sid -eq $usersSid -and
            $rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Deny -and
            ($rule.FileSystemRights -band [Security.AccessControl.FileSystemRights]::ExecuteFile)
        ) {
            return $true
        }
    }
    return $false
}

function Get-ManagerExecuteDenyRules {
    if (-not (Test-Path -LiteralPath $managerPath)) {
        return @()
    }
    $matches = @()
    foreach ($rule in (Get-Acl -LiteralPath $managerPath).Access) {
        try {
            $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        } catch {
            continue
        }
        if (
            $sid -eq $usersSid -and
            $rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Deny -and
            ($rule.FileSystemRights -band [Security.AccessControl.FileSystemRights]::ExecuteFile)
        ) {
            $matches += $rule
        }
    }
    return $matches
}

function Set-OwnedManagerExecuteBlock {
    $acl = Get-Acl -LiteralPath $managerPath
    foreach ($rule in @(Get-ManagerExecuteDenyRules)) {
        [void]$acl.RemoveAccessRuleSpecific($rule)
    }
    $identity = New-Object Security.Principal.SecurityIdentifier($usersSid)
    $denyExecute = New-Object Security.AccessControl.FileSystemAccessRule(
        $identity,
        [Security.AccessControl.FileSystemRights]::ExecuteFile,
        [Security.AccessControl.AccessControlType]::Deny
    )
    [void]$acl.AddAccessRule($denyExecute)
    Set-Acl -LiteralPath $managerPath -AclObject $acl
}

function Save-Status {
    param([array]$RemovedEntries = @())
    New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
    $service = Get-CimInstance Win32_Service -Filter "Name='BOINC'" -ErrorAction SilentlyContinue
    [ordered]@{
        checkedAt = [DateTime]::UtcNow.ToString('o')
        action = $Action
        managerRunning = [bool](Get-Process boincmgr -ErrorAction SilentlyContinue)
        managerExecuteBlocked = Test-ManagerExecuteBlocked
        removedAutostartEntries = @($RemovedEntries).Count
        boincServiceState = if ($service) { $service.State } else { 'NotInstalled' }
        boincServiceStartMode = if ($service) { $service.StartMode } else { 'NotInstalled' }
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statusPath -Encoding UTF8
    Get-Content -LiteralPath $statusPath -Raw
}

if ($Action -eq 'Status') {
    Save-Status
    exit 0
}

if (-not (Test-IsAdministrator)) {
    throw 'BOINC headless enforcement requires administrator rights.'
}

New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null

if ($Action -eq 'Restore') {
    if ((Test-Path -LiteralPath $managerPath) -and (Test-Path -LiteralPath $aclMarkerPath)) {
        $acl = Get-Acl -LiteralPath $managerPath
        foreach ($rule in @($acl.Access)) {
            try {
                $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            } catch {
                continue
            }
            if (
                $sid -eq $usersSid -and
                $rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Deny -and
                ($rule.FileSystemRights -band [Security.AccessControl.FileSystemRights]::ExecuteFile)
            ) {
                [void]$acl.RemoveAccessRuleSpecific($rule)
            }
        }
        Set-Acl -LiteralPath $managerPath -AclObject $acl
        Remove-Item -LiteralPath $aclMarkerPath -Force
    }
    if (Test-Path -LiteralPath $backupPath) {
        $backup = @(Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json)
        foreach ($entry in $backup) {
            if (Test-Path -LiteralPath $entry.location) {
                Set-ItemProperty -LiteralPath $entry.location -Name $entry.name -Value $entry.value
            }
        }
    }
    Save-Status
    exit 0
}

Get-Process boincmgr -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

$removedEntries = @(Get-BoincManagerAutostart)
if ($removedEntries.Count -gt 0) {
    $existingBackup = @()
    if (Test-Path -LiteralPath $backupPath) {
        $existingBackup = @(Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json)
    }
    @($existingBackup + $removedEntries |
        Group-Object { "$($_.location)|$($_.name)" } |
        ForEach-Object { $_.Group[-1] }) |
        ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath $backupPath -Encoding UTF8

    foreach ($entry in $removedEntries) {
        Remove-ItemProperty -LiteralPath $entry.location -Name $entry.name -Force
    }
}

if (Test-Path -LiteralPath $managerPath) {
    if (Test-Path -LiteralPath $aclMarkerPath) {
        $ownedRules = @(Get-ManagerExecuteDenyRules)
        if ($ownedRules.Count -ne 1) {
            Set-OwnedManagerExecuteBlock
        }
    } elseif (-not (Test-ManagerExecuteBlocked)) {
        Set-OwnedManagerExecuteBlock
        [ordered]@{
            createdAt = [DateTime]::UtcNow.ToString('o')
            managerPath = $managerPath
            deniedSid = $usersSid
            deniedRight = 'ExecuteFile'
        } | ConvertTo-Json | Set-Content -LiteralPath $aclMarkerPath -Encoding UTF8
    }
}

$boincService = Get-Service -Name BOINC -ErrorAction SilentlyContinue
if ($boincService) {
    Set-Service -Name BOINC -StartupType Automatic
    if ($boincService.Status -ne 'Running') {
        Start-Service -Name BOINC
    }
}

Save-Status -RemovedEntries $removedEntries
