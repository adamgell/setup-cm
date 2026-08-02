[CmdletBinding()]
param([Parameter(Mandatory)][string]$ManifestPath)

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../src/SetupCm/SetupCm.psd1" -Force
Invoke-SetupCmClient -ManifestPath $ManifestPath
