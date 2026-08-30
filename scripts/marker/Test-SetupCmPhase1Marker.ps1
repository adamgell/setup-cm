[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$MarkerRoot = 'C:\ProgramData\SetupCm\Phase1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$markerPath = Join-Path $MarkerRoot 'marker.json'
$expectedHash = '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'

if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
    $actualHash = (Get-FileHash -LiteralPath $markerPath -Algorithm SHA256).Hash
    if ($actualHash -ceq $expectedHash) {
        'Installed'
    }
}
