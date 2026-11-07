Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

function Read-SetupConfig {
    $path = Join-Path $script:RepoRoot 'config.local.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw 'Copy config.example.json to config.local.json and set gamePath/savePath first.'
    }
    Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Read-ModLock {
    Get-Content -LiteralPath (Join-Path $script:RepoRoot 'nightcoop.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-GameRoot {
    param([string]$GamePath)
    if (-not $GamePath) { $GamePath = (Read-SetupConfig).gamePath }
    $root = (Resolve-Path -LiteralPath $GamePath).ProviderPath.TrimEnd('\')
    if (-not (Test-Path -LiteralPath (Join-Path $root 'bin\x64\Cyberpunk2077.exe') -PathType Leaf)) {
        throw "Game executable not found under: $root"
    }
    $root
}

function Assert-GameStopped {
    if (Get-Process -Name Cyberpunk2077 -ErrorAction SilentlyContinue) {
        throw 'Close Cyberpunk 2077 before changing mod files or backing up saves.'
    }
}

function Get-ChildPath {
    param([string]$Root, [string]$Relative)
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    if ([IO.Path]::IsPathRooted($Relative)) { throw "Absolute relative path refused: $Relative" }
    $full = [IO.Path]::GetFullPath((Join-Path $base $Relative))
    if (-not $full.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes target directory: $Relative"
    }
    # Refuse junctions/symlinks anywhere in a write path.
    $current = $full
    while ($current -and $current.Length -ge $base.Length) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Reparse point refused: $current"
            }
        }
        if ($current -eq $base) { break }
        $current = Split-Path -Parent $current
    }
    $full
}

function Get-Sha256 {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $hasher.Dispose() }
}

function Save-Json {
    param($Value, [string]$Path)
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}
