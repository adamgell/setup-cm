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

        It 'pins the configured SQL instance directory in setup arguments' {
            $script:IsWindows = $true
            Mock Get-SetupCmMediaRoot { $TestDrive }
            Mock Test-Path { $true }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmSql -MediaPath 'C:\SetupCm\cache\sql.iso' -Sql @{
                instanceName = 'MSSQLSERVER'
                installDirectory = 'D:\SQL\'
                sysAdminAccounts = @('TEST\CMSetupAdmins')
            }

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains '/INSTANCEDIR="D:\SQL"'
            }
        }
    }
}

Describe 'New-SetupCmSqlConnection' {
    InModuleScope SetupCm {
        It 'builds an integrated encrypted connection using canonical SQL keywords' {
            Mock Add-Type {}
            $config = @{
                sql = @{ instanceName = 'MSSQLSERVER' }
                mecm = @{ sqlServer = 'LABZ1-CM01.test.gell.one'; siteServerFqdn = 'LABZ1-CM01.test.gell.one' }
            }

            $connection = New-SetupCmSqlConnection -Config $config -Database 'master'
            try {
                $connection.DataSource | Should -Be 'LABZ1-CM01.test.gell.one'
                $connection.Database | Should -Be 'master'
                $connection.ConnectionString | Should -Match 'Integrated Security=True'
                $connection.ConnectionString | Should -Match 'Encrypt=True'
                $connection.ConnectionString | Should -Match 'TrustServerCertificate=False'
                Should -Invoke Add-Type -Times 1 -Exactly -ParameterFilter {
                    $AssemblyName -eq 'System.Data.SqlClient'
                }
            }
            finally {
                if ($null -ne $connection) { $connection.Dispose() }
            }
        }

        It 'fails with a bounded configuration error before loading SQL dependencies when the server identity is missing' {
            Mock Add-Type {}

            {
                New-SetupCmSqlConnection -Config @{
                    sql = @{ instanceName = 'MSSQLSERVER' }
                } -Database 'master'
            } | Should -Throw '*mecm.sqlServer or mecm.siteServerFqdn*'
            Should -Invoke Add-Type -Times 0 -Exactly
        }
    }
}

