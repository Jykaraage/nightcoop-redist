[CmdletBinding()]
param(
    [string]$GamePath,
    [string]$SavePath,
    [switch]$ConfigureOnly,
    [switch]$NonInteractive
)
. "$PSScriptRoot\Common.ps1"
$configPath = Join-Path $script:RepoRoot 'config.local.json'
$existing = $null
if (Test-Path -LiteralPath $configPath) { $existing = Read-SetupConfig }
if (-not $GamePath -and $existing) { $GamePath = $existing.gamePath }
if (-not $GamePath) {
    $found = @(Find-GameInstallations)
    if ($found.Count -eq 1) { $GamePath = $found[0] }
    elseif ($found.Count -gt 1 -and -not $NonInteractive) {
        for ($i = 0; $i -lt $found.Count; $i++) { Write-Host "[$($i + 1)] $($found[$i])" }
        $choice = Read-Host 'Select a game number, or press Enter to enter a path'
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $found.Count) { $GamePath = $found[$number - 1] }
    }
}
if (-not $GamePath -and -not $NonInteractive) {
    $GamePath = Read-Host 'Paste the Cyberpunk 2077 game folder path (Steam: Manage -> Browse local files)'
}
if (-not $GamePath) { throw 'Game not found. Run with -GamePath pointing to your own installation.' }
$gameRoot = Resolve-GameSelection $GamePath
if (-not $gameRoot) { throw "Cyberpunk2077.exe was not found in: $GamePath" }
$lock = Read-ModLock
$version = (Get-Item -LiteralPath (Join-Path $gameRoot 'bin\x64\Cyberpunk2077.exe')).VersionInfo.ProductVersion
if ($version -ne $lock.gameVersion) { throw "This group uses game $($lock.gameVersion); found $version. No game files were changed." }
if (-not $SavePath -and $existing) { $SavePath = $existing.savePath }
if (-not $SavePath) { $SavePath = Get-DefaultSavePath }
if (-not [IO.Path]::IsPathRooted($SavePath)) { throw '-SavePath must be an absolute path.' }
$SavePath = [IO.Path]::GetFullPath($SavePath.Trim().Trim('"')).TrimEnd('\')
$receiptPath = Join-Path $script:RepoRoot 'local\installation.json'
if (Test-Path -LiteralPath $receiptPath) {
    $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($receipt.gamePath -ne $gameRoot) { throw 'An existing receipt belongs to another game folder. Restore that installation first.' }
}
Save-Json ([ordered]@{ gamePath = $gameRoot; savePath = $SavePath }) $configPath
Write-Host "Game: $gameRoot"
Write-Host "Saves: $SavePath"
Write-Host "Group build: NightCoop $($lock.version) / protocol $($lock.protocol)"
if ($ConfigureOnly) { Write-Host 'Configuration saved. No game files changed.'; return }
if (Test-Path -LiteralPath $receiptPath) {
    & "$PSScriptRoot\Test-Setup.ps1" | Format-List | Out-Host
    Write-Host 'Already installed and verified. Use Start-NightCoop.cmd to play.'
    return
}
& "$PSScriptRoot\Install-NightCoop.ps1"
& "$PSScriptRoot\Test-Setup.ps1" | Format-List | Out-Host
Write-Host 'Setup complete. Use Start-NightCoop.cmd to play.'
