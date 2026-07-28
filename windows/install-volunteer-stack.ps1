#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\ProgramData\daakLOLILE',
    [switch]$EnableRipeAtlasPrerequisites
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$downloadRoot = Join-Path $env:TEMP 'daakLOLILE-volunteer-install'
$boincDataRoot = 'C:\ProgramData\BOINC'
New-Item -ItemType Directory -Path $downloadRoot,$boincDataRoot -Force | Out-Null

$packages = @(
    [ordered]@{
        Name = 'Folding@home'
        Url = 'https://download.foldingathome.org/releases/public/fah-client/windows-10-64bit/release/fah-client_8.5.5_AMD64.exe'
        Path = Join-Path $downloadRoot 'fah-client_8.5.5_AMD64.exe'
        Sha256 = '718840240414EB065968A7A1A64B636F06857EA9AC284FBE4828CF21CD227EC9'
        Signer = 'Cauldron Development Oy'
        InstalledPath = 'C:\Program Files\FAHClient\FAHClient.exe'
    },
    [ordered]@{
        Name = 'BOINC'
        Url = 'https://boinc.berkeley.edu/dl/boinc_8.2.11_windows_x86_64.exe'
        Path = Join-Path $downloadRoot 'boinc_8.2.11_windows_x86_64.exe'
        Sha256 = '3C9992CD3EAFD90A65D45FDC8BD411ABD574E657710384966672AC0E264D92CB'
        Signer = 'BOINC'
        InstalledPath = 'C:\Program Files\BOINC\boinc.exe'
    }
)

foreach ($package in $packages) {
    if (-not (Test-Path -LiteralPath $package.InstalledPath)) {
        if (-not (Test-Path -LiteralPath $package.Path)) {
            Invoke-WebRequest -Uri $package.Url -OutFile $package.Path -UseBasicParsing
        }
        $hash = (Get-FileHash -LiteralPath $package.Path -Algorithm SHA256).Hash
        if ($hash -ne $package.Sha256) {
            throw "$($package.Name) checksum verification failed."
        }
        $signature = Get-AuthenticodeSignature -LiteralPath $package.Path
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch [regex]::Escape($package.Signer)) {
            throw "$($package.Name) digital signature verification failed."
        }
        $installer = $null
        $extractedMsi = if ($package.Name -eq 'BOINC') {
            Get-ChildItem 'C:\Windows\Downloaded Installations\BOINC' `
                -Filter 'BOINC.msi' -File -Recurse -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
        } else {
            $null
        }
        if ($extractedMsi) {
            $msiLog = Join-Path $downloadRoot 'boinc-msi.log'
            $msiArguments = @(
                '/i', "`"$($extractedMsi.FullName)`"",
                '/qn', '/norestart',
                'AgreeToLicense=Yes',
                'ENABLESCREENSAVER=0',
                'ENABLELAUNCHATLOGON=0',
                'ENABLEUSEBYALLUSERS=1',
                'LAUNCHPROGRAM=0',
                '/L*v', "`"$msiLog`""
            )
            $installer = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArguments -PassThru -Wait
        } else {
            $installer = Start-Process -FilePath $package.Path -ArgumentList '/S' -PassThru -Wait
        }
        if ($installer.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $package.InstalledPath)) {
            throw "$($package.Name) installation failed with exit code $($installer.ExitCode)."
        }
    }
}

$globalPreferences = @'
<global_preferences>
  <run_on_batteries>0</run_on_batteries>
  <run_if_user_active>1</run_if_user_active>
  <suspend_if_no_recent_input>0</suspend_if_no_recent_input>
  <max_ncpus_pct>33.000000</max_ncpus_pct>
  <cpu_usage_limit>33.000000</cpu_usage_limit>
  <ram_max_used_busy_pct>25.000000</ram_max_used_busy_pct>
  <ram_max_used_idle_pct>40.000000</ram_max_used_idle_pct>
  <disk_max_used_gb>5.000000</disk_max_used_gb>
  <disk_min_free_gb>20.000000</disk_min_free_gb>
  <work_buf_min_days>0.100000</work_buf_min_days>
  <work_buf_additional_days>0.250000</work_buf_additional_days>
</global_preferences>
'@
Set-Content -LiteralPath (Join-Path $boincDataRoot 'global_prefs_override.xml') -Value $globalPreferences -Encoding UTF8

$boincConfiguration = @'
<cc_config>
  <options>
    <no_gpus>1</no_gpus>
  </options>
</cc_config>
'@
Set-Content -LiteralPath (Join-Path $boincDataRoot 'cc_config.xml') -Value $boincConfiguration -Encoding UTF8

$boincService = Get-Service -Name BOINC -ErrorAction SilentlyContinue
if ($boincService) {
    Set-Service -Name BOINC -StartupType Automatic
    if ($boincService.Status -ne 'Running') {
        Start-Service -Name BOINC
    }
}

if ($EnableRipeAtlasPrerequisites) {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Null
    Write-Host 'RIPE Atlas prerequisites are enabled. A controlled reboot is required before the Linux probe can be installed.' -ForegroundColor Yellow
}

Write-Host 'Folding@home and BOINC are installed with conservative limits.' -ForegroundColor Green
Write-Host 'BOINC still needs a project account; daakLOLILE will show that state without storing a password.'
