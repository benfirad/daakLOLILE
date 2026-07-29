$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$powerShellFiles = @(
    'windows\install.ps1',
    'windows\uninstall.ps1',
    'windows\hardware-monitor.ps1',
    'windows\power-manager.ps1',
    'windows\memory-manager.ps1',
    'windows\volunteer-monitor.ps1',
    'windows\install-volunteer-stack.ps1',
    'windows\install-ripe-atlas.ps1',
    'windows\post-reboot-finalizer.ps1',
    'windows\widget.ps1'
)

foreach ($relative in $powerShellFiles) {
    $path = Join-Path $repoRoot $relative
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    if ($errors.Count -gt 0) {
        throw "PowerShell syntax failed for $relative`n$($errors | Out-String)"
    }
}

& node --check (Join-Path $repoRoot 'windows\dashboard\server.mjs')
if ($LASTEXITCODE -ne 0) {
    throw 'Node syntax check failed.'
}
& node --check (Join-Path $repoRoot 'windows\fah-control.mjs')
if ($LASTEXITCODE -ne 0) {
    throw 'Folding@home control syntax check failed.'
}

$dashboard = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\dashboard\public\dashboard.html') -Raw
$scriptMatch = [regex]::Match($dashboard, '(?s)<script>(.*)</script>')
if (-not $scriptMatch.Success) {
    throw 'Dashboard inline script was not found.'
}
$temporaryScript = Join-Path ([IO.Path]::GetTempPath()) ('daaklolile-dashboard-' + [guid]::NewGuid().ToString('N') + '.js')
try {
    [IO.File]::WriteAllText(
        $temporaryScript,
        "new Function(" + ($scriptMatch.Groups[1].Value | ConvertTo-Json -Compress) + ");",
        [Text.UTF8Encoding]::new($false)
    )
    & node $temporaryScript
    if ($LASTEXITCODE -ne 0) {
        throw 'Dashboard JavaScript syntax check failed.'
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryScript) {
        Remove-Item -LiteralPath $temporaryScript -Force
    }
}

$serverSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\dashboard\server.mjs') -Raw
foreach ($required in @(
    '/api/power',
    '/api/memory/maintain',
    '/api/console/run',
    'isTailscale',
    'allowedConsoleActions',
    'timingSafeEqual',
    'console-audit.jsonl',
    'boinc-headless.ps1',
    'power-manager.ps1',
    'memory-manager.ps1',
    'volunteer-status.json',
    'electricityCostStatus',
    'systemStatusCache',
    'snowflakeStatusCache',
    'onionooPending',
    'lowTierTryPerKWh',
    'skttAnnualKWh',
    'friendlyTorLogs',
    'No circuits are opened'
)) {
    if ($serverSource -notmatch [regex]::Escape($required)) {
        throw "Missing protected power-control feature: $required"
    }
}

$powerManagerSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\power-manager.ps1') -Raw
foreach ($required in @('Set-VolunteerBudget','boincCpuPercent','PROCTHROTTLEMAX','PERFEPP','foldingGpuPreserved = $false')) {
    if ($powerManagerSource -notmatch [regex]::Escape($required)) {
        throw "Missing eco power-budget feature: $required"
    }
}

$fahControlSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\fah-control.mjs') -Raw
foreach ($required in @('targetCpus','command === "eco"','gpuMatches')) {
    if ($fahControlSource -notmatch [regex]::Escape($required)) {
        throw "Missing Folding eco-budget feature: $required"
    }
}

$widgetSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\widget.ps1') -Raw
if ($widgetSource -match '[^\x00-\x7F]' -or $widgetSource -notmatch 'Convert-UnicodeLiteral') {
    throw 'Widget source must remain ASCII-only so Windows PowerShell 5.1 cannot corrupt its Unicode UI text.'
}
foreach ($required in @(
    'Width="252" Height="132"',
    'UsageMetaText',
    'NetworkText',
    'ResourceText',
    'widgetFailures',
    'Windows.Forms.NotifyIcon',
    'Set-TrayState',
    'Toggle-WidgetVisibility',
    'ContextMenuStrip'
)) {
    if ($widgetSource -notmatch [regex]::Escape($required)) {
        throw "Missing minimal resilient widget feature: $required"
    }
}

$installerSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\install.ps1') -Raw
$dashboardLauncherMatch = [regex]::Match(
    $installerSource,
    '(?s)\$dashboardLauncher\s*=\s*@"\r?\n(.*?)\r?\n"@'
)
if (-not $dashboardLauncherMatch.Success) {
    throw 'Dashboard launcher template was not found.'
}
if ($dashboardLauncherMatch.Groups[1].Value -match 'volunteer-monitor\.ps1') {
    throw 'Dashboard launcher must not create a duplicate volunteer monitor.'
}

$unsafeConsolePatterns = @(
    'input\.command',
    'input\.executable',
    'input\.arguments',
    'shell\s*:\s*true',
    'exec\s*\('
)
foreach ($pattern in $unsafeConsolePatterns) {
    if ($serverSource -match $pattern) {
        throw "Unsafe arbitrary console capability detected: $pattern"
    }
}

$dashboardSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\dashboard\public\dashboard.html') -Raw
foreach ($required in @(
    'Güvenli BOINC konsolu',
    'href="/favicon.svg"',
    'href="/site.webmanifest"',
    'data-console-action="boinc-sync"',
    'data-console-action="boinc-pause"',
    'data-console-action="boinc-headless"',
    'Folding GPU kapalı/',
    'Elektrik faturasına tahmini etkisi',
    'electricity-month-cost',
    'electricity-history',
    'hourly-energy-chart',
    'Bu benzersiz kişi sayısı değildir',
    'data-console-action="boinc-restart"',
    'X-daakLOLILE-Token'
)) {
    if ($dashboardSource -notmatch [regex]::Escape($required)) {
        throw "Missing constrained console UI feature: $required"
    }
}

foreach ($asset in @(
    'windows\dashboard\public\favicon.svg',
    'windows\dashboard\public\site.webmanifest'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $asset))) {
        throw "Missing dashboard identity asset: $asset"
    }
}

$forbiddenPatterns = @(
    '\bREDACTED\b',
    '\bREDACTED\b',
    '\bREDACTED\b',
    '\bREDACTED\b',
    '\bREDACTED\b',
    '\bREDACTED\b',
    'REDACTED'
)

$verificationScript = (Get-Item -LiteralPath $PSCommandPath).FullName
$textFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.FullName -ne $verificationScript -and
        $_.Extension -notin @('.png','.jpg','.jpeg','.gif','.zip','.dll','.exe')
    }

foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($pattern in $forbiddenPatterns) {
        if ($content -match $pattern) {
            throw "Sensitive fixture matched '$pattern' in $($file.FullName.Substring($repoRoot.Length + 1))."
        }
    }
}

Write-Host 'daakLOLILE verification passed.' -ForegroundColor Green
