[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [string]$OutputRoot = "",
    [string]$PackageName = "RIME_LIU"
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

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $SourceRoot "dist"
}

if (-not (Test-Path -LiteralPath $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$gitCommit = ""
try {
    $gitCommit = (git -C $SourceRoot rev-parse --short HEAD).Trim()
}
catch {
    $gitCommit = "nogit"
}

$packageBaseName = "$PackageName-$timestamp-$gitCommit"
$stagingRoot = Join-Path $OutputRoot $packageBaseName
$zipPath = Join-Path $OutputRoot ($packageBaseName + ".zip")

if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingRoot | Out-Null

$includePatterns = @("*.yaml", "*.txt", "*.json", "*.lua", "*.tsv", "*.db", "*.md")
$excludeNames = @("user.yaml")

foreach ($pattern in $includePatterns) {
    Get-ChildItem -Path (Join-Path $SourceRoot $pattern) -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($excludeNames -contains $_.Name) {
            return
        }
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stagingRoot $_.Name) -Force
    }
}

$copyDirs = @("lua", "opencc", "docs", "scripts")
foreach ($dirName in $copyDirs) {
    $srcDir = Join-Path $SourceRoot $dirName
    if (Test-Path -LiteralPath $srcDir) {
        Copy-Item -LiteralPath $srcDir -Destination (Join-Path $stagingRoot $dirName) -Recurse -Force
    }
}

$manifestPath = Join-Path $stagingRoot "PACKAGE_INFO.txt"
@(
    "Package: $PackageName"
    "BuiltAt: $timestamp"
    "Commit: $gitCommit"
    "SourceRoot: $SourceRoot"
) | Set-Content -Path $manifestPath -Encoding UTF8

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Package created: $zipPath"
