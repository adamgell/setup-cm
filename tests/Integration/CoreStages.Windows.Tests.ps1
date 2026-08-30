Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

$runLabIntegration = $IsWindows -and $env:SETUPCM_LAB_INTEGRATION -eq '1'

Describe 'LabZ1 core-stage read-only providers' -Tag LabIntegration -Skip:(-not $runLabIntegration) {
    InModuleScope SetupCm {
        BeforeAll {
            $script:labConfig = @{
                topology = 'single-box'
                evidenceRoot = $TestDrive
                sql = @{
                    instanceName = 'MSSQLSERVER'
                    installDirectory = 'C:\Program Files\Microsoft SQL Server'
                    serviceAccount = 'NT AUTHORITY\NETWORK SERVICE'
                    sysAdminAccounts = @('TEST\Domain Admins', 'NT AUTHORITY\SYSTEM')
                }
                mecm = @{
                    siteCode = 'LAB'
                    siteName = 'LABZ1 Configuration Manager'
                    sqlServer = 'LABZ1-CM01.test.gell.one'
                    siteServerFqdn = 'LABZ1-CM01.test.gell.one'
                    smsInstallDir = 'C:\Program Files\Microsoft Configuration Manager'
                }
                testClient = @{
                    name = 'RING0IVY24-01'
                    domain = 'test.gell.one'
                }
                markerAcceptance = @{ targetResourceId = 16777219 }
            }
        }

        BeforeEach {
            Mock Start-Process { throw 'A read-only integration probe attempted to start a process.' }
            Mock Install-SetupCmSql { throw 'A read-only integration probe attempted SQL setup.' }
            Mock Install-SetupCmPrimarySite { throw 'A read-only integration probe attempted MECM setup.' }
            Mock Install-SetupCmMecmVcRedist { throw 'A read-only integration probe attempted VC runtime setup.' }
            Mock Install-SetupCmMecmAdk { throw 'A read-only integration probe attempted ADK setup.' }
            Mock Install-SetupCmMecmWinPeAddOn { throw 'A read-only integration probe attempted WinPE setup.' }
            Mock Install-SetupCmMecmOdbcDriver18 { throw 'A read-only integration probe attempted ODBC setup.' }
        }

        It 'reports the real SQL desired state compliant without installation' {
            $state = Get-SetupCmSqlDesiredState -Config $script:labConfig

            $state.State | Should -Be 'Compliant'
            @($state.Components | Where-Object State -ne 'Compliant') | Should -HaveCount 0
            Should -Invoke Start-Process -Times 0 -Exactly
            Should -Invoke Install-SetupCmSql -Times 0 -Exactly
        }

        It 'reports the real MECM desired state compliant without media or setup' {
            $state = Get-SetupCmMecmDesiredState -Config $script:labConfig

            $state.State | Should -Be 'Compliant'
            @($state.Components | Where-Object State -ne 'Compliant') | Should -HaveCount 0
            Should -Invoke Start-Process -Times 0 -Exactly
            Should -Invoke Install-SetupCmPrimarySite -Times 0 -Exactly
        }

        It 'writes a fresh compliant Health artifact using only read-only checks' {
            Test-SetupCmLabHealth -Config $script:labConfig -EvidenceRoot $TestDrive |
                Should -Be 'Compliant'

            Test-Path -LiteralPath (Join-Path $TestDrive 'health.json') -PathType Leaf |
                Should -BeTrue
            Should -Invoke Start-Process -Times 0 -Exactly
        }
    }
}
