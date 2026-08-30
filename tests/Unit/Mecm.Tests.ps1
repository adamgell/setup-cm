Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'MECM source safety' {
    It 'does not assign to the read-only Host automatic variable' {
        $tokens = $null
        $parseErrors = $null
        $path = "$PSScriptRoot/../../src/SetupCm/Private/Mecm.ps1"
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $path,
            [ref]$tokens,
            [ref]$parseErrors
        )

        $parseErrors | Should -HaveCount 0
        $hostAssignments = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $node.Left.VariablePath.UserPath -ieq 'Host'
        }, $true))
        $hostAssignments | Should -HaveCount 0
    }
}

Describe 'New-SetupCmPrimarySiteScript' {
    InModuleScope SetupCm {
        It 'generates a current-branch standalone-primary answer file' {
            $script = New-SetupCmPrimarySiteScript -Mecm @{
                siteCode = 'LAB'; siteName = 'Lab Primary'; sqlServer = 'CM01.lab.example'
                smsInstallDir = 'D:\ConfigMgr'; prerequisitePath = 'D:\Sources\Redist';
                siteServerFqdn = 'CM01.lab.example'; productId = 'Eval'
            }

            $script | Should -Match '\[Identification\]'
            $script | Should -Match 'Action=InstallPrimarySite'
            $script | Should -Match 'SiteCode=LAB'
            $script | Should -Match 'SQLServerName=CM01.lab.example'
            $script | Should -Match 'PrerequisiteComp=1'
            $script | Should -Match 'ManagementPoint=CM01.lab.example'
            $script | Should -Match 'DistributionPoint=CM01.lab.example'
        }
    }
}

Describe 'Get-SetupCmMecmPrerequisites' {
    InModuleScope SetupCm {
        It 'runs the media Setup Downloader without a UI into the configured prerequisite folder' {
            $script:IsWindows = $true
            Mock Get-SetupCmMediaRoot { $TestDrive }
            Mock Test-Path { $true }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
            $destination = Join-Path $TestDrive 'Prereqs'

            Get-SetupCmMecmPrerequisites -MediaPath 'C:\SetupCm\cache\mecm.iso' -PrerequisitePath $destination | Should -Be $destination

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq (Join-Path $TestDrive 'SMSSETUP\BIN\X64\Setupdl.exe') -and
                $ArgumentList -contains '/NOUI' -and
                $ArgumentList -contains $destination
            }
        }
    }
}

Describe 'Install-SetupCmMecmOdbcDriver18' {
    InModuleScope SetupCm {
        It 'installs a verified, license-accepted ODBC artifact silently' {
            $script:IsWindows = $true
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Path = 'C:\SetupCm\cache\msodbcsql18-x64.msi' }
            }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmMecmOdbcDriver18 -Source @{ name = 'odbcDriver18'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive

            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'msiexec.exe' -and
                $ArgumentList -contains '/qn' -and
                $ArgumentList -contains 'IACCEPTMSODBCSQLLICENSETERMS=YES' -and
                $ArgumentList -contains 'C:\SetupCm\cache\msodbcsql18-x64.msi'
            }
        }
    }
}

