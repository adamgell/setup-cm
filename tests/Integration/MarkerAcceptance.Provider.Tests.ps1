$runProviderIntegration = $IsWindows -and $env:SETUPCM_LAB_PROVIDER_INTEGRATION -eq '1'

Describe 'Setup-CM marker provider acceptance' -Skip:(-not $runProviderIntegration) {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force
        $providerMode = if ([string]::IsNullOrWhiteSpace(
                $env:SETUPCM_MARKER_PROVIDER_MODE)) {
            'PostMigration'
        }
        else {
            [string]$env:SETUPCM_MARKER_PROVIDER_MODE
        }
        if ($providerMode -notin 'PreMigration', 'PostMigration') {
            throw 'SETUPCM_MARKER_PROVIDER_MODE must be PreMigration or PostMigration.'
        }
        $providerMode = if ($providerMode -ieq 'PreMigration') {
            'PreMigration'
        }
        else {
            'PostMigration'
        }
        $config = @{
            safety = @{ isolatedLab = $true; allowProductionTarget = $false }
            mecm = @{ siteCode = 'LAB'; siteServerFqdn = 'LABZ1-CM01.test.gell.one' }
            testClient = @{
                name = 'RING0IVY24-01'; domain = 'test.gell.one'; resourceId = 16777219
            }
            markerAcceptance = @{
                enabled = $true; labOnly = $true; siteCode = 'LAB'
                siteServerFqdn = 'LABZ1-CM01.test.gell.one'
                targetFqdn = 'RING0IVY24-01.test.gell.one'; targetResourceId = 16777219
            }
        }
    }

    It 'probes the exact bounded deployment without invoking any mutation adapter' {
        $state = & (Get-Module SetupCm) {
            param($resolvedConfig, $resolvedMode)
            $providers = Get-SetupCmMarkerDefaultProviders
            foreach ($name in @(
                'CreateEvidenceChannel', 'UpdateDetectorPolicy', 'SyncContent',
                'CreateApplication', 'CreateDeploymentType',
                'UpdateDeploymentType', 'Distribute', 'CreateCollection',
                'AddDirectMembership', 'RefreshCollection',
                'CreateDeployment', 'UpdateDeployment',
                'RequestClientPolicy', 'WaitForConvergence'
            )) {
                $actionName = $name
                $providers[$name] = {
                    throw "Unexpected live marker mutation: $actionName"
                }.GetNewClosure()
            }
            $resolvedState = Get-SetupCmMarkerDesiredState `
                -Config $resolvedConfig -Providers $providers
            if ($resolvedMode -ceq 'PostMigration') {
                Repair-SetupCmMarkerDesiredState -Config $resolvedConfig `
                    -State $resolvedState -Providers $providers
            }
            $resolvedState
        } $config $providerMode

        foreach ($name in 'EvidenceChannel', 'Client', 'ServerCompliance') {
            @($state.Components | Where-Object Name -eq $name) |
                Should -HaveCount 1
        }
        ($state.Components | Where-Object Name -eq Membership).MemberResourceId | Should -Be 16777219
        ($state.Components | Where-Object Name -eq Assignment).TargetCollectionId | Should -Not -BeNullOrEmpty
        ($state.Components | Where-Object Name -eq EvidenceChannel |
            ConvertTo-Json -Depth 8) | Should -Not -Match `
            'Aces|Rights|InheritanceFlags|PropagationFlags|AccessControlType'

        if ($providerMode -ceq 'PreMigration') {
            $state.State | Should -BeExactly 'NotCompliant'
            @($state.Components | Where-Object State -ne 'Compliant' |
                Sort-Object Name | ForEach-Object {
                    '{0}/{1}' -f $_.Name, $_.Reason
                }) | Should -BeExactly @(
                'Client/ClientEvidencePending',
                'DeploymentType/ApprovedDetectorUpgrade',
                'EvidenceChannel/Missing'
            )
            return
        }

        $state.State | Should -BeExactly 'Compliant'
        @($state.Components | Where-Object State -ne 'Compliant') |
            Should -HaveCount 0
        $client = $state.Components | Where-Object Name -eq Client
        $client.MarkerHash | Should -BeExactly `
            '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
        $client.MarkerLength | Should -Be 78
        $client.MarkerHashVerification | Should -BeIn @(
            'DirectAuthenticatedFileRead',
            'DirectAuthenticatedClientEvidence'
        )
    }
}
