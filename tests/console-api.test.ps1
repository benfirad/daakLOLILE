$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $repoRoot 'windows\dashboard\server.mjs'
$testPort = 17658
$testProcess = $null

if (Get-NetTCPConnection -LocalPort $testPort -State Listen -ErrorAction SilentlyContinue) {
    throw "Test port $testPort is already in use."
}

$env:RELAYWATCH_PORT = [string]$testPort
try {
    $testProcess = Start-Process `
        -FilePath 'C:\Program Files\nodejs\node.exe' `
        -ArgumentList "`"$serverPath`"" `
        -WorkingDirectory $repoRoot `
        -WindowStyle Hidden `
        -PassThru

    $deadline = (Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 300
        $listener = Get-NetTCPConnection -LocalPort $testPort -State Listen -ErrorAction SilentlyContinue
    } while (-not $listener -and (Get-Date) -lt $deadline)
    if (-not $listener) {
        throw 'Test dashboard did not start.'
    }

    $baseUrl = "http://127.0.0.1:$testPort"
    $status = Invoke-RestMethod `
        -Uri "$baseUrl/api/status" `
        -Headers @{ Host = "127.0.0.1:$testPort" } `
        -TimeoutSec 10
    if (-not $status.permissions.console -or -not $status.control.token) {
        throw 'Console token was not issued to loopback.'
    }
    $tariff = $status.electricity.tariff
    $lowTier = [double]$tariff.lowTierTryPerKWh
    $highTier = [double]$tariff.highTierTryPerKWh
    $skttLimit = [double]$tariff.skttAnnualKWh
    if ($tariff.effectiveFrom -ne '2026-04-04' -or $lowTier -le 0 -or $highTier -le $lowTier -or $skttLimit -ne 4000) {
        throw 'Electricity tariff status is missing or invalid.'
    }

    $body = @{ action = 'boinc-status' } | ConvertTo-Json -Compress
    $result = Invoke-RestMethod `
        -Uri "$baseUrl/api/console/run" `
        -Method Post `
        -Headers @{
            Origin = $baseUrl
            'X-daakLOLILE-Token' = $status.control.token
        } `
        -ContentType 'application/json' `
        -Body $body `
        -TimeoutSec 30
    if (-not $result.ok -or $result.output -notmatch 'Science United') {
        throw 'Allowed BOINC status action did not return the expected account-manager output.'
    }

    $missingTokenRejected = $false
    try {
        Invoke-RestMethod `
            -Uri "$baseUrl/api/console/run" `
            -Method Post `
            -Headers @{ Origin = $baseUrl } `
            -ContentType 'application/json' `
            -Body $body `
            -TimeoutSec 10 | Out-Null
    }
    catch {
        $missingTokenRejected = $_.Exception.Response.StatusCode -eq 403
    }
    if (-not $missingTokenRejected) {
        throw 'Console request without a control token was not rejected.'
    }

    Write-Host 'Constrained console API integration test passed.' -ForegroundColor Green
}
finally {
    Remove-Item Env:RELAYWATCH_PORT -ErrorAction SilentlyContinue
    if ($testProcess -and -not $testProcess.HasExited) {
        $resolved = Get-Process -Id $testProcess.Id -ErrorAction SilentlyContinue
        if ($resolved -and $resolved.ProcessName -eq 'node') {
            Stop-Process -Id $resolved.Id -Force
        }
    }
}
