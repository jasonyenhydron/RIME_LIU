[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [string]$TargetRoot = (Join-Path $env:APPDATA "Rime"),
    [string]$WeaselDeployer = ""
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

function Resolve-WeaselDeployerPath {
    param([string]$PreferredPath)

    if ($PreferredPath -and (Test-Path -LiteralPath $PreferredPath)) {
        return (Resolve-Path -LiteralPath $PreferredPath).Path
    }

    $fixedPath = "C:\Program Files (x86)\Rime\weasel-0.17.4\WeaselDeployer.exe"
    if (Test-Path -LiteralPath $fixedPath) {
        return $fixedPath
    }

    $candidates = Get-ChildItem -Path "C:\Program Files (x86)\Rime" -Filter "WeaselDeployer.exe" -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending
    if ($candidates -and $candidates.Count -gt 0) {
        return $candidates[0].FullName
    }

    throw "WeaselDeployer.exe not found."
}

$syncScript = Join-Path $PSScriptRoot "sync_to_weasel_user.ps1"
if (-not (Test-Path -LiteralPath $syncScript)) {
    throw "Sync script not found: $syncScript"
}

Write-Host "Syncing files to $TargetRoot ..."
& $syncScript -SourceRoot $SourceRoot -TargetRoot $TargetRoot

$resolvedWeaselDeployer = Resolve-WeaselDeployerPath -PreferredPath $WeaselDeployer
Write-Host "Running Weasel deployer: $resolvedWeaselDeployer"
$process = Start-Process -FilePath $resolvedWeaselDeployer -Wait -PassThru

if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 1) {
    throw "WeaselDeployer failed with exit code $($process.ExitCode)"
}

Write-Host "Done: synced files and redeployed Weasel."
