Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Setup-CM marker acceptance desired state' {
    InModuleScope SetupCm {
        BeforeAll {
            function New-TestMarkerConfig {
                @{
                    safety = @{ isolatedLab = $true; allowProductionTarget = $false }
                    mecm = @{
                        siteCode = 'LAB'
                        siteServerFqdn = 'LABZ1-CM01.test.gell.one'
                    }
                    testClient = @{ name = 'RING0IVY24-01'; domain = 'test.gell.one'; resourceId = 16777219 }
                    markerAcceptance = @{
                        enabled = $true
                        labOnly = $true
                        siteCode = 'LAB'
                        siteServerFqdn = 'LABZ1-CM01.test.gell.one'
                        targetFqdn = 'RING0IVY24-01.test.gell.one'
                        targetResourceId = 16777219
                    }
                }
            }

            function New-TestMarkerInventory {
                @{
                    Applications = @(@{
                        Name = 'Setup-CM Phase 1 Marker'; CI_ID = 16777528; Revision = 4
                        ModelName = 'ScopeId_test/Application_test'; Enabled = $true
                        Expired = $false; DeploymentTypeCount = 1; Publisher = 'Setup-CM'
                        Version = '1.0.0'
                    })
                    DeploymentTypes = @(@{
                        Name = 'Install Setup-CM Phase 1 Marker'; CI_ID = 16777529
                        Revision = 3; ModelName = 'ScopeId_test/DeploymentType_test'
                        Technology = 'Script'; Enabled = $true
                        ContentId = 'Content_test'; PackageId = 'LAB00008'
                        ContentLocation = '\\LABZ1-CM01.test.gell.one\C$\ProgramData\SetupCm\Phase1MarkerContent\'
                        DetectorHash = 'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
                        DetectionLanguage = 'VBScript'
                        InstallCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-SetupCmPhase1Marker.ps1'
                        UninstallCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall-SetupCmPhase1Marker.ps1'
                        ExecutionContext = 'System'; UserInteractionMode = 'Hidden'; RebootBehavior = 'NoAction'
                    })
                    Distributions = @(@{
                        PackageId = 'LAB00008'; DistributionPoint = 'LABZ1-CM01.test.gell.one'
                        State = 'Success'; Success = 1; Errors = 0; InProgress = 0; Unknown = 0
                    })
                    Collections = @(@{
                        Name = 'Setup-CM Phase 1 Marker - RING0IVY24-01 Only'
                        CollectionId = 'LAB00016'; Type = 2; LimitingCollectionId = 'SMS00001'; MemberCount = 1
                    })
                    DirectRules = @(@{ RuleName = 'RING0IVY24-01'; ResourceId = 16777219 })
                    OtherRules = @()
                    Members = @(@{ Name = 'RING0IVY24-01'; ResourceId = 16777219 })
                    Assignments = @(@{
                        AssignmentId = 16777217; TargetCollectionId = 'LAB00016'
                        Enabled = $true; DesiredConfigType = 1; OfferTypeId = 0
                        NotifyUser = $true; UserUIExperience = $true
                        AssignedRevision = 4; PolicyRevision = '4'
                    })
                    Client = @{
                        Name = 'RING0IVY24-01'; ResourceId = 16777219
                        MarkerHash = '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
                        MarkerHashVerification = 'DirectAuthenticatedFileRead'
                        InstallState = 'Installed'; EvaluationState = 1; ResolvedState = 'Installed'; ExitCode = 0
                        ExecutionContext = 'System'; SelectedDistributionPoint = 'LABZ1-CM01.test.gell.one'
                        ContentDownload = 'Verified'; StateMessages = @('APP_CI_PRESENT')
                    }
                    ServerCompliance = @(@{
                        AssignmentId = 16777217; MachineName = 'RING0IVY24-01'; MachineId = 16777219
                        CollectionId = 'LAB00016'; AppCI = 16777528; DTCI = 16777529
                        ComplianceState = 1; EnforcementState = 1001; InstalledState = 2; Revision = 4
                    })
                }
            }

            function New-CompliantMarkerProviders {
                $boundary = @{
                    HostFqdn = 'LABZ1-CM01.test.gell.one'; SiteCode = 'LAB'
                    SiteServerFqdn = 'LABZ1-CM01.test.gell.one'; ProviderMachine = 'LABZ1-CM01.test.gell.one'
                    ResolvedTargetFqdn = 'RING0IVY24-01.test.gell.one'
                    TargetResources = @(@{
                        Name = 'RING0IVY24-01'; ResourceId = 16777219
                        Active = 1; Obsolete = 0; Client = 1
                    })
                }
                $sourcePayload = @{
                    Files = @(
                        @{ Name = 'Install-SetupCmPhase1Marker.ps1'; Length = 520; Hash = 'AE7580DAFF7B567A647E2849776D8ABC95CA34FA79D61D9D1B8BB0D583B4A920' }
                        @{ Name = 'Test-SetupCmPhase1Marker.ps1'; Length = 523; Hash = 'E6F5BA49569FBEB3571584627DB3AB1B1BA940B4FE5146FB61595BF31A144FD7' }
                        @{ Name = 'Uninstall-SetupCmPhase1Marker.ps1'; Length = 572; Hash = '843D94C3DE2E29DAFD5EE82FADD344722FF5670BDB2F755B84277B12215E08AA' }
                    )
                    Detector = @{ Name = 'Test-SetupCmPhase1Marker.vbs'; Length = 1310; Hash = 'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC' }
                }
                $contentSource = @{ Files = @($sourcePayload.Files) }
                $inventory = New-TestMarkerInventory
                @{
                    Boundary = { $boundary }.GetNewClosure()
                    SourcePayload = { $sourcePayload }.GetNewClosure()
                    ContentSource = { $contentSource }.GetNewClosure()
                    Inventory = { $inventory }.GetNewClosure()
                }
            }

            function New-RecordingMarkerRepairProviders {
                param(
                    [Parameter(Mandatory)]
                    [AllowEmptyCollection()]
                    [System.Collections.Generic.List[string]]$Calls
                )

                $names = @(
                    'SyncContent', 'CreateApplication', 'CreateDeploymentType', 'UpdateDeploymentType',
                    'Distribute', 'CreateCollection', 'AddDirectMembership', 'RefreshCollection',
                    'CreateDeployment', 'UpdateDeployment', 'RequestClientPolicy'
                )
                $providers = @{}
                foreach ($name in $names) {
                    $actionName = $name
                    $providers[$name] = { [void]$Calls.Add($actionName) }.GetNewClosure()
                }
                return $providers
            }
        }

        It 'accepts only the exact fixed LabZ1 boundary and one active client identity' {
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers (New-CompliantMarkerProviders)

            $state.State | Should -BeExactly 'Compliant'
            @($state.Components | Where-Object State -ne 'Compliant') | Should -HaveCount 0
        }

        It 'fails closed when marker acceptance is not explicitly enabled and lab-only' {
            $config = New-TestMarkerConfig
            $config.markerAcceptance.enabled = $false

            $state = Get-SetupCmMarkerDesiredState -Config $config -Providers (New-CompliantMarkerProviders)

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq Boundary).Reason | Should -BeExactly 'MarkerAcceptanceDisabled'
        }

        It 'fails closed when a configured fixed identity is changed' {
            $config = New-TestMarkerConfig
            $config.markerAcceptance.targetResourceId = 42

            $state = Get-SetupCmMarkerDesiredState -Config $config -Providers (New-CompliantMarkerProviders)

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq Boundary).Reason | Should -BeExactly 'ConfigurationBoundaryMismatch'
        }

        It 'fails closed when the live provider host is not the accepted CM01 identity' {
            $providers = New-CompliantMarkerProviders
            $boundary = & $providers.Boundary
            $boundary.HostFqdn = 'OTHER-CM01.test.gell.one'
            $providers.Boundary = { $boundary }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq Boundary).Reason | Should -BeExactly 'LiveBoundaryMismatch'
        }

        It 'fails closed when a reviewed source payload or detector hash changes' {
            $providers = New-CompliantMarkerProviders
            $source = & $providers.SourcePayload
            $source.Detector.Hash = ('0' * 64)
            $providers.SourcePayload = { $source }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq SourcePayload).Reason | Should -BeExactly 'HashMismatch'
        }

        It 'fails closed on duplicate same-name application objects' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Applications = @($inventory.Applications[0], $inventory.Applications[0])
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq Application).Reason | Should -BeExactly 'SameNameConflict'
        }

        It 'fails closed when the embedded deployment-type detector hash drifts' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.DeploymentTypes[0].DetectorHash = ('0' * 64)
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq DeploymentType).Reason | Should -BeExactly 'DetectorHashMismatch'
        }

        It 'fails closed on broad or unexpected collection membership' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.OtherRules = @(@{ Type = 'Query'; RuleName = 'All lab devices' })
            $inventory.Members += @{ Name = 'OTHER-CLIENT'; ResourceId = 42 }
            $inventory.Collections[0].MemberCount = 2
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq Membership).Reason | Should -BeExactly 'BroadOrUnexpectedMembership'
        }

        It 'fails closed when any marker assignment targets another collection' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Assignments += @{
                AssignmentId = 99; TargetCollectionId = 'LAB00099'; Enabled = $true
                DesiredConfigType = 1; OfferTypeId = 0; NotifyUser = $true; UserUIExperience = $true
            }
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq Assignment).Reason | Should -BeExactly 'AssignmentScopeConflict'
        }

        It 'fails closed without mutation when the bounded assignment is disabled' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Assignments[0].Enabled = $false
            $providers.Inventory = { $inventory }.GetNewClosure()
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers
            $calls = [System.Collections.Generic.List[string]]::new()

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq Assignment).Reason |
                Should -BeExactly 'DisabledAssignmentRequiresOperator'
            {
                Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -State $state `
                    -Providers (New-RecordingMarkerRepairProviders -Calls $calls)
            } | Should -Throw '*safety conflict*'
            $calls | Should -HaveCount 0
        }

        It 'does not accept a contract-derived marker hash as direct client evidence' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Client.MarkerHashVerification = 'ExactDetectorAndServerState'
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'NotCompliant'
            ($state.Components | Where-Object Name -eq Client).Reason |
                Should -BeExactly 'ClientNotCompliant'
        }

        It 'fails closed when the direct client marker probe is unavailable' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Client.MarkerHash = ''
            $inventory.Client.MarkerHashVerification = 'ProbeUnavailable'
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            ($state.Components | Where-Object Name -eq Client).Reason |
                Should -BeExactly 'ClientProbeUnavailable'
        }

        It 'reuses an exact deployment without content, membership, assignment, distribution, or policy mutation' {
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers (New-CompliantMarkerProviders)
            $calls = [System.Collections.Generic.List[string]]::new()

            Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -State $state `
                -Providers (New-RecordingMarkerRepairProviders -Calls $calls)

            $calls | Should -HaveCount 0
        }

        It 'repairs only the owned content chain when the managed content source is incomplete' {
            $providers = New-CompliantMarkerProviders
            $content = & $providers.ContentSource
            $content.Files = @($content.Files | Where-Object Name -ne 'Uninstall-SetupCmPhase1Marker.ps1')
            $providers.ContentSource = { $content }.GetNewClosure()
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers
            $calls = [System.Collections.Generic.List[string]]::new()

            Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -State $state `
                -Providers (New-RecordingMarkerRepairProviders -Calls $calls)

            $calls | Should -BeExactly @('SyncContent', 'UpdateDeploymentType', 'Distribute')
        }

        It 'adds only the accepted direct member when an otherwise empty dedicated collection is missing its rule' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.DirectRules = @()
            $inventory.Members = @()
            $inventory.Collections[0].MemberCount = 0
            $providers.Inventory = { $inventory }.GetNewClosure()
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers
            $calls = [System.Collections.Generic.List[string]]::new()

            Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -State $state `
                -Providers (New-RecordingMarkerRepairProviders -Calls $calls)

            $calls | Should -BeExactly @('AddDirectMembership', 'RefreshCollection')
        }

        It 'creates only the missing required assignment when all prerequisite objects are exact' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Assignments = @()
            $inventory.ServerCompliance = @()
            $providers.Inventory = { $inventory }.GetNewClosure()
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers
            $calls = [System.Collections.Generic.List[string]]::new()

            Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -State $state `
                -Providers (New-RecordingMarkerRepairProviders -Calls $calls)

            $calls | Should -BeExactly @('CreateDeployment', 'RequestClientPolicy')
        }

        It 'redistributes only when the accepted package is absent from the single DP' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Distributions = @()
            $providers.Inventory = { $inventory }.GetNewClosure()
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers
            $calls = [System.Collections.Generic.List[string]]::new()

            Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -State $state `
                -Providers (New-RecordingMarkerRepairProviders -Calls $calls)

            $calls | Should -BeExactly @('Distribute')
        }

        It 'requests bounded client policy and application evaluation only when compliance is missing' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Client.InstallState = 'NotInstalled'
            $inventory.Client.ResolvedState = 'NotInstalled'
            $inventory.Client.MarkerHash = ''
            $inventory.ServerCompliance = @()
            $providers.Inventory = { $inventory }.GetNewClosure()
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers $providers
            $calls = [System.Collections.Generic.List[string]]::new()

            Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -State $state `
                -Providers (New-RecordingMarkerRepairProviders -Calls $calls)

            $calls | Should -BeExactly @('RequestClientPolicy')
        }

        It 'writes marker evidence tied to the exact source commit' {
            $commit = '0123456789abcdef0123456789abcdef01234567'
            $runRoot = New-SetupCmRunEvidence -Root $TestDrive -SourceCommit $commit

            Test-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -EvidenceRoot $runRoot `
                -Providers (New-CompliantMarkerProviders) | Should -BeExactly 'Compliant'

            $evidence = Get-Content -LiteralPath (Join-Path $runRoot 'marker-state.json') -Raw |
                ConvertFrom-Json
            $evidence.sourceCommit | Should -BeExactly $commit
            $evidence.state | Should -BeExactly 'Compliant'
            @($evidence.components | Where-Object state -ne 'Compliant') | Should -HaveCount 0
        }
    }
}