Describe 'Test-SetupCmMecmVcRedist' {
    InModuleScope SetupCm {
        It 'uses the native hive for x64 and WOW6432Node for x86 runtime registration' {
            Get-SetupCmMecmVcRedistRegistryPath -Architecture x64 | Should -Be 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
            Get-SetupCmMecmVcRedistRegistryPath -Architecture x86 | Should -Be 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
        }

        It 'requires an installed VC++ v14 runtime at or above 14.34 for each architecture' {
            Test-SetupCmMecmVcRedistArchitecture -Architecture x64 -RegistryProvider {
                param($Architecture)
                @{ Installed = 1; Version = 'v14.34.31938.0' }
            } | Should -Be 'Compliant'

            Test-SetupCmMecmVcRedistArchitecture -Architecture x86 -RegistryProvider {
                param($Architecture)
                @{ Installed = 1; Version = '14.33.31629.0' }
            } | Should -Be 'NotCompliant'

            Test-SetupCmMecmVcRedistArchitecture -Architecture x64 -RegistryProvider {
                param($Architecture)
                @{ Installed = 'invalid'; Version = '14.44.35211.0' }
            } | Should -Be 'NotCompliant'
        }

        It 'requires both VC++ runtime architectures before MECM is compliant' {
            Test-SetupCmMecmVcRedist -RegistryProvider {
                param($Architecture)
                if ($Architecture -eq 'x64') {
                    @{ Installed = 1; Version = '14.44.35211.0' }
                }
                else {
                    @{ Installed = 0; Version = '14.44.35211.0' }
                }
            } | Should -Be 'NotCompliant'
        }
    }
}

Describe 'Install-SetupCmMecmVcRedist' {
    InModuleScope SetupCm {
        It 'installs a verified VC++ redistributable silently' {
            $script:IsWindows = $true
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Path = 'C:\SetupCm\cache\vc_redist.x64.exe' }
            }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmMecmVcRedist -Source @{ name = 'vcRedistX64'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive

            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'C:\SetupCm\cache\vc_redist.x64.exe' -and
                $ArgumentList -contains '/install' -and
                $ArgumentList -contains '/quiet' -and
                $ArgumentList -contains '/norestart'
            }
        }

        It 'rejects exit code 3010 and requires a restart before continuing' {
            $script:IsWindows = $true
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Path = 'C:\SetupCm\cache\vc_redist.x64.exe' }
            }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 3010 } }

            { Install-SetupCmMecmVcRedist -Source @{ name = 'vcRedistX64'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive } |
                Should -Throw '*restart before MECM setup can continue*'
        }
    }
}

Describe 'Install-SetupCmMecmAdk' {
    InModuleScope SetupCm {
        It 'reports compliant when the matching Windows PE add-on is installed' {
            Test-SetupCmMecmWinPeAddOn -DirectoryProvider {
                param($Path)
                $Path -eq 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment'
            } | Should -Be 'Compliant'
        }

        It 'installs the verified Windows PE add-on silently' {
            $script:IsWindows = $true
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Path = 'C:\SetupCm\cache\adkwinpesetup.exe' }
            }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmMecmWinPeAddOn -Source @{ name = 'adkWinPe'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'C:\SetupCm\cache\adkwinpesetup.exe' -and
                $ArgumentList -contains '/quiet' -and
                $ArgumentList -contains '/norestart'
            }
        }

        It 'reports compliant only when both Deployment Tools and USMT are installed' {
            Test-SetupCmMecmAdk -DirectoryProvider {
                param($Path)
                $Path -in @(
                    'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools',
                    'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\User State Migration Tool'
                )
            } | Should -Be 'Compliant'
        }

        It 'installs only the MECM-required ADK Deployment Tools and USMT features' {
            $script:IsWindows = $true
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Path = 'C:\SetupCm\cache\adksetup.exe' }
            }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmMecmAdk -Source @{ name = 'adk'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive

            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'C:\SetupCm\cache\adksetup.exe' -and
                $ArgumentList -contains '/quiet' -and
                $ArgumentList -contains '/norestart' -and
                $ArgumentList -contains 'OptionId.DeploymentTools' -and
                $ArgumentList -contains 'OptionId.UserStateMigrationTool'
            }
        }
    }
}

