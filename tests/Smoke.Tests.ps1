[CmdletBinding()]
param([string]$OfficialArchivePath, [switch]$Online)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:SourceRoot = Split-Path -Parent $PSScriptRoot
. "$script:SourceRoot\scripts\Common.ps1"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$script:TestRoot = Get-ChildPath $script:SourceRoot ('scripts\.cache\smoke-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:TestRoot | Out-Null
$script:FakeExe = Join-Path $script:TestRoot 'fixture.exe'
Add-Type -TypeDefinition @'
using System.Reflection;
[assembly: AssemblyInformationalVersion("2.5")]
public class FixtureGame { public static void Main() {} }
'@ -OutputAssembly $script:FakeExe -OutputType ConsoleApplication

# Only the isolated fixture is used below. Do not let an unrelated real game
# process block testing, and never stop or launch that process.
function Get-Process {
    [CmdletBinding()]
    param([string]$Name)
    if ($Name -eq 'Cyberpunk2077') { return }
    Microsoft.PowerShell.Management\Get-Process @PSBoundParameters
}
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}
function Assert-Throws {
    param([scriptblock]$Action, [string]$Expected)
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_ }
    Assert-True ($null -ne $caught) "Expected rejection: $Expected"
    Assert-True ($caught.Exception.Message -like "*$Expected*") "Unexpected rejection: $($caught.Exception.Message)"
}
function New-Fixture {
    param([string]$Name, [switch]$NoSaves, [switch]$UnsafeZip, [string]$ArchivePath)
    $root = Join-Path $script:TestRoot $Name
    $kit = Join-Path $root 'kit'
    $game = Join-Path $root 'game'
    $saves = Join-Path $root 'saves'
    New-Item -ItemType Directory -Path "$kit\scripts\.cache", "$game\bin\x64", "$game\red4ext" -Force | Out-Null
    # The test root is inside scripts/.cache: recursive scripts copies would copy
    # their own destination indefinitely and include private state.
    Get-ChildItem -LiteralPath "$script:SourceRoot\scripts" -File | Where-Object {
        $_.Extension -eq '.ps1' -or ($_.Extension -eq '.json' -and $_.Name -ne 'config.local.json')
    } | Copy-Item -Destination "$kit\scripts"
    Copy-Item -LiteralPath $script:FakeExe -Destination "$game\bin\x64\Cyberpunk2077.exe"
    [IO.File]::WriteAllText("$game\red4ext\LICENSE.txt", 'pre-existing loader license')
    if (-not $NoSaves) {
        New-Item -ItemType Directory -Path "$saves\ManualSave-0" -Force | Out-Null
        [IO.File]::WriteAllText("$saves\ManualSave-0\sav.dat", 'private fixture save')
    }
    $lock = Get-Content -LiteralPath "$script:SourceRoot\scripts\nightcoop.lock.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $archive = Join-Path "$kit\scripts\.cache" $lock.fileName
    if ($ArchivePath) { Copy-Item -LiteralPath $ArchivePath -Destination $archive }
    else {
        $zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Create)
        try {
            $entries = @('bin/x64/winmm.dll', 'red4ext/RED4ext.dll', 'red4ext/LICENSE.txt', 'red4ext/plugins/NightCoop/NightCoop.dll', 'r6/scripts/NightCoopFlight/test.reds')
            if ($UnsafeZip) { $entries += 'red4ext/plugins/NightCoop/../../../../escaped.txt' }
            foreach ($path in $entries) {
                $writer = [IO.StreamWriter]::new($zip.CreateEntry($path).Open())
                try { $writer.Write("fixture $path") } finally { $writer.Dispose() }
            }
        } finally { $zip.Dispose() }
        $lock.sha256 = Get-Sha256 $archive
        $lock.size = (Get-Item -LiteralPath $archive).Length
    }
    Save-Json $lock "$kit\scripts\nightcoop.lock.json"
    & "$kit\scripts\Setup-NightCoop.ps1" -GamePath "$game\bin\x64\Cyberpunk2077.exe" -SavePath $saves -ConfigureOnly -NonInteractive | Out-Null
    [pscustomobject]@{ Root = $root; Kit = $kit; Game = $game; Saves = $saves; Archive = $archive; Lock = $lock }
}