Describe 'Setup-CM marker direct client file evidence' {
    InModuleScope SetupCm {
        It 'hashes the fixed client marker through its authenticated admin share' {
            $contract = Get-SetupCmMarkerFixedContract
            $script:probedPath = $null

            $state = Get-SetupCmMarkerDirectClientFileState -Contract $contract `
                -PathProvider {
                    param($Path)
                    $script:probedPath = $Path
                    $true
                } `
                -HashProvider { param($Path) ('a' * 64) } `
                -ItemProvider { param($Path) @{ LastWriteTimeUtc = [datetime]'2026-08-30T12:00:00Z' } }

            $script:probedPath | Should -BeExactly `
                '\\RING0IVY24-01.test.gell.one\C$\ProgramData\SetupCm\Phase1\marker.json'
            $state.MarkerHash | Should -BeExactly ('A' * 64)
            $state.MarkerHashVerification | Should -BeExactly 'DirectAuthenticatedFileRead'
            $state.MarkerLastWriteTime | Should -BeExactly '2026-08-30T12:00:00.0000000Z'
            $state.PSObject.Properties.Name | Should -Not -Contain 'Path'
        }

        It 'distinguishes a missing client marker from an unavailable probe' {
            $contract = Get-SetupCmMarkerFixedContract

            $missing = Get-SetupCmMarkerDirectClientFileState -Contract $contract `
                -PathProvider { $false }
            $unavailable = Get-SetupCmMarkerDirectClientFileState -Contract $contract `
                -PathProvider { throw 'client share unavailable' }

            $missing.MarkerHash | Should -BeNullOrEmpty
            $missing.MarkerHashVerification | Should -BeExactly 'Missing'
            $unavailable.MarkerHash | Should -BeNullOrEmpty
            $unavailable.MarkerHashVerification | Should -BeExactly 'ProbeUnavailable'
        }
    }
}