Describe 'Get-SetupCmMecmDesiredState' {
    InModuleScope SetupCm {
        BeforeAll {
            function New-TestMecmConfig {
                @{
                    topology = 'single-box'
                    cacheRoot = 'C:\SetupCm\cache'
                    evidenceRoot = $TestDrive
                    sql = @{ instanceName = 'MSSQLSERVER' }
                    mecm = @{
                        siteCode = 'LAB'
                        siteName = 'LABZ1 Configuration Manager'
                        sqlServer = 'LABZ1-CM01.test.gell.one'
                        siteServerFqdn = 'LABZ1-CM01.test.gell.one'
                        smsInstallDir = 'C:\Program Files\Microsoft Configuration Manager'
                        prerequisitePath = 'C:\SetupCm\Redist'
                        productId = 'Eval'
                    }
                    testClient = @{ name = 'RING0IVY24-01'; domain = 'test.gell.one' }
                    markerAcceptance = @{ targetResourceId = 16777219 }
                    sources = @{
                        mecm = @{ name = 'mecm' }
                        adk = @{ name = 'adk' }
                        adkWinPe = @{ name = 'adkWinPe' }
                        odbcDriver18 = @{ name = 'odbcDriver18' }
                        vcRedistX64 = @{ name = 'vcRedistX64' }
                        vcRedistX86 = @{ name = 'vcRedistX86' }
                    }
                }
            }

            function New-CompliantMecmProviders {
                @{
                    Host = { @{ Fqdn = 'LABZ1-CM01.test.gell.one' } }
                    Adk = { $true }
                    WinPe = { $true }
                    Odbc = { $true }
                    VcRuntime = { param($Architecture) $true }
                    Site = {
                        param($Config)
                        @{
                            Exists = $true
                            SiteCode = 'LAB'
                            SiteName = 'LABZ1 Configuration Manager'
                            ServerName = 'LABZ1-CM01.test.gell.one'
                            Type = 2
                            ParentSiteCode = ''
                            InstallDirectory = 'C:\Program Files\Microsoft Configuration Manager'
                            ProviderCount = 1
                            ProviderSiteCode = 'LAB'
                            ProviderMachine = 'LABZ1-CM01.test.gell.one'
                            ProviderForLocalSite = $true
                        }
                    }
                    Roles = {
                        @(
                            @{ RoleName = 'SMS Site Server'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                            @{ RoleName = 'SMS Provider'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                            @{ RoleName = 'SMS Management Point'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                            @{ RoleName = 'SMS Distribution Point'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                            @{ RoleName = 'SMS SQL Server'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                        )
                    }
                    Services = {
                        @(
                            @{ Name = 'SMS_EXECUTIVE'; Status = 'Running'; StartType = 'Automatic' }
                            @{ Name = 'SMS_SITE_COMPONENT_MANAGER'; Status = 'Running'; StartType = 'Automatic' }
                        )
                    }
                    ContentLibrary = {
                        @{ Path = 'C:\SCCMContentLib'; Accessible = $true; SiteCode = 'LAB' }
                    }
                    ClientProvider = {
                        param($Config)
                        @(
                            @{ Name = 'RING0IVY24-01'; ResourceId = 16777219; Active = 1; Obsolete = 0; Client = 1; ClientVersion = '5.00.9141.1011' }
                        )
                    }
                    ClientDatabase = {
                        param($Config)
                        @{
                            DatabaseName = 'CM_LAB'
                            ServerName = 'LABZ1-CM01'
                            Rows = @(
                                @{ Name = 'RING0IVY24-01'; ResourceId = 16777219; Active = 1; Obsolete = 0; Client = 1; ClientVersion = '5.00.9141.1011' }
                            )
                        }
                    }
                }
            }
        }

        It 'reports Compliant only for the exact single-box site and accepted client' {
            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers (New-CompliantMecmProviders)

            $state.State | Should -Be 'Compliant'
            @($state.Components | Where-Object State -ne 'Compliant') | Should -HaveCount 0
        }

        It 'compares the SQL database identity case-insensitively' {
            $providers = New-CompliantMecmProviders
            $databaseState = & $providers.ClientDatabase
            $databaseState.DatabaseName = 'cm_lab'
            $providers.ClientDatabase = { $databaseState }.GetNewClosure()

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Compliant'
            ($state.Components | Where-Object Name -eq 'AcceptedClientSql').State |
                Should -Be 'Compliant'
        }

        It 'accepts CM01 short names from WMI after the exact host boundary passes' {
            $providers = New-CompliantMecmProviders
            $site = & $providers.Site
            $site.ServerName = 'LABZ1-CM01'
            $site.ProviderMachine = 'LABZ1-CM01'
            $providers.Site = { $site }.GetNewClosure()

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Compliant'
            ($state.Components | Where-Object Name -eq 'MecmSite').State |
                Should -Be 'Compliant'
        }

        It 'fails closed on a target host mismatch before provider probes' {
            $script:siteProbed = $false
            $providers = New-CompliantMecmProviders
            $providers.Host = { @{ Fqdn = 'OTHER-CM01.test.gell.one' } }
            $providers.Site = { $script:siteProbed = $true; throw 'must not run' }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'TargetHost').Reason | Should -Be 'HostMismatch'
            $script:siteProbed | Should -BeFalse
        }

        It 'treats a genuinely absent site as repairable without probing roles or clients' {
            $script:dependentProbeCount = 0
            $providers = New-CompliantMecmProviders
            $providers.Site = { @{ Exists = $false } }
            $providers.Roles = { $script:dependentProbeCount++; throw 'must not run' }
            $providers.ClientProvider = { $script:dependentProbeCount++; throw 'must not run' }
            $providers.ClientDatabase = { $script:dependentProbeCount++; throw 'must not run' }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'MecmSite').Reason | Should -Be 'Missing'
            $script:dependentProbeCount | Should -Be 0
        }

        It 'fails closed on residual provider state when no complete site identity exists' {
            $providers = New-CompliantMecmProviders
            $providers.Site = { @{ Exists = $false; ResidualState = $true } }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'MecmSite').Reason |
                Should -Be 'ResidualInstallationState'
        }

        It 'fails closed on an existing site-code mismatch' {
            $providers = New-CompliantMecmProviders
            $providers.Site = {
                @{
                    Exists = $true; SiteCode = 'BAD'; SiteName = 'LABZ1 Configuration Manager'
                    ServerName = 'LABZ1-CM01.test.gell.one'; Type = 2; ParentSiteCode = ''
                    InstallDirectory = 'C:\Program Files\Microsoft Configuration Manager'
                    ProviderCount = 1; ProviderSiteCode = 'BAD'
                    ProviderMachine = 'LABZ1-CM01.test.gell.one'; ProviderForLocalSite = $true
                }
            }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'MecmSite').Reason | Should -Be 'SiteIdentityMismatch'
        }

        It 'fails closed when the local provider identity differs' {
            $providers = New-CompliantMecmProviders
            $siteProvider = $providers.Site
            $providers.Site = {
                $site = & $siteProvider
                $site.ProviderMachine = 'OTHER-CM01.test.gell.one'
                $site
            }.GetNewClosure()

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'MecmSite').Reason | Should -Be 'ProviderIdentityMismatch'
        }

        It 'fails closed when a required role is missing from the single box' {
            $providers = New-CompliantMecmProviders
            $providers.Roles = {
                @(
                    @{ RoleName = 'SMS Site Server'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                    @{ RoleName = 'SMS Provider'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                    @{ RoleName = 'SMS Management Point'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                    @{ RoleName = 'SMS SQL Server'; ServerName = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB' }
                )
            }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'MecmRoles').Missing |
                Should -Contain 'SMS Distribution Point'
        }

        It 'fails closed when a required role exists on another server' {
            $providers = New-CompliantMecmProviders
            $rolesProvider = $providers.Roles
            $providers.Roles = {
                @(& $rolesProvider) + @(
                    @{ RoleName = 'SMS Distribution Point'; ServerName = 'OTHER-DP.test.gell.one'; SiteCode = 'LAB' }
                )
            }.GetNewClosure()

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'MecmRoles').Reason | Should -Be 'DistributedRoleDetected'
        }

        It 'reports a stopped required service as repairable drift' {
            $providers = New-CompliantMecmProviders
            $providers.Services = {
                @(
                    @{ Name = 'SMS_EXECUTIVE'; Status = 'Stopped'; StartType = 'Manual' }
                    @{ Name = 'SMS_SITE_COMPONENT_MANAGER'; Status = 'Running'; StartType = 'Automatic' }
                )
            }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'MecmServices').Repair |
                Should -Be @('SMS_EXECUTIVE')
        }

        It 'reports only a missing ADK prerequisite as repairable drift' {
            $providers = New-CompliantMecmProviders
            $providers.Adk = { $false }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'NotCompliant'
            ($state.Components | Where-Object Name -eq 'Adk').State | Should -Be 'NotCompliant'
            @($state.Components | Where-Object { $_.State -eq 'NotCompliant' -and $_.Name -ne 'Adk' }) |
                Should -HaveCount 0
        }

        It 'fails closed when the registered content library is inaccessible' {
            $providers = New-CompliantMecmProviders
            $providers.ContentLibrary = {
                @{ Path = 'C:\SCCMContentLib'; Accessible = $false; SiteCode = 'LAB' }
            }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'ContentLibrary').Reason |
                Should -Be 'Unavailable'
        }

        It 'fails closed when the accepted provider client resource identity differs' {
            $providers = New-CompliantMecmProviders
            $providers.ClientProvider = {
                @(
                    @{ Name = 'RING0IVY24-01'; ResourceId = 99; Active = 1; Obsolete = 0; Client = 1; ClientVersion = '5.00.9141.1011' }
                )
            }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'AcceptedClient').Reason |
                Should -Be 'ResourceIdentityMismatch'
        }

        It 'fails closed when provider and SQL client rows disagree' {
            $providers = New-CompliantMecmProviders
            $providers.ClientDatabase = {
                @{
                    DatabaseName = 'CM_LAB'; ServerName = 'LABZ1-CM01'
                    Rows = @(
                        @{ Name = 'RING0IVY24-01'; ResourceId = 16777220; Active = 1; Obsolete = 0; Client = 1; ClientVersion = '5.00.9141.1011' }
                    )
                }
            }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'AcceptedClientSql').Reason |
                Should -Be 'ProviderSqlMismatch'
        }

        It 'fails closed when the site database identity differs' {
            $providers = New-CompliantMecmProviders
            $providers.ClientDatabase = {
                @{ DatabaseName = 'CM_BAD'; ServerName = 'OTHER-CM01'; Rows = @() }
            }

            $state = Get-SetupCmMecmDesiredState -Config (New-TestMecmConfig) -Providers $providers

            $state.State | Should -Be 'Conflict'
            ($state.Components | Where-Object Name -eq 'AcceptedClientSql').Reason |
                Should -Be 'DatabaseIdentityMismatch'
        }
    }
}

