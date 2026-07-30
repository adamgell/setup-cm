function Invoke-SetupCmStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Test,

        [Parameter(Mandatory)]
        [scriptblock]$Apply,

        [Parameter(Mandatory)]
        [scriptblock]$Verify,

        [Parameter(Mandatory)]
        [string]$EvidenceRoot
    )

    $startedAt = (Get-Date).ToUniversalTime().ToString('o')
    try {
        $testState = & $Test
        if ($testState -eq 'Compliant') {
            $result = [pscustomobject]@{
                name = $Name; state = 'Skipped'; startedAt = $startedAt
                finishedAt = (Get-Date).ToUniversalTime().ToString('o'); message = 'Already compliant.'
            }
            Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name "stage-$Name" -Value $result | Out-Null
            return $result
        }

        & $Apply
        $verifyState = & $Verify
        if ($verifyState -ne 'Compliant') {
            throw "$Name verification failed."
        }

        $result = [pscustomobject]@{
            name = $Name; state = 'Succeeded'; startedAt = $startedAt
            finishedAt = (Get-Date).ToUniversalTime().ToString('o'); message = 'Verified compliant.'
        }
        Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name "stage-$Name" -Value $result | Out-Null
        return $result
    }
    catch {
        $result = [pscustomobject]@{
            name = $Name; state = 'Failed'; startedAt = $startedAt
            finishedAt = (Get-Date).ToUniversalTime().ToString('o'); message = $_.Exception.Message
        }
        Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name "stage-$Name" -Value $result | Out-Null
        throw
    }
}
