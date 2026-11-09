# Loaded by NightCoop.ps1 after Common.ps1. Keep status inspection read-only.
function Get-NightCoopStatus {
    $hasReceipt = (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'scripts\local\installation.json')) -or
        (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'local\installation.json'))
    $state = 'NotInstalled'
    $details = $null
    $message = 'This kit has not set up NightCoop on this PC.'
    try {
        if ($hasReceipt) {
            # A partial or broken installation is never treated as a new install.
            $null = Get-InstallationReceiptPath
            $details = & (Join-Path $PSScriptRoot 'Test-Setup.ps1')
            $state = 'Ready'
            $message = 'NightCoop is installed and all checks passed.'
        } elseif (Test-Path -LiteralPath (Get-SetupConfigPath)) {
            $null = Read-SetupConfig
            $state = 'Configured'
            $message = 'PC settings exist, but NightCoop has not been installed by this kit.'
        }
    } catch {
        $state = 'NeedsAttention'
        $message = $_.Exception.Message
    }
    [pscustomobject]@{
        State = $state
        HasReceipt = $hasReceipt
        Details = $details
        Message = $message
    }
}

function Invoke-NightCoopMenu {
    [CmdletBinding()]
    param([string]$GamePath, [string]$SavePath)
    $status = Get-NightCoopStatus
    Write-Host ''
    Write-Host "NightCoop status: $($status.State)"
    Write-Host $status.Message
    if ($status.Details) { $status.Details | Format-List | Out-Host }
    if ($status.HasReceipt -and $status.State -ne 'Ready') {
        Write-Warning 'Launch is blocked. Restore still checks every recorded file and backup before making changes.'
    }

    while ($true) {
        Write-Host ''
        if (-not $status.HasReceipt) {
            Write-Host '[1] Run initial setup'
            Write-Host '[0] Do nothing / Exit (default)'
            $choice = ([string](Read-Host 'Run initial setup? Choose 1 or 0')).Trim()
            switch ($choice) {
                '1' {
                    $setupParameters = @{}
                    if ($GamePath) { $setupParameters.GamePath = $GamePath }
                    if ($SavePath) { $setupParameters.SavePath = $SavePath }
                    & (Join-Path $PSScriptRoot 'Setup-NightCoop.ps1') @setupParameters
                    return
                }
                { $_ -eq '' -or $_ -eq '0' } { Write-Host 'No changes made.'; return }
                default { Write-Warning 'Enter 1 or 0. No action was taken.' }
            }
        } else {
            Write-Host '[1] Launch NightCoop'
            Write-Host '[2] Restore pre-install mod files (current saves are kept)'
            Write-Host '[0] Do nothing / Exit (default)'
            $choice = ([string](Read-Host 'Choose 1, 2, or 0')).Trim()
            switch ($choice) {
                '1' {
                    if ($status.State -ne 'Ready') {
                        Write-Warning 'Launch is blocked until the reported problem is resolved. Choose Restore or Exit.'
                    } else {
                        # Recheck immediately before launch, even after a successful status check.
                        & (Join-Path $PSScriptRoot 'Start-NightCoop.ps1')
                        return
                    }
                }
                '2' {
                    & (Join-Path $PSScriptRoot 'Restore-NightCoop.ps1')
                    return
                }
                { $_ -eq '' -or $_ -eq '0' } { Write-Host 'No changes made.'; return }
                default { Write-Warning 'Enter 1, 2, or 0. No action was taken.' }
            }
        }
    }
}