Describe 'Get-SetupCmMecmDefaultProviders' {
    InModuleScope SetupCm {
        BeforeAll {
            function Get-CimInstance {
                param($Namespace, $ClassName, $ErrorAction, $Filter)
            }
        }

        AfterAll {
            Remove-Item -Path 'function:Get-CimInstance' -ErrorAction SilentlyContinue
        }

        It 'normalizes an omitted optional ParentSiteCode from the live SMS_Site shape' {
            Mock Get-ItemProperty {
                [pscustomobject]@{
                    'Site Code' = 'LAB'
                    'Installation Directory' = 'C:\Program Files\Microsoft Configuration Manager'
                }
            } -ParameterFilter { $Path -eq 'HKLM:\SOFTWARE\Microsoft\SMS\Identification' }
            Mock Get-CimInstance {
                if ($ClassName -eq 'SMS_Site') {
                    return [pscustomobject]@{
                        SiteCode = 'LAB'; SiteName = 'LABZ1 Configuration Manager'
                        ServerName = 'LABZ1-CM01.test.gell.one'; Type = 2
                    }
                }
                if ($ClassName -eq 'SMS_ProviderLocation') {
                    return [pscustomobject]@{
                        SiteCode = 'LAB'; Machine = 'LABZ1-CM01.test.gell.one'
                        ProviderForLocalSite = $true
                    }
                }
            }
            $providers = Get-SetupCmMecmDefaultProviders

            $site = & $providers.Site @{ mecm = @{ siteCode = 'LAB' } }

            $site.ParentSiteCode | Should -Be ''
            $site.Exists | Should -BeTrue
        }

        It 'reports residual state when provider registration remains without identification' {
            Mock Get-ItemProperty { $null } -ParameterFilter {
                $Path -eq 'HKLM:\SOFTWARE\Microsoft\SMS\Identification'
            }
            Mock Get-CimInstance {
                [pscustomobject]@{
                    SiteCode = 'LAB'; Machine = 'LABZ1-CM01.test.gell.one'
                    ProviderForLocalSite = $true
                }
            } -ParameterFilter { $ClassName -eq 'SMS_ProviderLocation' }
            $providers = Get-SetupCmMecmDefaultProviders

            $site = & $providers.Site @{ mecm = @{ siteCode = 'LAB' } }

            $site.Exists | Should -BeFalse
            $site.ResidualState | Should -BeTrue
        }

        It 'escapes backslashes and apostrophes in the client WQL filter value' {
            $script:clientFilter = $null
            Mock Get-CimInstance {
                $script:clientFilter = $Filter
                @()
            } -ParameterFilter { $ClassName -eq 'SMS_R_System' }
            $providers = Get-SetupCmMecmDefaultProviders

            @(& $providers.ClientProvider @{
                mecm = @{ siteCode = 'LAB' }
                testClient = @{ name = "RING\O'IVY" }
            }) | Should -HaveCount 0

            $script:clientFilter | Should -Be "Name = 'RING\\O\'IVY'"
        }

        It 'maps nullable SQL client columns to conservative defaults without reading DBNull values' {
            $reader = [pscustomobject]@{
                Values = @('RING0IVY24-01', 16777219, $null, $null, $null, $null)
            }
            $reader | Add-Member -MemberType ScriptMethod -Name IsDBNull -Value {
                param($Index)
                $Index -ge 2
            }
            $reader | Add-Member -MemberType ScriptMethod -Name GetValue -Value {
                param($Index)
                if ($this.IsDBNull($Index)) { throw "GetValue called for DBNull index $Index" }
                $this.Values[$Index]
            }

            $row = ConvertFrom-SetupCmMecmClientSqlRow -Reader $reader

            $row.Name | Should -Be 'RING0IVY24-01'
            $row.ResourceId | Should -Be 16777219
            $row.Active | Should -Be 0
            $row.Obsolete | Should -Be 1
            $row.Client | Should -Be 0
            $row.ClientVersion | Should -Be ''
        }
    }
}

