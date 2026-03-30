[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot = "",
    [string]$TargetRoot = (Join-Path $env:APPDATA "Rime")
)

# 將目前工作目錄的 Rime 設定同步到小狼毫實際使用的 AppData\Rime。
# 這支腳本只覆蓋方案相關檔案，不碰 user.yaml、*.userdb 等個人執行期資料。

$ErrorActionPreference = "Stop"

if (-not $SourceRoot) {
    if ($PSScriptRoot) {
        $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }
    else {
        $SourceRoot = (Get-Location).Path
    }
}

if (-not (Test-Path -LiteralPath $TargetRoot)) {
    if ($PSCmdlet.ShouldProcess($TargetRoot, "Create target directory")) {
        New-Item -ItemType Directory -Path $TargetRoot | Out-Null
    }
}

$rootFiles = @()
$rootFiles += Get-ChildItem -Path (Join-Path $SourceRoot "*.yaml") -File -ErrorAction SilentlyContinue
$rootFiles += Get-ChildItem -Path (Join-Path $SourceRoot "*.txt") -File -ErrorAction SilentlyContinue
$rootFiles += Get-ChildItem -Path (Join-Path $SourceRoot "*.json") -File -ErrorAction SilentlyContinue
$rootFiles += Get-ChildItem -Path (Join-Path $SourceRoot "*.lua") -File -ErrorAction SilentlyContinue
$rootFiles += Get-ChildItem -Path (Join-Path $SourceRoot "*.tsv") -File -ErrorAction SilentlyContinue
$rootFiles += Get-ChildItem -Path (Join-Path $SourceRoot "*.db") -File -ErrorAction SilentlyContinue
$excludedNames = @("user.yaml")

foreach ($file in $rootFiles) {
    if ($excludedNames -contains $file.Name) {
        continue
    }
    $destinationFile = Join-Path $TargetRoot $file.Name
    if ($PSCmdlet.ShouldProcess($destinationFile, "Copy file from $($file.FullName)")) {
        Copy-Item -LiteralPath $file.FullName -Destination $destinationFile -Force
    }
}

$luaSource = Join-Path $SourceRoot "lua"
$luaTarget = Join-Path $TargetRoot "lua"
if (Test-Path -LiteralPath $luaSource) {
    if ($PSCmdlet.ShouldProcess($luaTarget, "Robocopy lua directory")) {
        & robocopy $luaSource $luaTarget /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy lua 失敗，exit code = $LASTEXITCODE"
        }
    }
}

$openccSource = Join-Path $SourceRoot "opencc"
$openccTarget = Join-Path $TargetRoot "opencc"
if (Test-Path -LiteralPath $openccSource) {
    if ($PSCmdlet.ShouldProcess($openccTarget, "Robocopy opencc directory")) {
        & robocopy $openccSource $openccTarget /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy opencc 失敗，exit code = $LASTEXITCODE"
        }
    }
}

$buildPath = Join-Path $TargetRoot "build"
if (Test-Path -LiteralPath $buildPath) {
    if ($PSCmdlet.ShouldProcess($buildPath, "Remove deployed build cache")) {
        Remove-Item -LiteralPath $buildPath -Recurse -Force
    }
}

Write-Host "已同步 Rime 設定到 $TargetRoot"
