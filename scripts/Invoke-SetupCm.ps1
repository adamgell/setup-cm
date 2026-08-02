[CmdletBinding()]
param(
    [string]$ConfigPath = $env:SETUPCM_CONFIG,

    [ValidateSet('Guided', 'Unattended')]
    [string]$Mode = 'Unattended',

    [ValidateSet('Acquire', 'Sql', 'Mecm', 'Health')]
    [string[]]$Stage
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    throw 'SETUPCM_CONFIG must contain the path to a lab YAML configuration.'
}

Import-Module "$PSScriptRoot/../src/SetupCm/SetupCm.psd1" -Force
Invoke-SetupCm -ConfigPath $ConfigPath -Mode $Mode -Stage $Stage