Describe 'Repair-SetupCmMecmDesiredState' {
    InModuleScope SetupCm {
        BeforeEach {
            Mock Install-SetupCmMecmVcRedist {}
            Mock Install-SetupCmMecmAdk {}
            Mock Install-SetupCmMecmWinPeAddOn {}
            Mock Install-SetupCmMecmOdbcDriver18 {}
            Mock Set-SetupCmMecmServiceState {}
            Mock Get-SetupCmArtifact { [pscustomobject]@{ Path = 'C:\SetupCm\cache\mecm.iso' } }
            Mock Get-SetupCmMecmPrerequisites { 'C:\SetupCm\Redist' }
            Mock Install-SetupCmPrimarySite {}
        }

        It 'repairs only one missing ADK prerequisite' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @([pscustomobject]@{ Name = 'Adk'; State = 'NotCompliant'; Reason = 'Missing' })
            }
            $config = @{
                cacheRoot = 'C:\SetupCm\cache'; mecm = @{}; sources = @{ adk = @{ name = 'adk' } }
            }

            Repair-SetupCmMecmDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            Should -Invoke Install-SetupCmMecmAdk -Times 1 -Exactly
            Should -Invoke Get-SetupCmArtifact -Times 0 -Exactly
            Should -Invoke Install-SetupCmPrimarySite -Times 0 -Exactly
        }

        It 'validates every required source before applying any prerequisite repair' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{ Name = 'VcRuntimeX64'; State = 'NotCompliant'; Reason = 'Missing' }
                    [pscustomobject]@{ Name = 'VcRuntimeX86'; State = 'NotCompliant'; Reason = 'Missing' }
                )
            }
            $config = @{
                cacheRoot = 'C:\SetupCm\cache'; mecm = @{}
                sources = @{ vcRedistX64 = @{ name = 'vcRedistX64' } }
            }

            { Repair-SetupCmMecmDesiredState -Config $config -State $state -EvidenceRoot $TestDrive } |
                Should -Throw '*sources.vcRedistX86*'
            Should -Invoke Install-SetupCmMecmVcRedist -Times 0 -Exactly
        }

        It 'repairs a missing site with one media acquisition download and setup' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @([pscustomobject]@{ Name = 'MecmSite'; State = 'NotCompliant'; Reason = 'Missing' })
            }
            $config = @{
                cacheRoot = 'C:\SetupCm\cache'
                mecm = @{ prerequisitePath = 'C:\SetupCm\Redist' }
                sources = @{ mecm = @{ name = 'mecm' } }
            }

            Repair-SetupCmMecmDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
            Should -Invoke Get-SetupCmMecmPrerequisites -Times 1 -Exactly
            Should -Invoke Install-SetupCmPrimarySite -Times 1 -Exactly
        }

        It 'installs missing prerequisites before downloading primary-site prerequisites' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{ Name = 'Adk'; State = 'NotCompliant'; Reason = 'Missing' }
                    [pscustomobject]@{ Name = 'MecmSite'; State = 'NotCompliant'; Reason = 'Missing' }
                )
            }
            $config = @{
                cacheRoot = 'C:\SetupCm\cache'
                mecm = @{ prerequisitePath = 'C:\SetupCm\Redist' }
                sources = @{ adk = @{ name = 'adk' }; mecm = @{ name = 'mecm' } }
            }
            $callOrder = [System.Collections.Generic.List[string]]::new()
            Mock Install-SetupCmMecmAdk { [void]$callOrder.Add('adk') }
            Mock Get-SetupCmMecmPrerequisites { [void]$callOrder.Add('prerequisiteDownload') }
            Mock Install-SetupCmPrimarySite { [void]$callOrder.Add('siteSetup') }

            Repair-SetupCmMecmDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            $callOrder | Should -Be @('adk', 'prerequisiteDownload', 'siteSetup')
        }

        It 'does not download MECM prerequisites after a VC runtime requests restart' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{ Name = 'VcRuntimeX64'; State = 'NotCompliant'; Reason = 'Missing' }
                    [pscustomobject]@{ Name = 'MecmSite'; State = 'NotCompliant'; Reason = 'Missing' }
                )
            }
            $config = @{
                cacheRoot = 'C:\SetupCm\cache'
                mecm = @{ prerequisitePath = 'C:\SetupCm\Redist' }
                sources = @{
                    vcRedistX64 = @{ name = 'vcRedistX64' }
                    mecm = @{ name = 'mecm' }
                }
            }
            Mock Install-SetupCmMecmVcRedist {
                throw 'Microsoft Visual C++ Redistributable installation requires a restart before MECM setup can continue (exit code 3010).'
            }

            { Repair-SetupCmMecmDesiredState -Config $config -State $state -EvidenceRoot $TestDrive } |
                Should -Throw '*restart before MECM setup can continue*'
            Should -Invoke Get-SetupCmMecmPrerequisites -Times 0 -Exactly
            Should -Invoke Install-SetupCmPrimarySite -Times 0 -Exactly
        }

        It 'repairs only the named stopped service' {
            $state = [pscustomobject]@{
                State = 'NotCompliant'
                Components = @(
                    [pscustomobject]@{
                        Name = 'MecmServices'; State = 'NotCompliant'; Reason = 'ServiceState'
                        Repair = @('SMS_EXECUTIVE')
                    }
                )
            }
            $config = @{ cacheRoot = 'C:\SetupCm\cache'; mecm = @{}; sources = @{} }

            Repair-SetupCmMecmDesiredState -Config $config -State $state -EvidenceRoot $TestDrive

            Should -Invoke Set-SetupCmMecmServiceState -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'SMS_EXECUTIVE'
            }
            Should -Invoke Install-SetupCmPrimarySite -Times 0 -Exactly
        }

        It 'never repairs a conflicting MECM state' {
            $state = [pscustomobject]@{
                State = 'Conflict'
                Components = @([pscustomobject]@{ Name = 'MecmSite'; State = 'Conflict'; Reason = 'SiteIdentityMismatch' })
            }

            { Repair-SetupCmMecmDesiredState -Config @{ sources = @{}; mecm = @{} } -State $state -EvidenceRoot $TestDrive } |
                Should -Throw '*conflict*'
            Should -Invoke Get-SetupCmArtifact -Times 0 -Exactly
            Should -Invoke Install-SetupCmPrimarySite -Times 0 -Exactly
        }
    }
}

