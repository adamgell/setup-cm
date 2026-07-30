[CmdletBinding()]
param(
    [string]$ConfigPath = $env:SETUPCM_CONFIG
)

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    throw 'SETUPCM_CONFIG must contain the path to a lab YAML configuration.'
}

Import-Module "$PSScriptRoot/../src/SetupCm/SetupCm.psd1" -Force
Invoke-SetupCm -ConfigPath $ConfigPath -Mode Unattended
