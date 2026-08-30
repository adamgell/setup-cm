Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Assert-SetupCmConfig' {
    InModuleScope SetupCm {
        It 'preserves scalar strings while normalizing nested YAML values' {
            $config = ConvertTo-SetupCmHashtable -Value @{
                sql = @{ sysAdminAccounts = @('TEST\\Domain Admins', 'NT AUTHORITY\\SYSTEM') }
            }

            $config.sql.sysAdminAccounts | Should -BeExactly @('TEST\\Domain Admins', 'NT AUTHORITY\\SYSTEM')
            $config.sql.sysAdminAccounts[0] | Should -BeOfType [string]
        }

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

        It 'requires explicit SQL sysadmin accounts' {
            {
                Assert-SetupCmConfig @{
                    safety = @{ isolatedLab = $true }
                    sources = @{
                        sqlServer = @{ uri='https://vault/sql'; sha256=('a' * 64) }
                        mecm = @{ uri='https://vault/mecm'; sha256=('b' * 64) }
                    }
                    sql = @{ instanceName = 'MSSQLSERVER' }
                }
            } | Should -Throw '*sql.sysAdminAccounts*'
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

        It 'requires pinned size version and architecture for runnable sources' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm.iso'; licenseAccepted = $true
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            { Assert-SetupCmConfig -Config $config } | Should -Throw '*sizeBytes*'
        }

        It 'accepts pinned source identity metadata in a runnable configuration' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                        sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'x64'
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm.iso'; licenseAccepted = $true
                        sizeBytes = 2048; version = '2503'; architecture = 'x64'
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            (Assert-SetupCmConfig -Config $config).sources.mecm.architecture | Should -Be 'x64'
        }

        It 'fails closed when enabled marker acceptance does not use the fixed LabZ1 identities' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{ uri = 'https://vault/sql'; sha256 = ('a' * 64) }
                    mecm = @{ uri = 'https://vault/mecm'; sha256 = ('b' * 64) }
                }
                sql = @{ sysAdminAccounts = @('TEST\Admins') }
                markerAcceptance = @{
                    enabled = $true
                    labOnly = $true
                    siteCode = 'LAB'
                    siteServerFqdn = 'OTHER-CM01.test.gell.one'
                    targetFqdn = 'RING0IVY24-01.test.gell.one'
                    targetResourceId = 16777219
                }
            }

            { Assert-SetupCmConfig -Config $config } | Should -Throw '*LABZ1-CM01*'
        }
    }
}
