$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$powerShellFiles = @(
    'windows\install.ps1',
    'windows\uninstall.ps1',
    'windows\hardware-monitor.ps1',
    'windows\power-manager.ps1',
    'windows\memory-manager.ps1',
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
foreach ($required in @('/api/power','/api/memory/maintain','isTailscale','power-manager.ps1','memory-manager.ps1','friendlyTorLogs','No circuits are opened')) {
    if ($serverSource -notmatch [regex]::Escape($required)) {
        throw "Missing protected power-control feature: $required"
    }
}

$forbiddenPatterns = @(
    '\b100\.69\.25\.110\b',
    '\b100\.102\.108\.7\b',
    '\b159\.146\.\d{1,3}\.\d{1,3}\b',
    '\b3C0EEDB23689C2FC2DA287509E619DB95C6FDF38\b',
    '\bbenfirad@proton\.me\b',
    '\bC:\\Users\\jarse\b',
    'proton-recovery-phrase'
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