foreach ($file in @(Get-ChildItem -LiteralPath "$script:SourceRoot\scripts" -Filter '*.ps1') + @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1')) {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-True (-not $errors) "PowerShell parse failed: $($file.Name)"
}
$f = New-Fixture 'install-and-restore'
$original = Get-Sha256 "$($f.Game)\red4ext\LICENSE.txt"
& "$($f.Kit)\scripts\Install-NightCoop.ps1" -WhatIf | Out-Null
Assert-True (-not (Test-Path -LiteralPath "$($f.Game)\bin\x64\winmm.dll")) 'WhatIf changed game files'
& "$($f.Kit)\scripts\Setup-NightCoop.ps1" -NonInteractive | Out-Null
$check = & "$($f.Kit)\scripts\Test-Setup.ps1"
Assert-True ($check.SavesBackedUp -eq 1) 'Existing save was not backed up'
$receiptPath = "$($f.Kit)\scripts\local\installation.json"
$receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True (Test-Path -LiteralPath (Join-Path $f.Kit "$($receipt.backupRelative)\saves\ManualSave-0\sav.dat")) 'Save backup is missing'
& "$($f.Kit)\scripts\Setup-NightCoop.ps1" -NonInteractive | Out-Null
& "$($f.Kit)\scripts\Start-NightCoop.ps1" -WhatIf | Out-Null
$gameExe = "$($f.Game)\bin\x64\Cyberpunk2077.exe"
[IO.File]::AppendAllText($gameExe, 'game update')
Assert-Throws { & "$($f.Kit)\scripts\Test-Setup.ps1" } 'game executable changed'
Copy-Item -LiteralPath $script:FakeExe -Destination $gameExe -Force
$modPath = "$($f.Game)\red4ext\plugins\NightCoop\NightCoop.dll"
[IO.File]::WriteAllText($modPath, 'a later mod update')
Assert-Throws { & "$($f.Kit)\scripts\Test-Setup.ps1" } 'missing or changed'
Assert-Throws { & "$($f.Kit)\scripts\Restore-NightCoop.ps1" } 'changed after installation'
Assert-True (Test-Path -LiteralPath "$($f.Game)\bin\x64\winmm.dll") 'Restore mutated files before checking all hashes'
$zip = [IO.Compression.ZipFile]::OpenRead($f.Archive)
try { [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry('red4ext/plugins/NightCoop/NightCoop.dll'), $modPath, $true) }
finally { $zip.Dispose() }
& "$($f.Kit)\scripts\Restore-NightCoop.ps1" -WhatIf | Out-Null
Assert-True (Test-Path -LiteralPath $modPath) 'Restore WhatIf changed game files'
& "$($f.Kit)\scripts\Restore-NightCoop.ps1" | Out-Null
Assert-True (-not (Test-Path -LiteralPath "$($f.Game)\bin\x64\winmm.dll")) 'New loader was not removed'
Assert-True ((Get-Sha256 "$($f.Game)\red4ext\LICENSE.txt") -eq $original) 'Original file was not restored'
Assert-True ((Get-Content -LiteralPath "$($f.Saves)\ManualSave-0\sav.dat" -Raw) -eq 'private fixture save') 'Save was changed'
Assert-True (-not (Test-Path -LiteralPath $receiptPath)) 'Active receipt was not cleared'
Write-Host 'PASS: setup, repeat setup, launch preview, backup, tamper refusal, and exact restore'

$f = New-Fixture 'no-saves' -NoSaves
& "$($f.Kit)\scripts\Setup-NightCoop.ps1" -NonInteractive | Out-Null
$check = & "$($f.Kit)\scripts\Test-Setup.ps1"
Assert-True ($check.SavesBackedUp -eq 0) 'New player should have zero backed-up saves'
Assert-True (-not (Test-Path -LiteralPath $f.Saves)) 'Installer created a source save folder'
$receipt = Get-Content -LiteralPath "$($f.Kit)\scripts\local\installation.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$saveManifest = Get-Content -LiteralPath (Join-Path $f.Kit "$($receipt.backupRelative)\saves-manifest.json") -Raw -Encoding UTF8
Assert-True ($saveManifest -match '^\s*\[\s*\]\s*$') 'Empty save manifest must be a JSON array'
& "$($f.Kit)\scripts\Restore-NightCoop.ps1" | Out-Null
Write-Host 'PASS: first-time player with no saves'

$f = New-Fixture 'unsafe-zip' -UnsafeZip
Assert-Throws { & "$($f.Kit)\scripts\Install-NightCoop.ps1" } 'Unsafe archive path'
Assert-True (-not (Test-Path -LiteralPath "$($f.Game)\bin\x64\winmm.dll")) 'Unsafe ZIP changed game files'
$f = New-Fixture 'corrupt-zip'
[IO.File]::AppendAllText($f.Archive, 'corruption')
Assert-Throws { & "$($f.Kit)\scripts\Install-NightCoop.ps1" } 'Archive SHA-256 or size'
Write-Host 'PASS: unsafe ZIP and checksum rejection before game writes'

$f = New-Fixture 'wrong-game-version'
$f.Lock.gameVersion = '2.31'
Save-Json $f.Lock "$($f.Kit)\scripts\nightcoop.lock.json"
Assert-Throws { & "$($f.Kit)\scripts\Setup-NightCoop.ps1" -NonInteractive } 'This group uses game 2.31'
Assert-True (-not (Test-Path -LiteralPath "$($f.Game)\bin\x64\winmm.dll")) 'Version mismatch changed game files'
Write-Host 'PASS: game version mismatch and executable update detection'

if ($OfficialArchivePath) {
    $f = New-Fixture 'official-archive' -ArchivePath $OfficialArchivePath
    if ($Online) {
        Move-Item -LiteralPath $f.Archive -Destination ($f.Archive + '.seed')
    }
    & "$($f.Kit)\scripts\Setup-NightCoop.ps1" -NonInteractive | Out-Null
    $check = & "$($f.Kit)\scripts\Test-Setup.ps1"
    Assert-True ($check.VerifiedFiles -eq 10) 'Official archive layout changed'
    & "$($f.Kit)\scripts\Restore-NightCoop.ps1" | Out-Null
    Write-Host "PASS: official pinned archive install, verification, and restore (fresh download: $Online)"
}
. "$PSScriptRoot\Menu.Tests.ps1"
Write-Host "All smoke tests passed. Isolated artifacts: $script:TestRoot"
