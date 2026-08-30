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

        It 'preserves an empty nested YAML list instead of collapsing it to null' {
            $emptyList = [System.Collections.Generic.List[object]]::new()

            $config = ConvertTo-SetupCmHashtable -Value @{
                sources = @{ prerequisites = $emptyList }
            }

            $null -eq $config.sources.prerequisites | Should -BeFalse
            $config.sources.prerequisites -is [object[]] | Should -BeTrue
            @($config.sources.prerequisites) | Should -HaveCount 0
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
            $config.sources.sqlServer.name | Should -Be 'sqlServer'
            $config.sources.mecm.cacheFile | Should -Be 'mecm-current-branch-2509.iso'
            $config.sources.mecm.name | Should -Be 'mecm'
            $config.sources.mecm.version | Should -Be '5.00.9141.1002'
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

        It 'requires an expected publisher for every runnable source' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                        sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'x64'
                        signatureRelativePath = 'setup.exe'
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm.iso'; licenseAccepted = $true
                        sizeBytes = 2048; version = '5.00.9141.1002'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'SMSSETUP\BIN\X64\setup.exe'
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            { Assert-SetupCmConfig -Config $config } |
                Should -Throw '*sources.sqlServer.publisher*'
        }

        It 'rejects a MECM branch label where native setup ProductVersion is required' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                        sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'setup.exe'
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm-current-branch-2509.iso'; licenseAccepted = $true
                        sizeBytes = 2048; version = '2509'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'SMSSETUP\BIN\X64\setup.exe'
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            { Assert-SetupCmConfig -Config $config } |
                Should -Throw '*sources.mecm.version*native setup.exe ProductVersion*'
        }

        It 'accepts pinned source identity metadata in a runnable configuration' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                        sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'setup.exe'
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm.iso'; licenseAccepted = $true
                        sizeBytes = 2048; version = '5.00.9141.1002'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'SMSSETUP\BIN\X64\setup.exe'
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            (Assert-SetupCmConfig -Config $config).sources.mecm.architecture | Should -Be 'x64'
        }

        It 'rejects an unknown bootstrapper architecture verification mode' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                        sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'; signatureRelativePath = 'setup.exe'
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm.iso'; licenseAccepted = $true
                        sizeBytes = 2048; version = '5.00.9141.1002'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'SMSSETUP\BIN\X64\setup.exe'
                    }
                    vcRedistX64 = @{
                        uri = 'https://vault/vc.exe'; sha256 = ('c' * 64)
                        cacheFile = 'vc_redist.x64.exe'; licenseAccepted = $true
                        sizeBytes = 4096; version = '14.51.36247.0'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        architectureVerification = 'trustTheFilename'
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            { Assert-SetupCmConfig -Config $config } |
                Should -Throw '*architectureVerification*signedVersionResource*'
        }

        It 'rejects competing payload-path and bootstrapper architecture proofs' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                        sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'; signatureRelativePath = 'setup.exe'
                        architectureRelativePath = 'x64\ScenarioEngine.exe'
                        architectureVerification = 'signedVersionResource'
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm.iso'; licenseAccepted = $true
                        sizeBytes = 2048; version = '5.00.9141.1002'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'SMSSETUP\BIN\X64\setup.exe'
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            { Assert-SetupCmConfig -Config $config } |
                Should -Throw '*only one architecture proof*'
        }

        It 'rejects a payload architecture proof for neutral media' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                        sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'neutral'
                        publisher = 'Microsoft Corporation'; signatureRelativePath = 'setup.exe'
                        architectureRelativePath = 'x64\ScenarioEngine.exe'
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm.iso'; licenseAccepted = $true
                        sizeBytes = 2048; version = '5.00.9141.1002'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'SMSSETUP\BIN\X64\setup.exe'
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            { Assert-SetupCmConfig -Config $config } |
                Should -Throw '*architecture proof requires x64 or x86*'
        }

        It 'requires a signed identity path for every runnable ISO source' {
            $config = @{
                safety = @{ isolatedLab = $true }
                sources = @{
                    sqlServer = @{
                        uri = 'https://vault/sql.iso'; sha256 = ('a' * 64)
                        cacheFile = 'sql.iso'; licenseAccepted = $true
                        sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                    }
                    mecm = @{
                        uri = 'https://vault/mecm.iso'; sha256 = ('b' * 64)
                        cacheFile = 'mecm.iso'; licenseAccepted = $true
                        sizeBytes = 2048; version = '5.00.9141.1002'; architecture = 'x64'
                        publisher = 'Microsoft Corporation'
                        signatureRelativePath = 'SMSSETUP\BIN\X64\setup.exe'
                    }
                }
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
            }

            { Assert-SetupCmConfig -Config $config } |
                Should -Throw '*sources.sqlServer.signatureRelativePath*'
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
