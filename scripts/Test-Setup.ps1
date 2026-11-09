[CmdletBinding()]
param([string]$GamePath)
. "$PSScriptRoot\Common.ps1"
$gameRoot = Resolve-GameRoot $GamePath
$lock = Read-ModLock
$version = (Get-Item -LiteralPath (Join-Path $gameRoot 'bin\x64\Cyberpunk2077.exe')).VersionInfo.ProductVersion
if ($version -ne $lock.gameVersion) { throw "Game changed: expected $($lock.gameVersion), found $version." }
$receiptPath = Get-InstallationReceiptPath
if (-not (Test-Path -LiteralPath $receiptPath)) { throw 'No installation receipt. Run NightCoop.cmd to set up this PC.' }
$receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($receipt.status -ne 'installed') { throw "Installation status: $($receipt.status)" }
if ($gameRoot -ne $receipt.gamePath) { throw 'The selected game folder differs from the installation receipt.' }
if ($receipt.version -ne $lock.version -or $receipt.archiveSha256 -ne $lock.sha256) { throw 'Lock and installed build differ.' }
$exeHash = Get-Sha256 (Join-Path $gameRoot 'bin\x64\Cyberpunk2077.exe')
if ($exeHash -ne $receipt.gameExeSha256) { throw 'The game executable changed since installation. Check compatibility before launching.' }
foreach ($file in $receipt.files) {
    $path = Get-ChildPath $gameRoot $file.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ne $file.sha256) {
        throw "Installed file is missing or changed: $($file.path)"
    }
}
foreach ($file in $receipt.disabledFiles) {
    if (Test-Path -LiteralPath (Get-ChildPath $gameRoot $file.path)) {
        throw "A disabled legacy CET file reappeared: $($file.path). Review it before launching."
    }
}
[pscustomobject]@{
    Game = $version
    NightCoop = $receipt.version
    Protocol = $receipt.protocol
    VerifiedFiles = @($receipt.files).Count
    SavesBackedUp = $receipt.savesBackedUp
    Backup = Join-Path $script:RepoRoot $receipt.backupRelative
    GamePath = $gameRoot
}
