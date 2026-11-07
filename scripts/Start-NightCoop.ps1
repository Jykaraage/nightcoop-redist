[CmdletBinding(SupportsShouldProcess)]
param()
. "$PSScriptRoot\Common.ps1"
Assert-GameStopped
$setup = & "$PSScriptRoot\Test-Setup.ps1"
$setup | Format-List | Out-Host
Write-Host 'In the main menu: Co-op -> Host a session / Join by code.'
$gameBin = Join-Path $setup.GamePath 'bin\x64'
if ($PSCmdlet.ShouldProcess($setup.GamePath, 'Launch Cyberpunk 2077 with installed NightCoop')) {
    Start-Process -FilePath (Join-Path $gameBin 'Cyberpunk2077.exe') -WorkingDirectory $gameBin -WindowStyle Normal
}
