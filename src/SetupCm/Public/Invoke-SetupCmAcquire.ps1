function Invoke-SetupCmAcquire {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    $config = Read-SetupCmConfig -Path $ConfigPath
    $evidenceRoot = New-SetupCmRunEvidence -Root $config.evidenceRoot
    $artifacts = foreach ($source in $config.sources.Values) {
        Get-SetupCmArtifact -Source $source -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
    }

    return $artifacts
}
