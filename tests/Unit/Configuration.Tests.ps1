Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Assert-SetupCmConfig' {
    InModuleScope SetupCm {
        It 'rejects a production target without explicit approval' {
            {
                Assert-SetupCmConfig @{ safety = @{ isolatedLab = $false; allowProductionTarget = $false } }
            } | Should -Throw '*allowProductionTarget*'
        }

        It 'requires a SQL Server source' {
            {
                Assert-SetupCmConfig @{ safety = @{ isolatedLab = $true }; sources = @{} }
            } | Should -Throw '*sources.sqlServer*'
        }

        It 'requires a MECM source' {
            {
                Assert-SetupCmConfig @{ safety = @{ isolatedLab = $true }; sources = @{ sqlServer = @{} } }
            } | Should -Throw '*sources.mecm*'
        }

        It 'reads the documented single-box example' {
            $config = Read-SetupCmConfig -Path "$PSScriptRoot/../../config/lab.example.yaml"
            $config.topology | Should -Be 'single-box'
            $config.sources.sqlServer.cacheFile | Should -Be 'sql-server.iso'
        }
    }
}
