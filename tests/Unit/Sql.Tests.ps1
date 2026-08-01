Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Test-SetupCmSql' {
    InModuleScope SetupCm {
        It 'requires an enabled TCP listener on port 1433 for a default instance' {
            Test-SetupCmSqlNetwork -InstanceName 'MSSQLSERVER' -RegistryProvider {
                [pscustomobject]@{ Enabled = 1; TcpPort = '1433'; TcpDynamicPorts = '' }
            } -ListenerProvider { $true } | Should -Be 'Compliant'
        }

        It 'checks the default SQL service by its unqualified service name' {
            $script:queriedServiceName = $null

            Test-SetupCmSql -InstanceName 'MSSQLSERVER' -ServiceStateProvider {
                param($Name)
                $script:queriedServiceName = $Name
                [pscustomobject]@{ Status = 'Running' }
            } | Should -Be 'Compliant'

            $script:queriedServiceName | Should -Be 'MSSQLSERVER'
        }

        It 'returns Compliant when the configured SQL service is running' {
            Test-SetupCmSql -InstanceName 'MSSQLSERVER' -ServiceStateProvider {
                [pscustomobject]@{ Status = 'Running' }
            } | Should -Be 'Compliant'
        }

        It 'returns NotCompliant when the configured SQL service is stopped' {
            Test-SetupCmSql -InstanceName 'MSSQLSERVER' -ServiceStateProvider {
                [pscustomobject]@{ Status = 'Stopped' }
            } | Should -Be 'NotCompliant'
        }
    }
}

Describe 'Install-SetupCmSql' {
    InModuleScope SetupCm {
        It 'requires explicit SQL sysadmin accounts' {
            $script:IsWindows = $true
            Mock Get-SetupCmMediaRoot { $TestDrive }
            Mock Test-Path { $true }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            {
                Install-SetupCmSql -MediaPath 'C:\SetupCm\cache\sql.iso' -Sql @{ instanceName = 'MSSQLSERVER' }
            } | Should -Throw '*sysAdminAccounts*'
        }

        It 'uses NETWORK SERVICE and configures explicit SQL sysadmins when no service account is configured' {
            $script:IsWindows = $true
            Mock Get-SetupCmMediaRoot { $TestDrive }
            Mock Test-Path { $true }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmSql -MediaPath 'C:\SetupCm\cache\sql.iso' -Sql @{
                instanceName = 'MSSQLSERVER'
                sysAdminAccounts = @('TEST\Domain Admins', 'NT AUTHORITY\SYSTEM')
            }

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains '/SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"' -and
                $ArgumentList -contains '/TCPENABLED=1' -and
                $ArgumentList -contains '/SQLSYSADMINACCOUNTS="TEST\Domain Admins" "NT AUTHORITY\SYSTEM"'
            }
        }
    }
}
