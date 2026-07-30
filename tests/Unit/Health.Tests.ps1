Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Test-SetupCmLabHealth' {
    InModuleScope SetupCm {
        It 'returns NotCompliant when the Management Point check fails' {
            Test-SetupCmLabHealth -Config @{ sql = @{ instanceName = 'MSSQLSERVER' }; testClient = @{ name = 'CL01' } } -EvidenceRoot $TestDrive -Checks @{
                Sql = { $true }; ManagementPoint = { $false }; DistributionPoint = { $true }; Client = { $true }
            } |
                Should -Be 'NotCompliant'
        }
    }
}