Describe 'Get-SetupCmSqlDesiredState' {
    InModuleScope SetupCm {
        BeforeAll {
            function New-TestSqlConfig {
                @{
                    topology = 'single-box'
                    mecm = @{
                        siteCode = 'LAB'
                        siteServerFqdn = 'LABZ1-CM01.test.gell.one'
                    }
                    sql = @{
                        instanceName = 'MSSQLSERVER'
                        installDirectory = 'D:\SQL'
                        serviceAccount = 'NT AUTHORITY\NETWORK SERVICE'
                        sysAdminAccounts = @('TEST\CMSetupAdmins', 'NT AUTHORITY\SYSTEM')
                    }
                }
            }

            function New-CompliantSqlProviders {
                @{
                    Host = { @{ Fqdn = 'LABZ1-CM01.test.gell.one' } }
                    WindowsFeatures = {
                        @('NET-Framework-Features', 'BITS', 'Web-Server')
                    }
                    Instance = {
                        param($InstanceName)
                        @{
                            Exists = $true
                            InstanceName = 'MSSQLSERVER'
                            InstallDirectory = 'D:\SQL'
                        }
                    }
                    Service = {
                        param($ServiceName)
                        @{
                            Status = 'Running'
                            StartType = 'Automatic'
                            StartName = 'NT AUTHORITY\NETWORK SERVICE'
                        }
                    }
                    Network = {
                        param($InstanceName)
                        @{ Enabled = 1; TcpPort = '1433'; TcpDynamicPorts = ''; Listening = $true }
                    }
                    Firewall = { $true }
                    VcRuntime = { param($Architecture) $true }
                    Site = { $true }
                    Database = {
                        param($Config)
                        @{
                            MasterReachable = $true
                            InstanceName = 'MSSQLSERVER'
                            DatabaseReachable = $true
                            SysAdminAccounts = @('TEST\CMSetupAdmins', 'NT AUTHORITY\SYSTEM')
                        }
                    }
                }
            }
        }

        It 'reports Compliant only when every owned SQL component matches' {
            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers (New-CompliantSqlProviders)

            $state.State | Should -Be 'Compliant'
            @($state.Components | Where-Object State -ne 'Compliant') | Should -HaveCount 0
        }

        It 'fails closed when explicit SQL sysadmin configuration is missing or empty' -ForEach @(
            @{ Variant = 'missing'; Accounts = $null }
            @{ Variant = 'empty'; Accounts = @() }
        ) {
            $config = New-TestSqlConfig
            if ($Variant -eq 'missing') {
                $config.sql.Remove('sysAdminAccounts')
            }
            else {
                $config.sql.sysAdminAccounts = $Accounts
            }

            $state = Get-SetupCmSqlDesiredState -Config $config -Providers (New-CompliantSqlProviders)

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'SqlSysAdmins').Reason |
                Should -Be 'MissingSysAdminAccounts'
        }

        It 'fails closed on a target host mismatch' {
            $providers = New-CompliantSqlProviders
            $providers.Host = { @{ Fqdn = 'OTHER-CM01.test.gell.one' } }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'TargetHost').Reason | Should -Be 'HostMismatch'
        }

        It 'treats an absent configured instance as repairable without running database diagnostics' {
            $script:databaseProbed = $false
            $providers = New-CompliantSqlProviders
            $providers.Instance = { @{ Exists = $false; InstanceName = $null } }
            $providers.Site = { $false }
            $providers.Database = { $script:databaseProbed = $true; throw 'must not run' }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'SqlInstance').Reason | Should -Be 'Missing'
            $script:databaseProbed | Should -BeFalse
        }

        It 'fails closed when a site exists but the configured SQL instance appears absent' {
            $script:databaseProbed = $false
            $providers = New-CompliantSqlProviders
            $providers.Instance = { @{ Exists = $false; InstanceName = $null } }
            $providers.Site = { $true }
            $providers.Database = { $script:databaseProbed = $true; throw 'must not run' }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'SqlInstance').Reason |
                Should -Be 'SitePresentWithoutInstance'
            $script:databaseProbed | Should -BeFalse
        }

        It 'fails closed when another SQL instance exists instead of the configured instance' {
            $providers = New-CompliantSqlProviders
            $providers.Instance = {
                @{ Exists = $false; InstanceName = $null; OtherInstances = @('SQLEXPRESS') }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'SqlInstance').Reason |
                Should -Be 'DifferentInstancePresent'
        }

        It 'fails closed when the installed instance directory conflicts with configuration' {
            $providers = New-CompliantSqlProviders
            $providers.Instance = {
                @{ Exists = $true; InstanceName = 'MSSQLSERVER'; InstallDirectory = 'E:\Unexpected' }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'SqlInstance').Reason |
                Should -Be 'InstallDirectoryMismatch'
        }

        It 'reports only missing Windows features as repairable drift' {
            $providers = New-CompliantSqlProviders
            $providers.WindowsFeatures = { @('NET-Framework-Features', 'BITS') }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'WindowsFeatures').Missing |
                Should -Be @('Web-Server')
        }

        It 'reports stopped or non-automatic SQL service state as repairable drift' {
            $providers = New-CompliantSqlProviders
            $providers.Service = {
                @{ Status = 'Stopped'; StartType = 'Manual'; StartName = 'NT AUTHORITY\NETWORK SERVICE' }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'SqlService').State |
                Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'SqlServiceAccount').State |
                Should -Be 'Compliant'
        }

        It 'reports only a missing setup-cm firewall rule as repairable drift' {
            $providers = New-CompliantSqlProviders
            $providers.Firewall = { $false }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'SqlFirewall').Reason |
                Should -Be 'Missing'
        }

        It 'fails closed when database diagnostics are unavailable on an installed instance' {
            $providers = New-CompliantSqlProviders
            $providers.Database = { throw 'diagnostic unavailable' }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'SqlDatabase').Reason | Should -Be 'ProbeUnavailable'
        }

        It 'classifies only a missing TCP configuration as repairable drift' {
            $providers = New-CompliantSqlProviders
            $providers.Network = {
                @{ Enabled = 0; TcpPort = ''; TcpDynamicPorts = '0'; Listening = $false }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'SqlNetwork').State | Should -Be 'NotCompliant'
            @($state.Components | Where-Object { $_.State -eq 'NotCompliant' -and $_.Name -ne 'SqlNetwork' }) |
                Should -HaveCount 0
        }

        It 'fails closed when an existing site has no reachable CM_LAB database' {
            $providers = New-CompliantSqlProviders
            $providers.Database = {
                @{
                    MasterReachable = $true
                    InstanceName = 'MSSQLSERVER'
                    DatabaseReachable = $false
                    SysAdminAccounts = @('TEST\CMSetupAdmins', 'NT AUTHORITY\SYSTEM')
                }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'SqlDatabase').Reason | Should -Be 'SiteDatabaseUnavailable'
        }

        It 'does not require CM_LAB before a site has been installed' {
            $providers = New-CompliantSqlProviders
            $providers.Site = { $false }
            $providers.Database = {
                @{
                    MasterReachable = $true
                    InstanceName = 'MSSQLSERVER'
                    DatabaseReachable = $false
                    SysAdminAccounts = @('TEST\CMSetupAdmins', 'NT AUTHORITY\SYSTEM')
                }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Compliant'
            ($state.Components | Where-Object Name -eq 'SqlDatabase').Reason |
                Should -Be 'MasterReachable'
        }

        It 'fails closed when the master query reports unreachable' {
            $providers = New-CompliantSqlProviders
            $providers.Database = {
                @{
                    MasterReachable = $false
                    InstanceName = 'MSSQLSERVER'
                    DatabaseReachable = $false
                    SysAdminAccounts = @()
                }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'SqlDatabase').Reason |
                Should -Be 'ProbeUnavailable'
        }

        It 'fails closed on a configured service-account mismatch' {
            $providers = New-CompliantSqlProviders
            $providers.Service = {
                @{ Status = 'Running'; StartType = 'Automatic'; StartName = 'TEST\UnexpectedSqlAccount' }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'SqlServiceAccount').Reason | Should -Be 'AccountMismatch'
        }

        It 'reports only the missing explicit sysadmin membership as repairable' {
            $providers = New-CompliantSqlProviders
            $providers.Database = {
                @{
                    MasterReachable = $true
                    InstanceName = 'MSSQLSERVER'
                    DatabaseReachable = $true
                    SysAdminAccounts = @('NT AUTHORITY\SYSTEM')
                }
            }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'SqlSysAdmins').Missing |
                Should -Be @('TEST\CMSetupAdmins')
        }

        It 'reports one missing VC runtime architecture as repairable' {
            $providers = New-CompliantSqlProviders
            $providers.VcRuntime = { param($Architecture) $Architecture -eq 'x64' }

            $state = Get-SetupCmSqlDesiredState -Config (New-TestSqlConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'VcRuntimeX86').State | Should -Be 'NotCompliant'
        }
    }
}

