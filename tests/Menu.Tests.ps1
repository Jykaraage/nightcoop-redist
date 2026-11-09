# Loaded by Smoke.Tests.ps1; no Pester or external modules are required.
function Get-FixtureStatus {
    param($Fixture)
    . "$($Fixture.Kit)\scripts\Common.ps1"
    . "$($Fixture.Kit)\scripts\Menu.ps1"
    Get-NightCoopStatus
}
function Get-FixtureSnapshot {
    param($Fixture)
    # Include directory creation and timestamps as well as file contents so a
    # status check cannot quietly rewrite configuration or receipt files.
    (@(Get-ChildItem -LiteralPath $Fixture.Root -Recurse -Force | Sort-Object FullName | ForEach-Object {
        $hash = if ($_.PSIsContainer) { '<directory>' } else { Get-Sha256 $_.FullName }
        '{0}|{1}|{2}' -f $_.FullName, $_.LastWriteTimeUtc.Ticks, $hash
    }) -join "`n")
}
# Mocks are called from nested script scopes. Unqualified, uniquely named
# shared objects resolve through those scopes to this test harness; script:
# would incorrectly select NightCoop.ps1 or Start-NightCoop.ps1's scope.
$NightCoopTestRoot = $script:TestRoot
$NightCoopTestMenuAnswers = [Collections.Generic.Queue[string]]::new()
$NightCoopTestLaunches = [Collections.Generic.List[string]]::new()
function Read-Host {
    param([string]$Prompt)
    if ($NightCoopTestMenuAnswers.Count -eq 0) { throw "Unexpected interactive prompt: $Prompt" }
    $NightCoopTestMenuAnswers.Dequeue()
}
function Start-Process {
    [CmdletBinding()]
    param([string]$FilePath, [string]$WorkingDirectory, [string]$WindowStyle)
    # Never launch even the fixture executable, and record all launch attempts.
    Assert-True ($FilePath.StartsWith($NightCoopTestRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Launch escaped fixture'
    Assert-True ($WorkingDirectory -eq (Split-Path -Parent $FilePath)) 'Unexpected launch working directory'
    $NightCoopTestLaunches.Add($FilePath)
}
function Invoke-FixtureMenu {
    param($Fixture, [string[]]$Answers)
    $NightCoopTestMenuAnswers.Clear()
    foreach ($answer in $Answers) { $NightCoopTestMenuAnswers.Enqueue($answer) }
    & "$($Fixture.Kit)\scripts\NightCoop.ps1" -GamePath $Fixture.Game -SavePath $Fixture.Saves | Out-Null
    Assert-True ($NightCoopTestMenuAnswers.Count -eq 0) 'Menu did not consume expected answers'
}
function Assert-ReadOnlyMenu {
    param($Fixture, [string]$State, [bool]$HasReceipt, [string[]]$Answers = @('0'))
    $before = Get-FixtureSnapshot $Fixture
    $status = Get-FixtureStatus $Fixture
    Assert-True ($status.State -eq $State) "Expected status $State, got $($status.State)"
    Assert-True ($status.HasReceipt -eq $HasReceipt) 'Incorrect receipt-presence status'
    Invoke-FixtureMenu $Fixture $Answers
    Assert-True ((Get-FixtureSnapshot $Fixture) -ceq $before) "Status/cancel changed $State fixture"
}

$f = New-Fixture 'menu-new'
Remove-Item -LiteralPath "$($f.Kit)\scripts\config.local.json"
Assert-ReadOnlyMenu $f 'NotInstalled' $false @('invalid', '')
Invoke-FixtureMenu $f @('1')
Assert-True ((Get-FixtureStatus $f).State -eq 'Ready') 'Menu setup failed'
Assert-True (Test-Path -LiteralPath "$($f.Kit)\scripts\local\installation.json") 'Menu setup receipt is not under scripts'
$receipt = Get-Content -LiteralPath "$($f.Kit)\scripts\local\installation.json" -Raw | ConvertFrom-Json
Assert-True ($receipt.backupRelative.Replace('\', '/').StartsWith('scripts/backups/')) 'New backup is not under scripts'
Assert-ReadOnlyMenu $f 'Ready' $true @('invalid', '0')
$status = Get-FixtureStatus $f
Assert-True ($null -ne $status.Details) 'Ready status omitted verification details'
$launchCount = $NightCoopTestLaunches.Count
Invoke-FixtureMenu $f @('1')
Assert-True ($NightCoopTestLaunches.Count -eq ($launchCount + 1)) 'Menu did not launch exactly once'
Assert-True ($NightCoopTestLaunches[$launchCount] -eq "$($f.Game)\bin\x64\Cyberpunk2077.exe") 'Menu launched wrong executable'
Invoke-FixtureMenu $f @('2')
Assert-True (-not (Test-Path -LiteralPath "$($f.Kit)\scripts\local\installation.json")) 'Menu restore left active receipt'
Assert-True (-not (Test-Path -LiteralPath "$($f.Game)\bin\x64\winmm.dll")) 'Menu restore left loader'
Assert-ReadOnlyMenu $f 'Configured' $false @('0')
Invoke-FixtureMenu $f @('1')
Assert-True ((Get-FixtureStatus $f).State -eq 'Ready') 'Configured menu setup failed'
Write-Host 'PASS: new/configured setup, invalid choices, safe cancellation, verified launch and restore'

$modPath = "$($f.Game)\red4ext\plugins\NightCoop\NightCoop.dll"
[IO.File]::WriteAllText($modPath, 'modified after installation')
$launchCount = $NightCoopTestLaunches.Count
Assert-ReadOnlyMenu $f 'NeedsAttention' $true @('1', '0')
Assert-True ($NightCoopTestLaunches.Count -eq $launchCount) 'Menu launched a broken installation'
$before = Get-FixtureSnapshot $f
Assert-Throws { Invoke-FixtureMenu $f @('2') } 'changed after installation'
Assert-True ((Get-FixtureSnapshot $f) -ceq $before) 'Failed menu restore changed fixture'
Remove-Item -LiteralPath "$($f.Kit)\scripts\config.local.json"
Assert-ReadOnlyMenu $f 'NeedsAttention' $true @('1', '')
Assert-True ($NightCoopTestLaunches.Count -eq $launchCount) 'Menu launched without configuration'
Write-Host 'PASS: damaged installation and missing configuration cannot launch or silently set up'

foreach ($receiptText in @('{broken json', '{}')) {
    $f = New-Fixture ('menu-invalid-receipt-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path "$($f.Kit)\scripts\local" -Force | Out-Null
    [IO.File]::WriteAllText("$($f.Kit)\scripts\local\installation.json", $receiptText)
    Assert-ReadOnlyMenu $f 'NeedsAttention' $true @('1', '0')
    Assert-True (-not (Test-Path -LiteralPath "$($f.Game)\bin\x64\winmm.dll")) 'Bad receipt triggered setup'
}
Write-Host 'PASS: malformed and partial receipts stay in repair/restore mode'

$f = New-Fixture 'legacy-paths'
& "$($f.Kit)\scripts\Setup-NightCoop.ps1" -NonInteractive | Out-Null
# Reproduce the old directory layout and its repo-relative backup reference.
Move-Item -LiteralPath "$($f.Kit)\scripts\config.local.json" -Destination "$($f.Kit)\config.local.json"
Move-Item -LiteralPath "$($f.Kit)\scripts\local" -Destination "$($f.Kit)\local"
Move-Item -LiteralPath "$($f.Kit)\scripts\backups" -Destination "$($f.Kit)\backups"
$receiptPath = "$($f.Kit)\local\installation.json"
$receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
$receipt.backupRelative = $receipt.backupRelative -replace '^scripts[\\/]', ''
Save-Json $receipt $receiptPath
Assert-ReadOnlyMenu $f 'Ready' $true @('0')
Invoke-FixtureMenu $f @('2')
Assert-True (-not (Test-Path -LiteralPath $receiptPath)) 'Legacy receipt was not cleared'
Assert-True ((Get-Content -LiteralPath "$($f.Game)\red4ext\LICENSE.txt" -Raw) -eq 'pre-existing loader license') 'Legacy backup was not restored'
Assert-True (-not (Test-Path -LiteralPath "$($f.Kit)\scripts\config.local.json")) 'Legacy status/restore migrated configuration unexpectedly'

$f = New-Fixture 'duplicate-receipts'
& "$($f.Kit)\scripts\Setup-NightCoop.ps1" -NonInteractive | Out-Null
New-Item -ItemType Directory -Path "$($f.Kit)\local" | Out-Null
Copy-Item -LiteralPath "$($f.Kit)\scripts\local\installation.json" -Destination "$($f.Kit)\local\installation.json"
Assert-ReadOnlyMenu $f 'NeedsAttention' $true @('1', '0')
Write-Host 'PASS: legacy config/receipt/backup restore and conflicting receipt detection'

$launcher = Get-Content -LiteralPath "$script:SourceRoot\NightCoop.cmd" -Raw
Assert-True ($launcher -match '(?i)scripts\\NightCoop\.ps1') 'CMD does not invoke the unified PowerShell entry point'
Assert-True ($launcher.Contains('%*')) 'CMD does not forward user arguments'

# Exercise cmd.exe argument parsing and exit-code propagation, not the game.
# Only this disposable kit receives the harmless PowerShell argument probe.
$cmdKit = Join-Path $NightCoopTestRoot 'cmd wrapper with spaces'
New-Item -ItemType Directory -Path "$cmdKit\scripts" -Force | Out-Null
Copy-Item -LiteralPath "$script:SourceRoot\NightCoop.cmd" -Destination "$cmdKit\NightCoop.cmd"
@'
param([string]$GamePath, [string]$SavePath, [int]$ProbeExitCode)
Write-Output "PROBE_GAME=$GamePath"
Write-Output "PROBE_SAVES=$SavePath"
exit $ProbeExitCode
'@ | Set-Content -LiteralPath "$cmdKit\scripts\NightCoop.ps1" -Encoding ASCII
$probeGame = Join-Path $cmdKit 'game folder with spaces'
$probeSaves = Join-Path $cmdKit 'save folder with spaces'
foreach ($probeExitCode in @(0, 23)) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = '/d /s /c ""{0}\NightCoop.cmd" -GamePath "{1}" -SavePath "{2}" -ProbeExitCode {3}"' -f $cmdKit, $probeGame, $probeSaves, $probeExitCode
    $startInfo.WorkingDirectory = $cmdKit
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        Assert-True ($process.Start()) 'Could not start isolated CMD wrapper probe'
        # Drain both output streams asynchronously to prevent pipe deadlocks.
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.WriteLine('')
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            throw 'Isolated CMD wrapper probe exceeded 30 seconds'
        }
        Assert-True ($stdoutTask.Wait(5000) -and $stderrTask.Wait(5000)) 'CMD probe output streams did not close'
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        Assert-True ($process.ExitCode -eq $probeExitCode) "CMD lost exit code $probeExitCode (got $($process.ExitCode)): $stderr"
        Assert-True ($stdout.Contains("PROBE_GAME=$probeGame")) "CMD changed spaced GamePath: $stdout $stderr"
        Assert-True ($stdout.Contains("PROBE_SAVES=$probeSaves")) "CMD changed spaced SavePath: $stdout $stderr"
    } finally { $process.Dispose() }
}
Write-Host 'PASS: real CMD wrapper forwards spaced arguments and preserves exit codes 0 and 23'

# Exercise the actual packaging allowlist while private fixture data exists.
& "$script:SourceRoot\scripts\Build-Package.ps1" | Out-Null
$lock = Get-Content -LiteralPath "$script:SourceRoot\scripts\nightcoop.lock.json" -Raw | ConvertFrom-Json
$packagePath = "$script:SourceRoot\scripts\dist\NightCoop-Setup-$($lock.version).zip"
Assert-True (Test-Path -LiteralPath $packagePath) 'Package output is not under scripts/dist'
$expected = @('NightCoop.cmd') + @(
    Get-ChildItem -LiteralPath "$script:SourceRoot\scripts" -File | Where-Object {
        $_.Extension -eq '.ps1' -or ($_.Extension -eq '.json' -and $_.Name -ne 'config.local.json')
    } | ForEach-Object { 'scripts/' + $_.Name }
) + @(
    Get-ChildItem -LiteralPath "$script:SourceRoot\docs" -Recurse -File | Where-Object { $_.Name -ne '.gitattributes' } | ForEach-Object {
        $_.FullName.Substring($script:SourceRoot.Length + 1).Replace('\', '/')
    }
)
$zip = [IO.Compression.ZipFile]::OpenRead($packagePath)
try {
    $actual = @($zip.Entries | ForEach-Object { $_.FullName })
    Assert-True ((@($actual | Sort-Object) -join "`n") -ceq (@($expected | Sort-Object) -join "`n")) 'Package differs from public code/docs allowlist'
    Assert-True (@($actual | Where-Object { $_ -notmatch '/' }).Count -eq 1) 'Package contains extra root files'
    Assert-True (-not ($actual -match '(^|/)(config\.local\.json|installation\.json|\.cache|backups|local|dist)(/|$)')) 'Package leaked private/generated files'
} finally { $zip.Dispose() }
$rootFiles = @(Get-ChildItem -LiteralPath $script:SourceRoot -File -Force)
Assert-True ($rootFiles.Count -eq 1 -and $rootFiles[0].Name -eq 'NightCoop.cmd') 'Source root must contain only NightCoop.cmd'
Write-Host 'PASS: source/package root layout and public package allowlist'
