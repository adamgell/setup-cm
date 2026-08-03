function Invoke-SetupCmClient {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ManifestPath)

    $manifest = Read-SetupCmClientManifest -Path $ManifestPath
    $evidenceRoot = New-SetupCmRunEvidence -Root $manifest.evidenceRoot
    try {
        $stageResult = Invoke-SetupCmStage -Name Client -EvidenceRoot $evidenceRoot -Test {
            Test-SetupCmClientInstallation -Manifest $manifest
        } -Apply {
            Install-SetupCmClient -Manifest $manifest | Out-Null
        } -Verify {
            Wait-SetupCmClientInstallation -Manifest $manifest
        }
    }
    finally {
        Write-SetupCmEvidenceJson -EvidenceRoot $evidenceRoot -Name 'client-install' -Value (Get-SetupCmClientEvidence -Manifest $manifest) | Out-Null
    }
    return $stageResult
}
