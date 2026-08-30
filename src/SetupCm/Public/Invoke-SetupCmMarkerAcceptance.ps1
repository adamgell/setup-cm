function Invoke-SetupCmMarkerAcceptance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [string]$EvidenceRoot,
        [string]$SourceCommit
    )

    $config = Read-SetupCmConfig -Path $ConfigPath
    $SourceCommit = Resolve-SetupCmRequiredSourceCommit -SourceCommit $SourceCommit
    if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        $EvidenceRoot = New-SetupCmRunEvidence -Root $config.evidenceRoot -SourceCommit $SourceCommit
    }
    $context = [pscustomobject]@{ State = $null }
    Invoke-SetupCmStage -Name Marker -EvidenceRoot $EvidenceRoot -Test {
        $probe = Test-SetupCmMarkerDesiredState -Config $config -EvidenceRoot $EvidenceRoot -PassThru
        $context.State = $probe
        [string]$probe.State
    } -Apply {
        Repair-SetupCmMarkerDesiredState -Config $config -State $context.State -EvidenceRoot $EvidenceRoot
    } -Verify {
        Test-SetupCmMarkerDesiredState -Config $config -EvidenceRoot $EvidenceRoot
    }
}
