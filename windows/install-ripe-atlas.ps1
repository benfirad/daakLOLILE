#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\ProgramData\daakLOLILE',
    [string]$Distro = 'Debian'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$volunteerRoot = Join-Path $InstallRoot 'volunteer'
$statusPath = Join-Path $volunteerRoot 'ripe-atlas-install.json'
$probeKeyPath = Join-Path $volunteerRoot 'ripe-atlas-probe-key.pub'
New-Item -ItemType Directory -Path $volunteerRoot -Force | Out-Null
$createdNew = $false
$installMutex = New-Object System.Threading.Mutex($true, 'Global\daakLOLILERipeInstaller', [ref]$createdNew)
if (-not $createdNew) {
    exit 0
}

function Write-InstallState {
    param(
        [Parameter(Mandatory)][string]$State,
        [Parameter(Mandatory)][string]$Detail,
        [bool]$RebootRequired = $false
    )
    [ordered]@{
        updatedAt = [DateTime]::UtcNow.ToString('o')
        state = $State
        detail = $Detail
        rebootRequired = $RebootRequired
        registrationUrl = 'https://atlas.ripe.net/apply/swprobe/'
        publicKeyPath = $probeKeyPath
        diskSharing = $false
        inboundPortRequired = $false
    } | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath $statusPath -Encoding UTF8
}

function Test-RebootPending {
    [bool](
        (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
        (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
        (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
    )
}

try {
    $wslFeature = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State
    $vmFeature = (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State
    if ($wslFeature -ne 'Enabled' -or $vmFeature -ne 'Enabled') {
        Write-InstallState `
            -State 'reboot-required' `
            -Detail 'WSL bileşenleri etkinleştirildi; güvenli bir yeniden başlatma bekleniyor.' `
            -RebootRequired $true
        exit 3010
    }

    $distroNames = @(& wsl.exe --list --quiet 2>$null) |
        ForEach-Object { ([string]$_).Replace([char]0, '').Trim() } |
        Where-Object { $_ }
    if ($Distro -notin $distroNames) {
        Write-InstallState `
            -State 'installing-distro' `
            -Detail 'Resmi Debian WSL ortamı kuruluyor.'
        & wsl.exe --install -d $Distro --no-launch
        if ($LASTEXITCODE -notin @(0,3010)) {
            if (Test-RebootPending) {
                Write-InstallState `
                    -State 'reboot-required' `
                    -Detail 'Windows değişiklikleri hazır; Debian ve RIPE Atlas kurulumu yeniden başlatmadan sonra otomatik tamamlanacak.' `
                    -RebootRequired $true
                exit 3010
            }
            throw "Debian WSL installation failed with exit code $LASTEXITCODE."
        }
    }

    & wsl.exe -d $Distro -u root -- true
    if ($LASTEXITCODE -ne 0) {
        Write-InstallState `
            -State 'reboot-required' `
            -Detail 'Debian hazırlandı; kurulumu tamamlamak için bir yeniden başlatma gerekiyor.' `
            -RebootRequired $true
        exit 3010
    }

    Write-InstallState `
        -State 'installing-probe' `
        -Detail 'RIPE Atlas resmi paketi indiriliyor ve doğrulanıyor.'

    $linuxInstaller = @'
set -eu
export DEBIAN_FRONTEND=noninteractive
ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && printf '%s' "$VERSION_CODENAME")"
case "$CODENAME" in
  bullseye|bookworm|trixie) ;;
  *) echo "Unsupported Debian release: $CODENAME" >&2; exit 20 ;;
esac
case "$ARCH" in
  amd64|arm64) ;;
  *) echo "Unsupported Debian architecture: $ARCH" >&2; exit 21 ;;
esac
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
REPO_PKG=ripe-atlas-repo_1.5-5_all.deb
curl --fail --location --silent --show-error \
  --output "$REPO_PKG" \
  "https://ftp.ripe.net/ripe/atlas/software-probe/debian/dists/$CODENAME/main/binary-$ARCH/$REPO_PKG"
curl --fail --location --silent --show-error \
  --output CHECKSUMS \
  "https://github.com/RIPE-NCC/ripe-atlas-software-probe/releases/latest/download/CHECKSUMS"
sha256sum "$REPO_PKG" > actual.sha256
grep -Fq "$(cat actual.sha256)" CHECKSUMS
dpkg -i "$REPO_PKG"
apt-get update
apt-get install -y --no-install-recommends ripe-atlas-probe unattended-upgrades
install -d -m 0755 /etc/ripe-atlas
printf '%s\n' 'RXTXRPT=no' > /etc/ripe-atlas/config.txt
systemctl enable ripe-atlas-probe.service 2>/dev/null || true
systemctl restart ripe-atlas-probe.service 2>/dev/null || service ripe-atlas-probe restart
test -s /etc/ripe-atlas/probe_key.pub
'@
    $linuxInstaller | & wsl.exe -d $Distro -u root -- bash -s
    if ($LASTEXITCODE -ne 0) {
        throw "RIPE Atlas package installation failed with exit code $LASTEXITCODE."
    }

    $publicKey = (& wsl.exe -d $Distro -u root -- cat /etc/ripe-atlas/probe_key.pub 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($publicKey)) {
        throw 'RIPE Atlas probe public key was not generated.'
    }
    Set-Content -LiteralPath $probeKeyPath -Value $publicKey -Encoding ASCII

    Write-InstallState `
        -State 'account-required' `
        -Detail 'Prob hazır. RIPE NCC hesabında anahtarı kaydetmen gerekiyor.'
    exit 0
} catch {
    Write-InstallState `
        -State 'error' `
        -Detail $_.Exception.Message
    throw
}