Describe 'Repair-SetupCmSqlDesiredState' {
    InModuleScope SetupCm {
        BeforeEach {
            Mock Install-SetupCmWindowsPrerequisites {}
            Mock Install-SetupCmMecmVcRedist {}
            Mock Install-SetupCmSql {}
            Mock Set-SetupCmSqlServiceState {}
            Mock Enable-SetupCmSqlNetwork {}
            Mock Enable-SetupCmSqlFirewall {}
            Mock Add-SetupCmSqlSysAdmin {}
            Mock Get-SetupCmArtifact { [pscustomobject]@{ Path = 'C:\cache\sql.iso' } }
        }

        It 'repairs only a missing SQL firewall rule' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{ Name = 'SqlFirewall'; State = 'NotCompliant'; Reason = 'Missing' }
                )
            }
            $config = @{
                cacheRoot = 'C:\cache'; evidenceRoot = $TestDrive
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
                sources = @{}
            }

            Repair-SetupCmSqlDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            Should -Invoke Enable-SetupCmSqlFirewall -Times 1 -Exactly
            Should -Invoke Install-SetupCmSql -Times 0 -Exactly
            Should -Invoke Enable-SetupCmSqlNetwork -Times 0 -Exactly
            Should -Invoke Install-SetupCmWindowsPrerequisites -Times 0 -Exactly
        }

        It 'never repairs a conflicting SQL state' {
            $state = [pscustomobject]@{
                State = 'Conflict'
                Components = @([pscustomobject]@{ Name = 'TargetHost'; State = 'Conflict'; Reason = 'HostMismatch' })
            }

            { Repair-SetupCmSqlDesiredState -Config @{ sql = @{}; sources = @{} } -State $state -EvidenceRoot $TestDrive } |
                Should -Throw '*conflict*'
            Should -Invoke Install-SetupCmSql -Times 0 -Exactly
        }

        It 'installs an absent SQL instance once and completes owned bootstrap state' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{ Name = 'SqlInstance'; State = 'NotCompliant'; Reason = 'Missing' }
                )
            }
            $config = @{
                cacheRoot = 'C:\cache'
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
                sources = @{ sqlServer = @{ name = 'sqlServer' } }
            }

            Repair-SetupCmSqlDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
            Should -Invoke Install-SetupCmSql -Times 1 -Exactly
            Should -Invoke Set-SetupCmSqlServiceState -Times 1 -Exactly
            Should -Invoke Enable-SetupCmSqlNetwork -Times 1 -Exactly
            Should -Invoke Enable-SetupCmSqlFirewall -Times 1 -Exactly
            Should -Invoke Add-SetupCmSqlSysAdmin -Times 0 -Exactly
        }

        It 'installs only explicitly missing Windows features' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{
                        Name = 'WindowsFeatures'; State = 'NotCompliant'; Reason = 'Missing'
                        Missing = @('Web-Server')
                    }
                )
            }
            $config = @{ cacheRoot = 'C:\cache'; sql = @{}; sources = @{} }

            Repair-SetupCmSqlDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            Should -Invoke Install-SetupCmWindowsPrerequisites -Times 1 -Exactly -ParameterFilter {
                @($FeatureName).Count -eq 1 -and $FeatureName[0] -eq 'Web-Server'
            }
            Should -Invoke Install-SetupCmSql -Times 0 -Exactly
        }

        It 'validates every required source before applying any SQL repair' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{
                        Name = 'WindowsFeatures'; State = 'NotCompliant'; Reason = 'Missing'
                        Missing = @('Web-Server')
                    }
                    [pscustomobject]@{ Name = 'VcRuntimeX86'; State = 'NotCompliant'; Reason = 'Missing' }
                )
            }
            $config = @{ cacheRoot = 'C:\cache'; sql = @{}; sources = @{} }

            { Repair-SetupCmSqlDesiredState -Config $config -State $state -EvidenceRoot $TestDrive } |
                Should -Throw '*sources.vcRedistX86*'
            Should -Invoke Install-SetupCmWindowsPrerequisites -Times 0 -Exactly
            Should -Invoke Install-SetupCmMecmVcRedist -Times 0 -Exactly
        }

        It 'installs only the missing VC runtime architecture' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{ Name = 'VcRuntimeX86'; State = 'NotCompliant'; Reason = 'Missing' }
                )
            }
            $config = @{
                cacheRoot = 'C:\cache'; sql = @{}
                sources = @{ vcRedistX86 = @{ name = 'vcRedistX86' } }
            }

            Repair-SetupCmSqlDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            Should -Invoke Install-SetupCmMecmVcRedist -Times 1 -Exactly -ParameterFilter {
                $Source.name -eq 'vcRedistX86'
            }
            Should -Invoke Install-SetupCmSql -Times 0 -Exactly
        }

        It 'adds only explicitly missing SQL sysadmin accounts' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{
                        Name = 'SqlSysAdmins'; State = 'NotCompliant'; Reason = 'Missing'
                        Missing = @('TEST\CMSetupAdmins')
                    }
                )
            }
            $config = @{
                cacheRoot = 'C:\cache'; sql = @{ instanceName = 'MSSQLSERVER' }; sources = @{}
                mecm = @{ siteServerFqdn = 'LABZ1-CM01.test.gell.one' }
            }

            Repair-SetupCmSqlDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            Should -Invoke Add-SetupCmSqlSysAdmin -Times 1 -Exactly -ParameterFilter {
                $Account -eq 'TEST\CMSetupAdmins'
            }
            Should -Invoke Install-SetupCmSql -Times 0 -Exactly
        }

        It 'validates SQL connection identity before applying any mixed repair' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{
                        Name = 'WindowsFeatures'; State = 'NotCompliant'; Reason = 'Missing'
                        Missing = @('Web-Server')
                    }
                    [pscustomobject]@{
                        Name = 'SqlSysAdmins'; State = 'NotCompliant'; Reason = 'Missing'
                        Missing = @('TEST\CMSetupAdmins')
                    }
                )
            }
            $config = @{
                cacheRoot = 'C:\cache'
                sql = @{ instanceName = 'MSSQLSERVER' }
                sources = @{}
            }

            {
                Repair-SetupCmSqlDesiredState -Config $config -State $state -EvidenceRoot $TestDrive
            } | Should -Throw '*mecm.sqlServer or mecm.siteServerFqdn*'
            Should -Invoke Install-SetupCmWindowsPrerequisites -Times 0 -Exactly
            Should -Invoke Add-SetupCmSqlSysAdmin -Times 0 -Exactly
        }
    }
}

