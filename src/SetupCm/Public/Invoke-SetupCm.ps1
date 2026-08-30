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
                Invoke-SetupCmStage -Name Acquire -EvidenceRoot $evidenceRoot `
                    -Test { Test-SetupCmAcquire -Config $config -EvidenceRoot $evidenceRoot } `
                    -Apply { Invoke-SetupCmAcquire -ConfigPath $ConfigPath -EvidenceRoot $evidenceRoot | Out-Null } `
                    -Verify { Test-SetupCmAcquire -Config $config -EvidenceRoot $evidenceRoot } |
                    Write-Output
            }
            'Sql' {
                Invoke-SetupCmStage -Name Sql -EvidenceRoot $evidenceRoot -Test {
                    if ((Test-SetupCmSql -InstanceName $config.sql.instanceName) -eq 'Compliant' -and (Test-SetupCmSqlNetwork -InstanceName $config.sql.instanceName) -eq 'Compliant') { 'Compliant' } else { 'NotCompliant' }
                } -Apply {
                    if ((Test-SetupCmSql -InstanceName $config.sql.instanceName) -ne 'Compliant') {
                        $media = Get-SetupCmArtifact -Source $config.sources.sqlServer -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
                        Install-SetupCmWindowsPrerequisites
                        Install-SetupCmSql -MediaPath $media.Path -Sql $config.sql
                    }
                    Enable-SetupCmSqlNetwork -InstanceName $config.sql.instanceName
                } -Verify {
                    if ((Test-SetupCmSql -InstanceName $config.sql.instanceName) -eq 'Compliant' -and (Test-SetupCmSqlNetwork -InstanceName $config.sql.instanceName) -eq 'Compliant') { 'Compliant' } else { 'NotCompliant' }
                } | Write-Output
            }
            'Mecm' {
                Invoke-SetupCmStage -Name Mecm -EvidenceRoot $evidenceRoot -Test { 'NotCompliant' } -Apply {
                    $vcRedistSources = @{ x64 = 'vcRedistX64'; x86 = 'vcRedistX86' }
                    foreach ($architecture in 'x64', 'x86') {
                        $sourceName = $vcRedistSources[$architecture]
                        if (-not $config.sources.ContainsKey($sourceName)) {
                            throw "sources.$sourceName is required before MECM prerequisite download."
                        }
                    }
                    foreach ($architecture in 'x64', 'x86') {
                        $sourceName = $vcRedistSources[$architecture]
                        if ((Test-SetupCmMecmVcRedistArchitecture -Architecture $architecture) -ne 'Compliant') {
                            Install-SetupCmMecmVcRedist -Source $config.sources[$sourceName] -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
                        }
                    }
                    if ((Test-SetupCmMecmVcRedist) -ne 'Compliant') {
                        throw 'Microsoft Visual C++ Redistributable x64 and x86 version 14.34 or later are required before MECM prerequisite download.'
                    }
                    $media = Get-SetupCmArtifact -Source $config.sources.mecm -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
                    if (-not $config.sources.ContainsKey('adk')) {
                        throw 'sources.adk is required before MECM installation.'
                    }
                    if ((Test-SetupCmMecmAdk) -ne 'Compliant') {
                        Install-SetupCmMecmAdk -Source $config.sources.adk -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
                    }
                    if (-not $config.sources.ContainsKey('adkWinPe')) {
                        throw 'sources.adkWinPe is required before MECM installation.'
                    }
                    if ((Test-SetupCmMecmWinPeAddOn) -ne 'Compliant') {
                        Install-SetupCmMecmWinPeAddOn -Source $config.sources.adkWinPe -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
                    }
                    if (-not $config.sources.ContainsKey('odbcDriver18')) {
                        throw 'sources.odbcDriver18 is required before MECM prerequisite download.'
                    }
                    if ((Test-SetupCmMecmOdbcDriver18) -ne 'Compliant') {
                        Install-SetupCmMecmOdbcDriver18 -Source $config.sources.odbcDriver18 -CacheRoot $config.cacheRoot -EvidenceRoot $evidenceRoot
                    }
                    Get-SetupCmMecmPrerequisites -MediaPath $media.Path -PrerequisitePath $config.mecm.prerequisitePath | Out-Null
                    Install-SetupCmPrimarySite -MediaPath $media.Path -Mecm $config.mecm -EvidenceRoot $evidenceRoot | Out-Null
                } -Verify { 'Compliant' } | Write-Output
            }
            'Health' { Invoke-SetupCmStage -Name Health -EvidenceRoot $evidenceRoot -Test { 'NotCompliant' } -Apply {} -Verify { Test-SetupCmLabHealth -Config $config -EvidenceRoot $evidenceRoot } | Write-Output }
            default { throw "Unknown SetupCm stage: $name" }
        }
        if ($Mode -eq 'Guided') { Read-Host "Completed $name. Press Enter to continue" | Out-Null }
    }
}
