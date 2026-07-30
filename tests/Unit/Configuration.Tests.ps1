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
                Assert-SetupCmConfig @{ safety = @{ isolatedLab = $true }; sources = @{ sqlServer = @{ uri='https://vault/sql'; sha256=('a' * 64) } } }
            } | Should -Throw '*sources.mecm*'
        }

        It 'reads the documented single-box example' {
            $config = Read-SetupCmConfig -Path "$PSScriptRoot/../../config/lab.example.yaml"
            $config.topology | Should -Be 'single-box'
            $config.sources.sqlServer.cacheFile | Should -Be 'sql-server.iso'
        }

        It 'rejects installer placeholders in a runnable configuration' {
            {
                Assert-SetupCmConfig @{ safety=@{ isolatedLab=$true }; sources=@{
                    sqlServer=@{ uri='https://vault/'; sha256='REPLACE_WITH_SHA256' }
                    mecm=@{ uri='https://vault/'; sha256=('a' * 64) }
                } }
            } | Should -Throw '*placeholder*'
        }
    }
}