Describe 'Invoke-SetupCm SQL desired-state orchestration' {
    InModuleScope SetupCm {
        BeforeEach {
            $script:sqlProbeCount = 0
            $config = @{
                evidenceRoot = $TestDrive
                cacheRoot = 'C:\cache'
                sql = @{ instanceName = 'MSSQLSERVER'; sysAdminAccounts = @('TEST\Admins') }
                mecm = @{ siteCode = 'LAB'; siteServerFqdn = 'LABZ1-CM01.test.gell.one' }
                topology = 'single-box'
                sources = @{}
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Repair-SetupCmSqlDesiredState {}
        }

        It 'skips repair when SQL is already compliant' {
            Mock Test-SetupCmSqlDesiredState { 'Compliant' }

            $result = Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Sql

            $result.state | Should -Be 'Skipped'
            Should -Invoke Repair-SetupCmSqlDesiredState -Times 0 -Exactly
        }

        It 'repairs once and independently verifies compliance' {
            Mock Test-SetupCmSqlDesiredState {
                $script:sqlProbeCount++
                if ($script:sqlProbeCount -eq 1) { 'NotCompliant' } else { 'Compliant' }
            }

            $result = Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Sql

            $result.state | Should -Be 'Succeeded'
            Should -Invoke Repair-SetupCmSqlDesiredState -Times 1 -Exactly
            Should -Invoke Test-SetupCmSqlDesiredState -Times 2 -Exactly
        }

        It 'fails after one repair when independent verification still fails' {
            Mock Test-SetupCmSqlDesiredState { 'NotCompliant' }

            { Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Sql } |
                Should -Throw '*verification failed*'
            Should -Invoke Repair-SetupCmSqlDesiredState -Times 1 -Exactly
        }

        It 'never repairs a SQL conflict' {
            Mock Test-SetupCmSqlDesiredState { 'Conflict' }

            { Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Sql } |
                Should -Throw '*conflict*'
            Should -Invoke Repair-SetupCmSqlDesiredState -Times 0 -Exactly
        }
    }
}
