[CmdletBinding(SupportsShouldProcess)]
param()
. "$PSScriptRoot\Common.ps1"
Assert-GameStopped
$receiptPath = Join-Path $script:RepoRoot 'local\installation.json'
if (-not (Test-Path -LiteralPath $receiptPath)) { throw 'No installation receipt to restore.' }
$receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
$gameRoot = Resolve-GameRoot $receipt.gamePath
$backup = Get-ChildPath $script:RepoRoot $receipt.backupRelative
# Check everything before restoring anything. Never discard a later mod update.
foreach ($file in $receipt.files) {
    $target = Get-ChildPath $gameRoot $file.path
    if (Test-Path -LiteralPath $target) {
        $hash = Get-Sha256 $target
        if ($hash -ne $file.sha256 -and $hash -ne $file.originalSha256) {
            throw "File changed after installation; preserve/review it first: $target"
        }
    }
    if ($file.existedBefore) {
        $original = Get-ChildPath $backup ('originals\' + $file.path)
        if (-not (Test-Path -LiteralPath $original) -or (Get-Sha256 $original) -ne $file.originalSha256) {
            throw "Original backup missing or changed: $original"
        }
    }
}
foreach ($file in $receipt.disabledFiles) {
    $target = Get-ChildPath $gameRoot $file.path
    if ((Test-Path -LiteralPath $target) -and (Get-Sha256 $target) -ne $file.sha256) {
        throw "A different CET file exists; preserve/review it first: $target"
    }
    $original = Get-ChildPath $backup ('disabled\' + $file.path)
    if (-not (Test-Path -LiteralPath $original) -or (Get-Sha256 $original) -ne $file.sha256) {
        throw "Disabled CET backup missing or changed: $original"
    }
}
if (-not $PSCmdlet.ShouldProcess($gameRoot, 'Restore files recorded by this repo (save data is kept)')) { return }
foreach ($file in $receipt.files) {
    $target = Get-ChildPath $gameRoot $file.path
    if ($file.existedBefore) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Get-ChildPath $backup ('originals\' + $file.path)) -Destination $target -Force
        if ((Get-Sha256 $target) -ne $file.originalSha256) { throw "Restore verification failed: $target" }
    } elseif (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target
    }
}
foreach ($file in $receipt.disabledFiles) {
    $target = Get-ChildPath $gameRoot $file.path
    Copy-Item -LiteralPath (Get-ChildPath $backup ('disabled\' + $file.path)) -Destination $target -Force
    if ((Get-Sha256 $target) -ne $file.sha256) { throw "CET restore verification failed: $target" }
}
# Remove only empty NightCoop directories; no recursive deletion.
$directories = @(foreach ($file in $receipt.files) {
    $relative = Split-Path -Parent $file.path
    while ($relative -match '^(red4ext\\plugins\\NightCoop|r6\\scripts\\NightCoopFlight)(\\|$)') {
        $relative
        $relative = Split-Path -Parent $relative
    }
}) | Sort-Object -Unique | Sort-Object { $_.Length } -Descending
foreach ($relative in $directories) {
    $dir = Get-ChildPath $gameRoot $relative
    if ((Test-Path -LiteralPath $dir -PathType Container) -and @(Get-ChildItem -LiteralPath $dir -Force).Count -eq 0) {
        Remove-Item -LiteralPath $dir
    }
}
$receipt.status = 'restored'
Save-Json $receipt (Join-Path $backup 'restored-installation.json')
Remove-Item -LiteralPath $receiptPath
Write-Host "Restored mod files. Save backups remain at: $backup\saves"
