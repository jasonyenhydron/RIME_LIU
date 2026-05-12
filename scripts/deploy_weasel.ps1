[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [string]$TargetRoot = (Join-Path $env:APPDATA "Rime"),
    [string]$WeaselDeployer = "",
    [string]$WeaselServer = ""
)

$ErrorActionPreference = "Stop"

if (-not $SourceRoot) {
    if ($PSScriptRoot) {
        $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }
    else {
        $SourceRoot = (Get-Location).Path
    }
}

function Resolve-RimeExecutablePath {
    param(
        [string]$PreferredPath,
        [string]$FileName
    )

    if ($PreferredPath -and (Test-Path -LiteralPath $PreferredPath)) {
        return (Resolve-Path -LiteralPath $PreferredPath).Path
    }

    $fixedBase = "C:\Program Files (x86)\Rime\weasel-0.17.4"
    $fixedPath = Join-Path $fixedBase $FileName
    if (Test-Path -LiteralPath $fixedPath) {
        return $fixedPath
    }

    $candidates = Get-ChildItem -Path "C:\Program Files (x86)\Rime" -Filter $FileName -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending
    if ($candidates -and $candidates.Count -gt 0) {
        return $candidates[0].FullName
    }

    throw "$FileName not found."
}

function Restart-WeaselServer {
    param([string]$ServerPath)

    $running = Get-Process WeaselServer -ErrorAction SilentlyContinue
    if ($running) {
        Write-Host "Stopping WeaselServer ..."
        $running | Stop-Process -Force
        Start-Sleep -Milliseconds 800
    }

    Write-Host "Starting WeaselServer: $ServerPath"
    Start-Process -FilePath $ServerPath -WindowStyle Hidden
    Start-Sleep -Milliseconds 800
}

$syncScript = Join-Path $PSScriptRoot "sync_to_weasel_user.ps1"
if (-not (Test-Path -LiteralPath $syncScript)) {
    throw "Sync script not found: $syncScript"
}

$resolvedWeaselServer = Resolve-RimeExecutablePath -PreferredPath $WeaselServer -FileName "WeaselServer.exe"
$resolvedWeaselDeployer = Resolve-RimeExecutablePath -PreferredPath $WeaselDeployer -FileName "WeaselDeployer.exe"

if (Get-Process WeaselServer -ErrorAction SilentlyContinue) {
    Write-Host "Stopping WeaselServer before sync ..."
    Get-Process WeaselServer | Stop-Process -Force
    Start-Sleep -Milliseconds 800
}

Write-Host "Syncing files to $TargetRoot ..."
& $syncScript -SourceRoot $SourceRoot -TargetRoot $TargetRoot

Write-Host "Running Weasel deployer: $resolvedWeaselDeployer"
$process = Start-Process -FilePath $resolvedWeaselDeployer -Wait -PassThru

if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 1) {
    throw "WeaselDeployer failed with exit code $($process.ExitCode)"
}

Restart-WeaselServer -ServerPath $resolvedWeaselServer

Write-Host "Done: synced files, redeployed Weasel, and restarted WeaselServer."
