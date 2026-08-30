$runProviderIntegration = $IsWindows -and $env:SETUPCM_LAB_PROVIDER_INTEGRATION -eq '1'

Describe 'Setup-CM marker provider acceptance' -Skip:(-not $runProviderIntegration) {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force
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

    It 'finds the exact one-device marker deployment and proves reconciliation is a no-op' {
        $state = & (Get-Module SetupCm) {
            param($resolvedConfig)
            Get-SetupCmMarkerDesiredState -Config $resolvedConfig
        } $config

        $state.State | Should -BeExactly 'Compliant'
        @($state.Components | Where-Object State -ne 'Compliant') | Should -HaveCount 0
        ($state.Components | Where-Object Name -eq Membership).MemberResourceId | Should -Be 16777219
        ($state.Components | Where-Object Name -eq Assignment).TargetCollectionId | Should -Not -BeNullOrEmpty
        ($state.Components | Where-Object Name -eq Client).MarkerHash |
            Should -BeExactly '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'

        & (Get-Module SetupCm) {
            param($resolvedConfig, $resolvedState)
            $mutationProviders = @{}
            foreach ($name in @(
                'SyncContent', 'CreateApplication', 'CreateDeploymentType', 'UpdateDeploymentType',
                'Distribute', 'CreateCollection', 'AddDirectMembership', 'RefreshCollection',
                'CreateDeployment', 'UpdateDeployment', 'RequestClientPolicy'
            )) {
                $actionName = $name
                $mutationProviders[$name] = {
                    throw "Unexpected live marker mutation: $actionName"
                }.GetNewClosure()
            }
            Repair-SetupCmMarkerDesiredState -Config $resolvedConfig -State $resolvedState `
                -Providers $mutationProviders
        } $config $state
    }
}