Describe 'Invoke-SetupCm MECM desired-state orchestration' {
    InModuleScope SetupCm {
        BeforeEach {
            $script:mecmProbeCount = 0
            $config = @{
                evidenceRoot = $TestDrive; cacheRoot = 'C:\SetupCm\cache'
                mecm = @{ siteCode = 'LAB'; siteServerFqdn = 'LABZ1-CM01.test.gell.one' }
                sources = @{}
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Repair-SetupCmMecmDesiredState {}
            Mock Get-SetupCmArtifact {}
            Mock Get-SetupCmMecmPrerequisites {}
            Mock Install-SetupCmPrimarySite {}
        }

        It 'skips all media and repair work when the exact site is compliant' {
            Mock Test-SetupCmMecmDesiredState { 'Compliant' }

            $result = Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Mecm

            $result.state | Should -Be 'Skipped'
            Should -Invoke Repair-SetupCmMecmDesiredState -Times 0 -Exactly
            Should -Invoke Get-SetupCmArtifact -Times 0 -Exactly
            Should -Invoke Get-SetupCmMecmPrerequisites -Times 0 -Exactly
            Should -Invoke Install-SetupCmPrimarySite -Times 0 -Exactly
        }

        It 'repairs once and independently verifies MECM compliance' {
            Mock Test-SetupCmMecmDesiredState {
                $script:mecmProbeCount++
                if ($script:mecmProbeCount -eq 1) { 'NotCompliant' } else { 'Compliant' }
            }

            $result = Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Mecm

            $result.state | Should -Be 'Succeeded'
            Should -Invoke Repair-SetupCmMecmDesiredState -Times 1 -Exactly
            Should -Invoke Test-SetupCmMecmDesiredState -Times 2 -Exactly
        }

        It 'never repairs a MECM conflict' {
            Mock Test-SetupCmMecmDesiredState { 'Conflict' }

            { Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Mecm } |
                Should -Throw '*conflict*'
            Should -Invoke Repair-SetupCmMecmDesiredState -Times 0 -Exactly
            Should -Invoke Install-SetupCmPrimarySite -Times 0 -Exactly
        }

        It 'fails after one repair when independent MECM verification still fails' {
            Mock Test-SetupCmMecmDesiredState { 'NotCompliant' }

            { Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Mecm } |
                Should -Throw '*verification failed*'
            Should -Invoke Repair-SetupCmMecmDesiredState -Times 1 -Exactly
        }
    }
}
