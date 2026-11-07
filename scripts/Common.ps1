Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

function Read-SetupConfig {
    $path = Join-Path $script:RepoRoot 'config.local.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw 'Run Setup-NightCoop.cmd first to configure this PC.'
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
    ConvertTo-Json -InputObject $Value -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-DefaultSavePath {
    # The Saved Games known-folder value also handles a moved user folder.
    $folder = $null
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $values = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
    if ($values) {
        $property = $values.PSObject.Properties['{4C5C32FF-BB9D-43b0-BF3C-3A238C4D8DF0}']
        if ($property -and $property.Value) { $folder = [Environment]::ExpandEnvironmentVariables([string]$property.Value) }
    }
    if (-not $folder) {
        $profilePath = [Environment]::GetFolderPath('UserProfile')
        if (-not $profilePath) { $profilePath = $env:USERPROFILE }
        if (-not $profilePath) { throw 'Cannot locate the current user profile. Supply -SavePath.' }
        $folder = Join-Path $profilePath 'Saved Games'
    }
    Join-Path $folder 'CD Projekt Red\Cyberpunk 2077'
}

function Resolve-GameSelection {
    param([string]$Path)
    $candidate = $Path.Trim().Trim('"')
    if (-not $candidate -or -not (Test-Path -LiteralPath $candidate)) { return }
    $item = Get-Item -LiteralPath $candidate
    if (-not $item.PSIsContainer) {
        if ($item.Name -ne 'Cyberpunk2077.exe') { return }
        $candidate = $item.DirectoryName
    }
    # Accept the install root, bin/x64, or the executable selected by the user.
    foreach ($root in @($candidate, (Join-Path $candidate '..\..'))) {
        $full = [IO.Path]::GetFullPath($root).TrimEnd('\')
        if (Test-Path -LiteralPath (Join-Path $full 'bin\x64\Cyberpunk2077.exe') -PathType Leaf) { return $full }
    }
}

function Find-GameInstallations {
    $candidates = [Collections.Generic.List[string]]::new()
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        $values = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if (-not $values) { continue }
        foreach ($propertyName in @('SteamPath', 'InstallPath')) {
            $property = $values.PSObject.Properties[$propertyName]
            if (-not $property -or -not $property.Value) { continue }
            $steamRoot = [string]$property.Value
            $candidates.Add((Join-Path $steamRoot 'steamapps\common\Cyberpunk 2077'))
            $librariesPath = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $librariesPath) {
                $text = Get-Content -LiteralPath $librariesPath -Raw -Encoding UTF8
                foreach ($match in [regex]::Matches($text, '"path"\s+"([^"\r\n]+)"')) {
                    $library = $match.Groups[1].Value.Replace('\\', '\')
                    $candidates.Add((Join-Path $library 'steamapps\common\Cyberpunk 2077'))
                }
            }
        }
    }
    foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1423049311', 'HKLM:\SOFTWARE\GOG.com\Games\1423049311')) {
        $values = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($values) {
            $property = $values.PSObject.Properties['path']
            if ($property -and $property.Value) { $candidates.Add([string]$property.Value) }
        }
    }
    if ($env:ProgramData) {
        $epicManifests = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
        if (Test-Path -LiteralPath $epicManifests) {
            foreach ($file in Get-ChildItem -LiteralPath $epicManifests -Filter '*.item' -File) {
                try {
                    $manifest = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                    $property = $manifest.PSObject.Properties['InstallLocation']
                    if ($property -and $property.Value) { $candidates.Add([string]$property.Value) }
                } catch { Write-Verbose "Could not read Epic manifest: $($file.Name)" }
            }
        }
    }
    @($candidates | ForEach-Object { Resolve-GameSelection $_ } | Sort-Object -Unique)
}
