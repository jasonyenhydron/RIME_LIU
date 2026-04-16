[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Lite", "Full")]
    [string]$Profile,
    [switch]$Deploy,
    [string]$SchemaPath = "",
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

if (-not $SchemaPath) {
    $SchemaPath = Join-Path $SourceRoot "liur.schema.yaml"
}

if (-not (Test-Path -LiteralPath $SchemaPath)) {
    throw "Schema file not found: $SchemaPath"
}

function Set-FeatureLine {
    param(
        [string]$Text,
        [string]$Feature,
        [bool]$Enable
    )

    $escapedFeature = [regex]::Escape($Feature)
    $pattern = "(?m)^(?<indent>\s*)#?\s*-\s*(?<feature>$escapedFeature\b.*)$"
    return [regex]::Replace(
        $Text,
        $pattern,
        {
            param($match)
            $indent = $match.Groups["indent"].Value
            $featureText = $match.Groups["feature"].Value
            if ($Enable) {
                return "$indent- $featureText"
            }
            return "$indent# - $featureText"
        }
    )
}

$schemaText = [System.IO.File]::ReadAllText($SchemaPath, [System.Text.Encoding]::UTF8)

switch ($Profile) {
    "Lite" {
        $enableRelated = $false
        $enablePredict = $false
    }
    "Full" {
        $enableRelated = $true
        $enablePredict = $true
    }
}

$schemaText = Set-FeatureLine -Text $schemaText -Feature "lua_processor@liu_related_processor" -Enable $enableRelated
$schemaText = Set-FeatureLine -Text $schemaText -Feature "lua_filter@liu_related_filter" -Enable $enableRelated
$schemaText = Set-FeatureLine -Text $schemaText -Feature "predictor" -Enable $enablePredict
$schemaText = Set-FeatureLine -Text $schemaText -Feature "predict_translator" -Enable $enablePredict

[System.IO.File]::WriteAllText($SchemaPath, $schemaText, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Switched liur profile to $Profile"
Write-Host "  related: $enableRelated"
Write-Host "  predictor: $enablePredict"

if ($Deploy) {
    $deployScript = Join-Path $PSScriptRoot "deploy_weasel.ps1"
    if (-not (Test-Path -LiteralPath $deployScript)) {
        throw "Deploy script not found: $deployScript"
    }
    & $deployScript -SourceRoot $SourceRoot -TargetRoot $TargetRoot -WeaselDeployer $WeaselDeployer
}
