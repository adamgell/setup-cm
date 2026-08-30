[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$MarkerRoot = 'C:\ProgramData\SetupCm\Phase1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$markerPath = Join-Path $MarkerRoot 'marker.json'

if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
    Remove-Item -LiteralPath $markerPath -Force
}

if (Test-Path -LiteralPath $MarkerRoot -PathType Container) {
    $remainingItems = @(Get-ChildItem -LiteralPath $MarkerRoot -Force)
    if ($remainingItems.Count -eq 0) {
        Remove-Item -LiteralPath $MarkerRoot -Force
    }
}
