[CmdletBinding()]
param(
    [string]$ConfigPath = $env:SETUPCM_CONFIG,
    [string]$SourceCommit = $env:SETUPCM_SOURCE_COMMIT
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    throw 'SETUPCM_CONFIG must contain the path to a lab YAML configuration.'
}

Import-Module "$PSScriptRoot/../src/SetupCm/SetupCm.psd1" -Force
Invoke-SetupCmMarkerAcceptance -ConfigPath $ConfigPath -SourceCommit $SourceCommit
