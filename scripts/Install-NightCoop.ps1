[CmdletBinding(SupportsShouldProcess)]
param([string]$GamePath, [switch]$DisableLegacyCet)
. "$PSScriptRoot\Common.ps1"
Assert-GameStopped
$gameRoot = Resolve-GameRoot $GamePath
$lock = Read-ModLock
$disabledFiles = @(if ($DisableLegacyCet) {
    foreach ($relative in @('bin\x64\version.dll', 'bin\x64\plugins\cyber_engine_tweaks.asi')) {
        $path = Get-ChildPath $gameRoot $relative
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            [pscustomobject]@{ path = $relative; sha256 = Get-Sha256 $path }
        }
    }
})
$exe = Get-Item -LiteralPath (Join-Path $gameRoot 'bin\x64\Cyberpunk2077.exe')
if ($exe.VersionInfo.ProductVersion -ne $lock.gameVersion) {
    throw "Expected game $($lock.gameVersion), found $($exe.VersionInfo.ProductVersion). Review the lock before installing."
}
$receiptPath = Get-InstallationReceiptPath
if (Test-Path -LiteralPath $receiptPath) {
    throw 'An installation receipt already exists. Restore it before reinstalling or updating.'
}
foreach ($relative in @('red4ext\plugins\NightCoop', 'r6\scripts\NightCoopFlight')) {
    if (Test-Path -LiteralPath (Join-Path $gameRoot $relative)) {
        throw "Existing NightCoop installation found: $relative. Preserve/remove it before using this installer."
    }
}
$archive = Get-ChildPath $script:RepoRoot ('scripts\.cache\' + $lock.fileName)
if (-not (Test-Path -LiteralPath $archive)) {
    if ($WhatIfPreference) { Write-Output "Would download and verify $($lock.url), then back up and install into $gameRoot"; return }
    $uri = [Uri]$lock.url
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'nightcoop.net') { throw 'Unexpected download origin in lock.' }
    $manifestUri = [Uri]$lock.manifestUrl
    if ($manifestUri.Scheme -ne 'https' -or $manifestUri.Host -ne 'nightcoop.net') { throw 'Unexpected manifest origin in lock.' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $manifest = Invoke-RestMethod -Uri $manifestUri.AbsoluteUri -TimeoutSec 30 -DisableKeepAlive
    $demo = $manifest.PSObject.Properties['demo']
    if ($demo -and $demo.Value) { throw 'The official release manifest contains demo data.' }
    $releases = @($manifest.releases | Where-Object { $_.version -eq $lock.version -and -not $_.yanked })
    if ($releases.Count -ne 1) { throw 'The pinned release is missing or withdrawn on the official site.' }
    $officialFiles = @($releases[0].files | Where-Object { $_.kind -eq 'mod' -and $_.name -eq $lock.fileName })
    if ($officialFiles.Count -ne 1) { throw 'The pinned archive is missing from the official manifest.' }
    $official = $officialFiles[0]
    $officialUrl = [Uri]::new($manifestUri, [string]$official.url).AbsoluteUri
    if ($official.sha256 -ne $lock.sha256 -or $official.size -ne $lock.size -or $officialUrl -ne $uri.AbsoluteUri) {
        throw 'Official archive metadata changed. Ask the group maintainer to review the lock.'
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $archive) -Force | Out-Null
    $partial = $archive + '.partial'
    Write-Host "Downloading NightCoop $($lock.version) from the official site ..."
    $previousProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            try {
                Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $partial -UseBasicParsing -TimeoutSec 60 -DisableKeepAlive
                break
            } catch {
                if ($attempt -eq 2) { throw }
                Write-Warning 'Download failed or timed out; retrying once. No game files have been changed.'
            }
        }
    } finally { $ProgressPreference = $previousProgress }
    if ((Get-Sha256 $partial) -ne $lock.sha256 -or (Get-Item -LiteralPath $partial).Length -ne $lock.size) {
        throw 'Downloaded archive SHA-256 or size mismatch. No game files were changed.'
    }
    Move-Item -LiteralPath $partial -Destination $archive -Force
}
if ((Get-Sha256 $archive) -ne $lock.sha256 -or (Get-Item -LiteralPath $archive).Length -ne $lock.size) {
    throw 'Archive SHA-256 or size does not match nightcoop.lock.json.'
}
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $seen = @{}
    $files = @(foreach ($entry in $zip.Entries) {
        if (-not $entry.Name) { continue }
        $relative = $entry.FullName.Replace('/', '\')
        if ($relative -match '(^|\\)\.\.?($|\\)' -or $relative.Contains(':')) { throw "Unsafe archive path: $relative" }
        if ($relative -notmatch '^(bin\\x64\\winmm\.dll|red4ext\\(RED4ext\.dll|LICENSE\.txt|THIRD_PARTY_LICENSES\.txt|plugins\\NightCoop\\.+)|r6\\scripts\\NightCoopFlight\\.+)$') {
            throw "Unexpected archive entry: $relative"
        }
        if ($seen.ContainsKey($relative)) { throw "Duplicate archive path: $relative" }
        $seen[$relative] = $true
        $target = Get-ChildPath $gameRoot $relative
        $stream = $entry.Open()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
        finally { $stream.Dispose(); $hasher.Dispose() }
        $exists = Test-Path -LiteralPath $target -PathType Leaf
        [pscustomobject]@{
            path = $relative
            archiveEntry = $entry.FullName
            sha256 = $hash
            existedBefore = $exists
            originalSha256 = $(if ($exists) { Get-Sha256 $target } else { $null })
        }
    })
    foreach ($required in @('bin\x64\winmm.dll', 'red4ext\RED4ext.dll', 'red4ext\plugins\NightCoop\NightCoop.dll')) {
        if (-not $seen.ContainsKey($required)) { throw "Missing required file: $required" }
    }
    $files | Select-Object path,existedBefore | Format-Table -AutoSize | Out-Host
    if ($disabledFiles.Count) { Write-Host 'Legacy CET files to back up and disable:'; $disabledFiles | Select-Object path | Format-Table -AutoSize | Out-Host }
    if (-not $PSCmdlet.ShouldProcess($gameRoot, "Back up saves and install NightCoop $($lock.version) ($($files.Count) files)")) { return }

    $config = Read-SetupConfig
    if (-not $config.savePath -or -not [IO.Path]::IsPathRooted($config.savePath)) { throw 'Configure an absolute savePath using NightCoop.cmd.' }
    $saveRoot = [IO.Path]::GetFullPath($config.savePath).TrimEnd('\')
    $repoPath = [IO.Path]::GetFullPath($script:RepoRoot).TrimEnd('\')
    if ($saveRoot -eq $repoPath -or $saveRoot.StartsWith($repoPath + '\', [StringComparison]::OrdinalIgnoreCase) -or $repoPath.StartsWith($saveRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The save folder and this kit must not contain one another.'
    }
    $savesExist = Test-Path -LiteralPath $saveRoot -PathType Container
    if ((Test-Path -LiteralPath $saveRoot) -and -not $savesExist) { throw 'savePath must be a folder, not a file.' }
    $backupRelative = 'scripts\backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $backup = Get-ChildPath $script:RepoRoot $backupRelative
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    Write-Host "Backing up any existing saves to $backup\saves ..."
    $saveFiles = @(if ($savesExist) { Get-ChildItem -LiteralPath $saveRoot -Recurse -File -Force })
    $saveManifest = @(foreach ($file in $saveFiles) {
        $relative = $file.FullName.Substring($saveRoot.Length + 1)
        $source = Get-ChildPath $saveRoot $relative
        $dest = Get-ChildPath $backup ('saves\' + $relative)
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $dest
        $hash = Get-Sha256 $source
        if ((Get-Sha256 $dest) -ne $hash) { throw "Save backup verification failed: $relative" }
        [pscustomobject]@{ path = $relative; sha256 = $hash; size = $file.Length }
    })
    Save-Json $saveManifest (Join-Path $backup 'saves-manifest.json')
    foreach ($file in $files) {
        if ($file.existedBefore) {
            $source = Get-ChildPath $gameRoot $file.path
            $dest = Get-ChildPath $backup ('originals\' + $file.path)
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $dest
            if ((Get-Sha256 $dest) -ne $file.originalSha256) { throw "Original backup verification failed: $($file.path)" }
        }
    }
    foreach ($file in $disabledFiles) {
        $source = Get-ChildPath $gameRoot $file.path
        $dest = Get-ChildPath $backup ('disabled\' + $file.path)
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $dest
        if ((Get-Sha256 $dest) -ne $file.sha256) { throw "CET backup verification failed: $($file.path)" }
    }
    $receipt = [ordered]@{
        status = 'installing'
        installedAt = (Get-Date).ToUniversalTime().ToString('o')
        gamePath = $gameRoot
        gameVersion = $exe.VersionInfo.ProductVersion
        gameExeSha256 = Get-Sha256 $exe.FullName
        version = $lock.version
        protocol = $lock.protocol
        archiveSha256 = $lock.sha256
        backupRelative = $backupRelative
        savesBackedUp = $saveManifest.Count
        savesExistedBefore = $savesExist
        files = $files
        disabledFiles = $disabledFiles
    }
    Save-Json $receipt (Join-Path $backup 'installation.json')
    New-Item -ItemType Directory -Path (Split-Path -Parent $receiptPath) -Force | Out-Null
    Save-Json $receipt $receiptPath
    try {
        foreach ($file in $disabledFiles) {
            $path = Get-ChildPath $gameRoot $file.path
            if ((Get-Sha256 $path) -ne $file.sha256) { throw "CET file changed before disabling: $path" }
            Remove-Item -LiteralPath $path
        }
        foreach ($file in $files) {
            $dest = Get-ChildPath $gameRoot $file.path
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            $stream = $zip.GetEntry($file.archiveEntry).Open()
            $output = [IO.File]::Create($dest)
            try { $stream.CopyTo($output) } finally { $output.Dispose(); $stream.Dispose() }
            if ((Get-Sha256 $dest) -ne $file.sha256) { throw "Installed file verification failed: $($file.path)" }
        }
        $receipt.status = 'installed'
        Save-Json $receipt $receiptPath
        Save-Json $receipt (Join-Path $backup 'installation.json')
        Write-Host "Installed NightCoop $($lock.version); protocol $($lock.protocol). Backup: $backup"
    } catch {
        Write-Warning 'Installation incomplete. The receipt and backups were kept; run NightCoop.cmd and choose Restore to undo copied files.'
        throw
    }
} finally { $zip.Dispose() }
