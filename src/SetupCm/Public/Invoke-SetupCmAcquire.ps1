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
    $artifacts = @(
        foreach ($source in (Get-SetupCmNormalizedSources -Sources $config.sources)) {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $config.cacheRoot
            switch ($state.State) {
                'Compliant' {
                    [pscustomobject]@{
                        Name = $source.name
                        State = 'Compliant'
                        Reason = 'Verified'
                        Path = Join-Path $config.cacheRoot $source.cacheFile
                        Sha256 = $state.Sha256
                        SizeBytes = [long]$state.SizeBytes
                        Version = $state.Version
                        Architecture = $state.Architecture
                        VerifiedAt = (Get-Date).ToUniversalTime().ToString('o')
                    }
                }
                'NotCompliant' {
                    Get-SetupCmArtifact -Source $source -CacheRoot $config.cacheRoot -EvidenceRoot $EvidenceRoot
                }
                'Conflict' {
                    throw "Artifact '$($state.Name)' cannot be acquired safely: $($state.Reason)."
                }
                default {
                    throw "Artifact '$($state.Name)' returned unsupported compliance state '$($state.State)'."
                }
            }
        }
    )
    Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'acquisition' -Value $artifacts | Out-Null
    return $artifacts
}
