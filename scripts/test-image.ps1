param(
    [Parameter(Mandatory = $true)][string]$Image,
    [Parameter(Mandatory = $true)][string]$BuildNumber
)

$ErrorActionPreference = 'Stop'
$testName = "expenso-image-test-$BuildNumber"
$testPort = 18082

function Invoke-Docker([string[]]$DockerArgs) {
    & docker @DockerArgs
    if ($LASTEXITCODE -ne 0) { throw "docker $($DockerArgs -join ' ') failed with exit code $LASTEXITCODE" }
}

try {
    Invoke-Docker @('run', '-d', '--name', $testName, '-p', "127.0.0.1:${testPort}:80", $Image)
    $deadline = (Get-Date).AddSeconds(30)
    do {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$testPort/" -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200 -and $response.Content -match '<html|<!doctype') {
                Write-Host "Image smoke test passed: HTTP $($response.StatusCode) on port $testPort."
                return
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    } while ((Get-Date) -lt $deadline)
    throw "Image did not serve the expected HTML on port $testPort within 30 seconds."
} finally {
    & docker rm -f $testName 2>$null | Out-Null
}
