function Invoke-SetupCmAcquire {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [string]$EvidenceRoot
    )

    $config = Read-SetupCmConfig -Path $ConfigPath
    if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        $EvidenceRoot = New-SetupCmRunEvidence -Root $config.evidenceRoot
    }
    $artifacts = foreach ($source in $config.sources.Values) {
        Get-SetupCmArtifact -Source $source -CacheRoot $config.cacheRoot -EvidenceRoot $EvidenceRoot
    }

    return $artifacts
}
