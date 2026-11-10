[CmdletBinding()]
param()
. "$PSScriptRoot\Common.ps1"
$lock = Read-ModLock
$paths = @(
    'NightCoop.cmd',
    'scripts\config.example.json', 'scripts\nightcoop.lock.json',
    'scripts\Common.ps1', 'scripts\Menu.ps1', 'scripts\NightCoop.ps1', 'scripts\Build-Package.ps1',
    'scripts\Setup-NightCoop.ps1', 'scripts\Install-NightCoop.ps1',
    'scripts\Start-NightCoop.ps1', 'scripts\Test-Setup.ps1', 'scripts\Restore-NightCoop.ps1',
    'docs\README.md', 'docs\LICENSE', 'docs\THIRD-PARTY-NOTICES.md',
    'docs\installation.md', 'docs\distribution.md'
)
foreach ($relative in $paths) {
    $path = Get-ChildPath $script:RepoRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package input: $relative" }
}
$output = Get-ChildPath $script:RepoRoot ("scripts\dist\NightCoop-Setup-$($lock.version).zip")
New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$stream = [IO.File]::Open($output, [IO.FileMode]::Create)
$zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($relative in $paths) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Get-ChildPath $script:RepoRoot $relative), $relative.Replace('\', '/'), [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $zip.Dispose(); $stream.Dispose() }
$hash = Get-Sha256 $output
[IO.File]::WriteAllText($output + '.sha256', "$hash  $([IO.Path]::GetFileName($output))`n", [Text.Encoding]::ASCII)
Write-Host "Package: $output"
Write-Host "SHA-256: $hash"
