[CmdletBinding()]
param([string]$GamePath, [string]$SavePath)
. "$PSScriptRoot\Common.ps1"
. "$PSScriptRoot\Menu.ps1"

# Let a terminating error reach PowerShell so the CMD receives a nonzero exit
# code and callers can inspect the failure without losing its original details.
Invoke-NightCoopMenu @PSBoundParameters
