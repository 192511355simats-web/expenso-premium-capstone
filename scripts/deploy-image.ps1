param(
    [Parameter(Mandatory = $true)][string]$Image,
    [Parameter(Mandatory = $true)][string]$ContainerName,
    [Parameter(Mandatory = $true)][int]$Port,
    [Parameter(Mandatory = $true)][string]$BuildNumber
)

$ErrorActionPreference = 'Stop'
$backupName = "$ContainerName-rollback-$BuildNumber"
$oldContainerMoved = $false
$newContainerStarted = $false

function Invoke-Docker([string[]]$DockerArgs) {
    & docker @DockerArgs
    if ($LASTEXITCODE -ne 0) { throw "docker $($DockerArgs -join ' ') failed with exit code $LASTEXITCODE" }
}

function Test-ContainerExists([string]$Name) {
    & docker container inspect $Name *> $null
    return ($LASTEXITCODE -eq 0)
}

try {
    if (Test-ContainerExists $backupName) {
        throw "Rollback container '$backupName' already exists. Inspect it manually before retrying; it will not be removed automatically."
    }

    if (Test-ContainerExists $ContainerName) {
        Write-Host "Stopping existing '$ContainerName' for replacement."
        Invoke-Docker @('stop', $ContainerName)
        Invoke-Docker @('rename', $ContainerName, $backupName)
        $oldContainerMoved = $true
    }

    Invoke-Docker @('run', '-d', '--restart', 'unless-stopped', '--name', $ContainerName, '-p', "${Port}:80", $Image)
    $newContainerStarted = $true

    $deadline = (Get-Date).AddSeconds(30)
    do {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/" -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200 -and $response.Content -match '<html|<!doctype') {
                Write-Host "New deployment is healthy: HTTP $($response.StatusCode)."
                if ($oldContainerMoved) {
                    & docker rm $backupName
                    if ($LASTEXITCODE -ne 0) { Write-Warning "Deployment is healthy, but old container '$backupName' could not be cleaned up." }
                }
                exit 0
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    } while ((Get-Date) -lt $deadline)

    throw "New deployment did not return the expected HTML on port $Port within 30 seconds."
} catch {
    Write-Host "Deployment failed: $_"
    if ($newContainerStarted -or (Test-ContainerExists $ContainerName)) {
        & docker rm -f $ContainerName 2>$null | Out-Null
    }
    if ($oldContainerMoved -and (Test-ContainerExists $backupName)) {
        try {
            Invoke-Docker @('rename', $backupName, $ContainerName)
            Invoke-Docker @('start', $ContainerName)
            Write-Warning "The previous container has been restored as '$ContainerName'."
        } catch {
            Write-Host "Automatic rollback failed. The stopped previous container remains '$backupName': $_"
        }
    }
    exit 1
}
