function Test-SetupCmPreflight {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ConfigPath)
    $config = Read-SetupCmConfig -Path $ConfigPath
    $missing = @()
    foreach ($name in 'sqlServer','mecm') {
        $source = $config.sources[$name]
        if (-not $source.licenseAccepted) { $missing += "sources.$name.licenseAccepted" }
        if (-not (Test-Path (Join-Path $config.cacheRoot $source.cacheFile)) -and [string]::IsNullOrWhiteSpace($source.uri) -and [string]::IsNullOrWhiteSpace($source.vaultPath)) { $missing += "sources.$name.uri-or-vaultPath" }
    }
    [pscustomobject]@{ Ready = $missing.Count -eq 0; Missing = $missing; Topology = $config.topology }
}
