param([Parameter(Mandatory = $true)][int]$Port)

$ErrorActionPreference = 'Stop'
$response = Invoke-WebRequest -Uri "http://localhost:$Port/" -UseBasicParsing -TimeoutSec 10
if ($response.StatusCode -ne 200) { throw "Unexpected HTTP status: $($response.StatusCode)" }
if ($response.Content -notmatch '<html|<!doctype') { throw 'Response does not look like the Expenso HTML page.' }
Write-Host "Deployment verified: HTTP $($response.StatusCode) at http://localhost:$Port/."
