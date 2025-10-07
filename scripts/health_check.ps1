# PowerShell health check script
# Sử dụng: .\scripts\health_check.ps1 [host] [port]

param(
    [string]$Host = "localhost",
    [int]$Port = 8000
)

$Url = "http://${Host}:${Port}"

Write-Host "Checking health of $Url..." -ForegroundColor Cyan

# Health check
try {
    $healthResponse = Invoke-WebRequest -Uri "$Url/health" -UseBasicParsing
    if ($healthResponse.StatusCode -eq 200) {
        Write-Host "✓ Health check: OK" -ForegroundColor Green
    } else {
        Write-Host "✗ Health check: FAILED (HTTP $($healthResponse.StatusCode))" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Health check: FAILED ($_)" -ForegroundColor Red
    exit 1
}

# Status check
try {
    $statusResponse = Invoke-RestMethod -Uri "$Url/api/status"
    Write-Host "✓ Status endpoint: OK" -ForegroundColor Green
    $statusResponse | ConvertTo-Json -Depth 10 | Write-Host
} catch {
    Write-Host "✗ Status endpoint: FAILED ($_)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All checks passed!" -ForegroundColor Green
