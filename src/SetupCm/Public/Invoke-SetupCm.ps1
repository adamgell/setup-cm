function Invoke-SetupCm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [ValidateSet('Guided', 'Unattended')]
        [string]$Mode = 'Guided',

        [string[]]$Stage
    )

    $config = Read-SetupCmConfig -Path $ConfigPath
    $evidenceRoot = New-SetupCmRunEvidence -Root $config.evidenceRoot
    $selected = if ($Stage) { $Stage } else { @('Acquire', 'Sql', 'Mecm', 'Health') }
    foreach ($name in $selected) {
        switch ($name) {
            'Acquire' {
                Invoke-SetupCmStage -Name Acquire -EvidenceRoot $evidenceRoot -Test { 'NotCompliant' } -Apply { Invoke-SetupCmAcquire -ConfigPath $ConfigPath -EvidenceRoot $evidenceRoot | Out-Null } -Verify { 'Compliant' } | Write-Output
            }
            'Sql' {
                Invoke-SetupCmStage -Name Sql -EvidenceRoot $evidenceRoot -Test { Test-SetupCmSql -InstanceName $config.sql.instanceName } -Apply {
                    $media = Get-SetupCmArtifact -Source $config.sources.sqlServer -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
                    Install-SetupCmWindowsPrerequisites
                    Install-SetupCmSql -MediaPath $media.Path -Sql $config.sql
                } -Verify { Verify-SetupCmSql -InstanceName $config.sql.instanceName } | Write-Output
            }
            'Mecm' {
                Invoke-SetupCmStage -Name Mecm -EvidenceRoot $evidenceRoot -Test { 'NotCompliant' } -Apply {
                    $media = Get-SetupCmArtifact -Source $config.sources.mecm -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
                    Install-SetupCmPrimarySite -MediaPath $media.Path -Mecm $config.mecm -EvidenceRoot $evidenceRoot | Out-Null
                } -Verify { 'Compliant' } | Write-Output
            }
            'Health' { Invoke-SetupCmStage -Name Health -EvidenceRoot $evidenceRoot -Test { 'NotCompliant' } -Apply {} -Verify { Test-SetupCmLabHealth -Config $config -EvidenceRoot $evidenceRoot } | Write-Output }
            default { throw "Unknown SetupCm stage: $name" }
        }
        if ($Mode -eq 'Guided') { Read-Host "Completed $name. Press Enter to continue" | Out-Null }
    }
}
