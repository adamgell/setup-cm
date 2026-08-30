[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$MarkerRoot = 'C:\ProgramData\SetupCm\Phase1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$markerPath = Join-Path $MarkerRoot 'marker.json'
$markerContent = '{"application":"Setup-CM Phase 1 Marker","version":"1.0.0","scope":"lab-only"}'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

New-Item -ItemType Directory -Path $MarkerRoot -Force | Out-Null
[System.IO.File]::WriteAllText($markerPath, $markerContent, $utf8NoBom)
