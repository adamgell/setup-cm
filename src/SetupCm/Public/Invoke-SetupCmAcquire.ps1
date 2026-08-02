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
    $artifacts = foreach ($sourceEntry in $config.sources.GetEnumerator()) {
        if ($sourceEntry.Value -isnot [hashtable]) {
            continue
        }
        $source = $sourceEntry.Value.Clone()
        if (-not $source.ContainsKey('name') -or [string]::IsNullOrWhiteSpace($source['name'])) {
            $source['name'] = $sourceEntry.Key
        }
        Get-SetupCmArtifact -Source $source -CacheRoot $config.cacheRoot -EvidenceRoot $EvidenceRoot
    }

    return $artifacts
}
