[CmdletBinding()]
param(
    [string]$DataRoot = "D:\CODE\LIKEIME\DATA",
    [string]$SourceRoot = ""
)

# 一鍵流程：
# 1. 從 LikeIME 的 custom / custom_user / related / emoji 匯入工作目錄
# 2. 同步工作目錄到小狼毫 AppData\Rime
# 3. 重新佈署小狼毫

$ErrorActionPreference = "Stop"

if (-not $SourceRoot) {
    if ($PSScriptRoot) {
        $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }
    else {
        $SourceRoot = (Get-Location).Path
    }
}

$limeDb = Join-Path $DataRoot "lime.db"
$emojiDb = Join-Path $DataRoot "emoji.db"

if (-not (Test-Path -LiteralPath $limeDb)) {
    throw "找不到 lime.db：$limeDb"
}

Push-Location $SourceRoot
try {
    python .\scripts\import_likeime_db.py --db $limeDb --emoji-db $emojiDb
    & .\scripts\sync_to_weasel_user.ps1 -SourceRoot $SourceRoot
    Start-Process -FilePath 'C:\Program Files (x86)\Rime\weasel-0.17.4\WeaselDeployer.exe' -Wait
}
finally {
    Pop-Location
}

Write-Host "LikeIME import and redeploy completed."