Describe 'Setup-CM marker acceptance public surface' {
    It 'exports the bounded marker acceptance command' {
        Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

        Get-Command Invoke-SetupCmMarkerAcceptance -Module SetupCm | Should -Not -BeNullOrEmpty
    }

    It 'ships a marker entry point that forwards the selected configuration' {
        $scriptPath = Join-Path $PSScriptRoot '../../scripts/Invoke-SetupCmMarkerAcceptance.ps1'
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)

        $parseErrors | Should -BeNullOrEmpty
        $ast.Extent.Text | Should -Match 'Invoke-SetupCmMarkerAcceptance.*-ConfigPath.*\$ConfigPath'
    }

    InModuleScope SetupCm {
        BeforeEach {
            $script:previousSourceCommit = $env:SETUPCM_SOURCE_COMMIT
            $env:SETUPCM_SOURCE_COMMIT = $null
            $config = @{
                evidenceRoot = $TestDrive
                markerAcceptance = @{ enabled = $true }
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Invoke-SetupCmStage { [pscustomobject]@{ name = 'Marker'; state = 'Skipped' } }
        }

        AfterEach {
            $env:SETUPCM_SOURCE_COMMIT = $script:previousSourceCommit
        }

        It 'refuses standalone marker acceptance without an exact source revision' {
            { Invoke-SetupCmMarkerAcceptance -ConfigPath 'lab.yaml' } |
                Should -Throw '*exact 40-character source commit*'

            Should -Invoke New-SetupCmRunEvidence -Times 0 -Exactly
            Should -Invoke Invoke-SetupCmStage -Times 0 -Exactly
        }

        It 'pins standalone marker evidence to the selected source revision' {
            $commit = '0123456789abcdef0123456789abcdef01234567'

            Invoke-SetupCmMarkerAcceptance -ConfigPath 'lab.yaml' -SourceCommit $commit | Out-Null

            Should -Invoke New-SetupCmRunEvidence -Times 1 -Exactly -ParameterFilter {
                $SourceCommit -eq $commit
            }
        }

        It 'refuses the full Marker stage without an exact source revision' {
            { Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Marker } |
                Should -Throw '*exact 40-character source commit*'

            Should -Invoke New-SetupCmRunEvidence -Times 0 -Exactly
            Should -Invoke Invoke-SetupCmStage -Times 0 -Exactly
        }

        It 'pins full-run Marker evidence to the selected source revision' {
            $commit = '0123456789abcdef0123456789abcdef01234567'

            Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Marker -SourceCommit $commit |
                Out-Null

            Should -Invoke New-SetupCmRunEvidence -Times 1 -Exactly -ParameterFilter {
                $SourceCommit -eq $commit
            }
        }
    }
}
