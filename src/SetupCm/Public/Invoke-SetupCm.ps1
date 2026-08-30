function Invoke-SetupCm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [ValidateSet('Guided', 'Unattended')]
        [string]$Mode = 'Guided',

        [ValidateSet('Acquire', 'Sql', 'Mecm', 'Marker', 'Health')]
        [string[]]$Stage,

        [string]$SourceCommit
    )

    $config = Read-SetupCmConfig -Path $ConfigPath
    $selected = if ($Stage) {
        $Stage
    }
    elseif ($config.ContainsKey('markerAcceptance') -and $config.markerAcceptance.enabled) {
        @('Acquire', 'Sql', 'Mecm', 'Marker', 'Health')
    }
    else {
        @('Acquire', 'Sql', 'Mecm', 'Health')
    }
    if ($selected -contains 'Marker') {
        $SourceCommit = Resolve-SetupCmRequiredSourceCommit -SourceCommit $SourceCommit
    }
    $evidenceRoot = New-SetupCmRunEvidence -Root $config.evidenceRoot -SourceCommit $SourceCommit
    foreach ($name in $selected) {
        switch ($name) {
            'Acquire' {
                Invoke-SetupCmStage -Name Acquire -EvidenceRoot $evidenceRoot `
                    -Test { Test-SetupCmAcquire -Config $config -EvidenceRoot $evidenceRoot } `
                    -Apply { Invoke-SetupCmAcquire -ConfigPath $ConfigPath -EvidenceRoot $evidenceRoot | Out-Null } `
                    -Verify { Test-SetupCmAcquire -Config $config -EvidenceRoot $evidenceRoot } |
                    Write-Output
            }
            'Sql' {
                $sqlContext = [pscustomobject]@{ State = $null }
                Invoke-SetupCmStage -Name Sql -EvidenceRoot $evidenceRoot -Test {
                    $probe = Test-SetupCmSqlDesiredState -Config $config -EvidenceRoot $evidenceRoot -PassThru
                    $sqlContext.State = $probe
                    if ($probe -is [string]) { [string]$probe } else { [string]$probe.State }
                } -Apply {
                    Repair-SetupCmSqlDesiredState -Config $config -State $sqlContext.State -EvidenceRoot $evidenceRoot
                } -Verify {
                    Test-SetupCmSqlDesiredState -Config $config -EvidenceRoot $evidenceRoot
                } | Write-Output
            }
            'Mecm' {
                $mecmContext = [pscustomobject]@{ State = $null }
                Invoke-SetupCmStage -Name Mecm -EvidenceRoot $evidenceRoot -Test {
                    $probe = Test-SetupCmMecmDesiredState -Config $config -EvidenceRoot $evidenceRoot -PassThru
                    $mecmContext.State = $probe
                    if ($probe -is [string]) { [string]$probe } else { [string]$probe.State }
                } -Apply {
                    Repair-SetupCmMecmDesiredState -Config $config -State $mecmContext.State -EvidenceRoot $evidenceRoot
                } -Verify {
                    Test-SetupCmMecmDesiredState -Config $config -EvidenceRoot $evidenceRoot
                } | Write-Output
            }
            'Marker' {
                $markerContext = [pscustomobject]@{ State = $null }
                Invoke-SetupCmStage -Name Marker -EvidenceRoot $evidenceRoot -Test {
                    $probe = Test-SetupCmMarkerDesiredState -Config $config -EvidenceRoot $evidenceRoot -PassThru
                    $markerContext.State = $probe
                    [string]$probe.State
                } -Apply {
                    Repair-SetupCmMarkerDesiredState -Config $config -State $markerContext.State -EvidenceRoot $evidenceRoot
                } -Verify {
                    Test-SetupCmMarkerDesiredState -Config $config -EvidenceRoot $evidenceRoot
                } | Write-Output
            }
            'Health' {
                Invoke-SetupCmStage -Name Health -EvidenceRoot $evidenceRoot `
                    -Test { Test-SetupCmLabHealth -Config $config -EvidenceRoot $evidenceRoot } `
                    -Apply {} `
                    -Verify { Test-SetupCmLabHealth -Config $config -EvidenceRoot $evidenceRoot } |
                    Write-Output
            }
            default { throw "Unknown SetupCm stage: $name" }
        }
        if ($Mode -eq 'Guided') { Read-Host "Completed $name. Press Enter to continue" | Out-Null }
    }
}
