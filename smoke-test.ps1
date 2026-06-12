#!/usr/bin/env pwsh
#Requires -Version 7.4

# =============================================================================
# smoke-test.ps1: Start a built image, poll the health endpoint, and clean up.
#   Reads PORT and HEALTH_PATH from <image>/metadata/.
# =============================================================================

param (
    [Parameter(Mandatory)] [string] $Name,      # image slug, e.g. "config-server"
    [Parameter(Mandatory)] [string] $Registry,  # e.g. "steeltoe.azurecr.io"
    [Parameter(Mandatory)] [string] $Tag,       # e.g. "4.3.1" or "dev"
    [int] $MaxAttempts = 60,
    [int] $DelaySeconds = 3
)

$ErrorActionPreference = 'Stop'

$imagesDirectory = Split-Path -Parent $PSCommandPath
$port            = (Get-Content (Join-Path $imagesDirectory $Name "metadata" "PORT")).Trim()
$healthPathFile  = Join-Path $imagesDirectory $Name "metadata" "HEALTH_PATH"
if (Test-Path $healthPathFile) {
    $healthPath = (Get-Content $healthPathFile).Trim()
} else {
    $healthPath = "/actuator/health"
}

$image = "$Registry/${Name}:$Tag"
$url   = "http://localhost:${port}${healthPath}"

Write-Host "Starting smoke test for $image"
Write-Host "Health endpoint: $url"

$containerId = (docker run -d -p "${port}:${port}" $image).Trim()
Write-Host "Container started: $containerId"

$ok = $false
try {
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -SkipHttpErrorCheck -ErrorAction Stop
            Write-Host "attempt ${i}: HTTP $($response.StatusCode)"
            if ($response.StatusCode -eq 200) {
                $ok = $true
                break
            }
        }
        catch {
            Write-Host "attempt ${i}: $($_.Message)"
        }
        Start-Sleep $DelaySeconds
    }
}
finally {
    Write-Host "----- container logs -----"
    docker logs $containerId
    docker rm -f $containerId | Out-Null
}

if (-not $ok) {
    Write-Error "Smoke test FAILED: $url did not return HTTP 200 after $MaxAttempts attempts"
    exit 1
}

Write-Host "Smoke test passed"
