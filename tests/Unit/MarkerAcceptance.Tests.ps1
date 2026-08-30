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
                        DetectorHash = '4C09CA514339B9C08277189C61B2DC74908309F0268856A3A4FAFD0CBB41F83C'
                        DetectorLength = 4075
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
                        MarkerLength = 78
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

            function New-TestMarkerEvidenceChannelInventory {
                $administratorsSid = 'S-1-5-32-544'
                $systemSid = 'S-1-5-18'
                $targetSid = 'S-1-5-21-1-2-3-1001'
                $administrativeAces = @(
                    [pscustomobject]@{
                        Sid = $administratorsSid; Rights = 2032127
                        InheritanceFlags = 3; PropagationFlags = 0
                        AccessControlType = 0; IsInherited = $false
                    }
                    [pscustomobject]@{
                        Sid = $systemSid; Rights = 2032127
                        InheritanceFlags = 3; PropagationFlags = 0
                        AccessControlType = 0; IsInherited = $false
                    }
                )
                [pscustomobject]@{
                    TargetComputerSid = $targetSid
                    AdministratorsSid = $administratorsSid
                    SystemSid = $systemSid
                    ProbeError = ''
                    Parent = [pscustomobject]@{
                        Exists = $true; IsDirectory = $true; IsReparsePoint = $false
                        OwnerSid = $administratorsSid; AclProtected = $true
                        Aces = @($administrativeAces)
                    }
                    Target = [pscustomobject]@{
                        Exists = $true; IsDirectory = $true; IsReparsePoint = $false
                        OwnerSid = $administratorsSid; AclProtected = $true
                        Aces = @(
                            $administrativeAces
                            [pscustomobject]@{
                                Sid = $targetSid; Rights = 1179819
                                InheritanceFlags = 0; PropagationFlags = 0
                                AccessControlType = 0; IsInherited = $false
                            }
                            [pscustomobject]@{
                                Sid = $targetSid; Rights = 1245631
                                InheritanceFlags = 1; PropagationFlags = 2
                                AccessControlType = 0; IsInherited = $false
                            }
                        )
                    }
                    Share = [pscustomobject]@{
                        Exists = $true
                        Path = 'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01'
                        Description = 'Setup-CM LabZ1 marker evidence for RING0IVY24-01'
                        CachingMode = 'None'
                        Aces = @(
                            [pscustomobject]@{
                                Sid = $administratorsSid; AccessRight = 'Full'
                                AccessControlType = 0
                            }
                            [pscustomobject]@{
                                Sid = $targetSid; AccessRight = 'Change'
                                AccessControlType = 0
                            }
                        )
                    }
                    Evidence = [pscustomobject]@{
                        Exists = $false; IsDirectory = $false; IsReparsePoint = $false
                        Length = 0L; Bytes = [byte[]]@(); OwnerSid = ''; AclExact = $false
                        Aces = @(); LastWriteTimeUtc = $null; ReadError = ''
                    }
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
                    Detector = @{ Name = 'Test-SetupCmPhase1Marker.vbs'; Length = 4075; Hash = '4C09CA514339B9C08277189C61B2DC74908309F0268856A3A4FAFD0CBB41F83C' }
                }
                $contentSource = @{ Files = @($sourcePayload.Files) }
                $inventory = New-TestMarkerInventory
                $evidenceChannel = New-TestMarkerEvidenceChannelInventory
                @{
                    Boundary = { $boundary }.GetNewClosure()
                    SourcePayload = { $sourcePayload }.GetNewClosure()
                    ContentSource = { $contentSource }.GetNewClosure()
                    EvidenceChannel = { $evidenceChannel }.GetNewClosure()
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
                    'CreateEvidenceChannel', 'UpdateDetectorPolicy', 'SyncContent',
                    'CreateApplication', 'CreateDeploymentType', 'UpdateDeploymentType',
                    'Distribute', 'CreateCollection', 'AddDirectMembership',
                    'RefreshCollection', 'CreateDeployment', 'UpdateDeployment',
                    'RequestClientPolicy', 'WaitForConvergence'
                )
                $providers = @{}
                foreach ($name in $names) {
                    $actionName = $name
                    if ($name -ceq 'RequestClientPolicy') {
                        $providers[$name] = {
                            [void]$Calls.Add($actionName)
                            [datetime]'2026-08-30T12:00:30Z'
                        }.GetNewClosure()
                    }
                    else {
                        $providers[$name] = {
                            [void]$Calls.Add($actionName)
                        }.GetNewClosure()
                    }
                }
                return $providers
            }

            function Get-CimInstance {
                param($Namespace, $ClassName, $Filter, $ErrorAction)
            }
        }

        AfterAll {
            Remove-Item -Path 'function:Get-CimInstance' -ErrorAction SilentlyContinue
        }

        It 'accepts only the exact fixed LabZ1 boundary and one active client identity' {
            $state = Get-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -Providers (New-CompliantMarkerProviders)

            $state.State | Should -BeExactly 'Compliant'
            @($state.Components | Where-Object State -ne 'Compliant') | Should -HaveCount 0
        }

        It 'probes the exact evidence channel once and emits only sanitized details' {
            $providers = New-CompliantMarkerProviders
            $channel = & $providers.EvidenceChannel
            $counter = [pscustomobject]@{ Count = 0 }
            $providers.EvidenceChannel = {
                $counter.Count++
                $channel
            }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers

            $counter.Count | Should -Be 1
            $component = $state.Components | Where-Object Name -eq EvidenceChannel
            $component.State | Should -BeExactly 'Compliant'
            $component.Reason | Should -BeExactly 'Exact'
            $component.ShareName | Should -BeExactly 'SetupCmMarkerEvidence$'
            $component.LocalPath | Should -BeExactly `
                'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01'
            $component.TargetComputerSid | Should -BeExactly `
                'S-1-5-21-1-2-3-1001'
            $component.SchemaVersion | Should -Be 1
            $component.PSObject.Properties.Name | Should -Not -Contain 'Aces'
            ($component | ConvertTo-Json -Depth 8) | Should -Not -Match `
                'Rights|InheritanceFlags|PropagationFlags|AccessControlType'
        }

        It 'accepts exact authenticated client-published evidence as the client proof route' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Client.MarkerHashVerification = 'DirectAuthenticatedClientEvidence'
            $inventory.Client.MarkerLength = 78
            $inventory.Client.EvidenceReceiptTimeUtc = '2026-08-30T12:00:00.0000000Z'
            $inventory.Client.EvidenceOwnerSid = 'S-1-5-21-1-2-3-1001'
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Compliant'
            $client = $state.Components | Where-Object Name -eq Client
            $client.State | Should -BeExactly 'Compliant'
            $client.MarkerHashVerification | Should -BeExactly `
                'DirectAuthenticatedClientEvidence'
            $client.MarkerLength | Should -Be 78
            $client.EvidenceOwnerSid | Should -BeExactly `
                'S-1-5-21-1-2-3-1001'
        }

        It 'keeps missing or stale published evidence pending instead of conflicting' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Client.MarkerHash = ''
            $inventory.Client.MarkerHashVerification = 'ClientEvidencePending'
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'NotCompliant'
            $client = $state.Components | Where-Object Name -eq Client
            $client.State | Should -BeExactly 'NotCompliant'
            $client.Reason | Should -BeExactly 'ClientEvidencePending'
        }

        It 'fails closed on malformed, foreign, or future published evidence' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Client.MarkerHash = ''
            $inventory.Client.MarkerHashVerification = 'EvidenceConflict'
            $inventory.Client.EvidenceReason = 'EvidenceMalformed'
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            $client = $state.Components | Where-Object Name -eq Client
            $client.State | Should -BeExactly 'Conflict'
            $client.Reason | Should -BeExactly 'ClientEvidenceConflict'
            $client.EvidenceReason | Should -BeExactly 'EvidenceMalformed'
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

        It 'classifies only the approved predecessor detector as a bounded upgrade' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.DeploymentTypes[0].DetectorHash = `
                'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
            $inventory.DeploymentTypes[0].DetectorLength = 1310
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'NotCompliant'
            $component = $state.Components | Where-Object Name -eq DeploymentType
            $component.State | Should -BeExactly 'NotCompliant'
            $component.Reason | Should -BeExactly 'ApprovedDetectorUpgrade'
        }

        It 'fails closed when predecessor detector state has another property drift' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.DeploymentTypes[0].DetectorHash = `
                'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
            $inventory.DeploymentTypes[0].DetectorLength = 1310
            $inventory.DeploymentTypes[0].ExecutionContext = 'User'
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            $component = $state.Components | Where-Object Name -eq DeploymentType
            $component.State | Should -BeExactly 'Conflict'
            $component.Reason | Should -BeExactly 'DetectorUpgradeWithPropertyDrift'
        }

        It 'does not approve a predecessor detector with a contradictory length' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.DeploymentTypes[0].DetectorHash = `
                'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
            $inventory.DeploymentTypes[0].DetectorLength = 1309
            $providers.Inventory = { $inventory }.GetNewClosure()

            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers

            $state.State | Should -BeExactly 'Conflict'
            $component = $state.Components | Where-Object Name -eq DeploymentType
            $component.State | Should -BeExactly 'Conflict'
            $component.Reason | Should -BeExactly 'DetectorHashMismatch'
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

        It 'fails closed when both authenticated client proof routes are unavailable' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            # Provider inventory is post-selection; ProbeUnavailable means both routes failed.
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

        It 'performs only the approved first evidence migration sequence' {
            $providers = New-CompliantMarkerProviders
            $channel = & $providers.EvidenceChannel
            $channel.Parent.Exists = $false
            $channel.Target.Exists = $false
            $channel.Share.Exists = $false
            $providers.EvidenceChannel = { $channel }.GetNewClosure()
            $inventory = & $providers.Inventory
            $inventory.DeploymentTypes[0].DetectorHash = `
                'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
            $inventory.DeploymentTypes[0].DetectorLength = 1310
            $providers.Inventory = { $inventory }.GetNewClosure()
            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers
            $calls = [System.Collections.Generic.List[string]]::new()
            $repairProviders = New-RecordingMarkerRepairProviders -Calls $calls
            $capture = [pscustomobject]@{
                MinimumReceiptUtc = $null
                Providers = $null
            }
            $repairProviders.WaitForConvergence = {
                param($Config, $Contract, $MinimumReceiptUtc, $AllProviders)
                [void]$calls.Add('WaitForConvergence')
                $capture.MinimumReceiptUtc = $MinimumReceiptUtc
                $capture.Providers = $AllProviders
            }.GetNewClosure()
            $requestTimestamp = [datetime]'2026-08-30T12:00:30Z'
            $repairProviders.RequestClientPolicy = {
                [void]$calls.Add('RequestClientPolicy')
                $requestTimestamp
            }.GetNewClosure()

            Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) `
                -State $state -Providers $repairProviders

            $calls | Should -BeExactly @(
                'CreateEvidenceChannel',
                'UpdateDetectorPolicy',
                'RequestClientPolicy',
                'WaitForConvergence'
            )
            ([datetime]$capture.MinimumReceiptUtc).ToUniversalTime().ToString('o') |
                Should -BeExactly $requestTimestamp.ToUniversalTime().ToString('o')
            [object]::ReferenceEquals($capture.Providers, $repairProviders) |
                Should -BeTrue
        }

        It 'fails closed when the policy provider does not return its request timestamp' {
            $providers = New-CompliantMarkerProviders
            $inventory = & $providers.Inventory
            $inventory.Client.InstallState = 'NotInstalled'
            $inventory.Client.ResolvedState = 'NotInstalled'
            $inventory.Client.MarkerHash = ''
            $inventory.ServerCompliance = @()
            $providers.Inventory = { $inventory }.GetNewClosure()
            $state = Get-SetupCmMarkerDesiredState `
                -Config (New-TestMarkerConfig) -Providers $providers
            $calls = [System.Collections.Generic.List[string]]::new()
            $repairProviders = New-RecordingMarkerRepairProviders -Calls $calls
            $repairProviders.RequestClientPolicy = {
                [void]$calls.Add('RequestClientPolicy')
            }.GetNewClosure()

            {
                Repair-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) `
                    -State $state -Providers $repairProviders
            } | Should -Throw '*did not return a valid request timestamp*'

            $calls | Should -BeExactly @('RequestClientPolicy')
        }

        It 'uses only detector script parameters for the approved policy upgrade' {
            $providers = Get-SetupCmMarkerDefaultProviders
            $policyText = $providers.UpdateDetectorPolicy.ToString()

            $policyText | Should -Match 'Set-CMScriptDeploymentType'
            $policyText | Should -Match '-ScriptLanguage\s+VBScript'
            $policyText | Should -Match '-ScriptText\s+\$detector'
            $policyText | Should -Match '-Force'
            $policyText | Should -Not -Match `
                'ContentLocation|InstallCommand|UninstallCommand|EstimatedRuntime|MaximumRuntime|InstallationBehavior|LogonRequirement|UserInteraction|RebootBehavior'
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

            $calls | Should -BeExactly @(
                'CreateDeployment',
                'RequestClientPolicy',
                'WaitForConvergence'
            )
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

            $calls | Should -BeExactly @(
                'RequestClientPolicy',
                'WaitForConvergence'
            )
        }

        It 'waits a full settle interval after an assignment-only revision catches up' {
            $contract = Get-SetupCmMarkerFixedContract
            $contract.ClientPolicy.PublicationSettleSeconds = 10
            $contract.ClientPolicy.PublicationTimeoutSeconds = 30
            $contract.ClientPolicy.PollSeconds = 5
            $clock = [pscustomobject]@{
                Now = [datetime]::SpecifyKind(
                    [datetime]'2026-08-30T12:00:00',
                    [System.DateTimeKind]::Utc
                )
            }
            $snapshots = [System.Collections.Generic.Queue[object]]::new()
            $snapshots.Enqueue([pscustomobject]@{
                ApplicationCount = 1
                AssignmentCount = 1
                ApplicationIdentity = 'ScopeId_test/Application_test'
                AssignmentIdentity = '16777217'
                ApplicationRevision = 5
                AssignmentRevision = 4
                ApplicationLastModifiedUtc = $clock.Now
                AssignmentCollectionName = $contract.CollectionName
            })
            $snapshots.Enqueue([pscustomobject]@{
                ApplicationCount = 1
                AssignmentCount = 1
                ApplicationIdentity = 'ScopeId_test/Application_test'
                AssignmentIdentity = '16777217'
                ApplicationRevision = 5
                AssignmentRevision = 5
                ApplicationLastModifiedUtc = $clock.Now
                AssignmentCollectionName = $contract.CollectionName
            })
            $snapshots.Enqueue([pscustomobject]@{
                ApplicationCount = 1
                AssignmentCount = 1
                ApplicationIdentity = 'ScopeId_test/Application_test'
                AssignmentIdentity = '16777217'
                ApplicationRevision = 5
                AssignmentRevision = 5
                ApplicationLastModifiedUtc = $clock.Now
                AssignmentCollectionName = $contract.CollectionName
            })
            $snapshots.Enqueue([pscustomobject]@{
                ApplicationCount = 1
                AssignmentCount = 1
                ApplicationIdentity = 'ScopeId_test/Application_test'
                AssignmentIdentity = '16777217'
                ApplicationRevision = 5
                AssignmentRevision = 5
                ApplicationLastModifiedUtc = $clock.Now
                AssignmentCollectionName = $contract.CollectionName
            })
            $delays = [System.Collections.Generic.List[int]]::new()

            $result = Wait-SetupCmMarkerPolicyPublication -Contract $contract `
                -SnapshotProvider { $snapshots.Dequeue() }.GetNewClosure() `
                -UtcNowProvider { $clock.Now }.GetNewClosure() `
                -DelayProvider {
                    param($Seconds)
                    [void]$delays.Add($Seconds)
                    $clock.Now = $clock.Now.AddSeconds($Seconds)
                }.GetNewClosure()

            $result.ApplicationRevision | Should -Be 5
            $result.AssignmentRevision | Should -Be 5
            $delays | Should -BeExactly @(5, 5, 5)
            $snapshots.Count | Should -Be 0
        }

        It 'fails closed when policy publication observes another assignment scope' {
            $contract = Get-SetupCmMarkerFixedContract

            {
                Wait-SetupCmMarkerPolicyPublication -Contract $contract `
                    -SnapshotProvider {
                        [pscustomobject]@{
                            ApplicationCount = 1
                            AssignmentCount = 1
                            ApplicationRevision = 5
                            AssignmentRevision = 5
                            ApplicationLastModifiedUtc = [datetime]::UtcNow.AddMinutes(-5)
                            AssignmentCollectionName = 'All Systems'
                        }
                    }
            } | Should -Throw '*assignment scope changed*'
        }

        It 'fails closed when a replacement assignment keeps the same revision and scope' {
            $contract = Get-SetupCmMarkerFixedContract
            $now = [datetime]::SpecifyKind(
                [datetime]'2026-08-30T12:00:00',
                [System.DateTimeKind]::Utc
            )
            $snapshots = [System.Collections.Generic.Queue[object]]::new()
            foreach ($assignmentIdentity in '16777217', '16777218') {
                $snapshots.Enqueue([pscustomobject]@{
                    ApplicationCount = 1
                    AssignmentCount = 1
                    ApplicationIdentity = 'ScopeId_test/Application_test'
                    AssignmentIdentity = $assignmentIdentity
                    ApplicationRevision = 5
                    AssignmentRevision = 5
                    ApplicationLastModifiedUtc = $now.AddMinutes(-5)
                    AssignmentCollectionName = $contract.CollectionName
                })
            }
            $snapshotProvider = { $snapshots.Dequeue() }.GetNewClosure()
            $clockProvider = { $now }.GetNewClosure()

            {
                Wait-SetupCmMarkerPolicyPublication -Contract $contract `
                    -SnapshotProvider $snapshotProvider `
                    -UtcNowProvider $clockProvider `
                    -DelayProvider { param($Seconds) }
            } | Should -Throw '*object identity changed*'
            $snapshots.Count | Should -Be 0
        }

        It 'fails closed on policy publication cardinality drift: <Case>' -ForEach @(
            @{ Case = 'missing application'; ApplicationCount = 0; AssignmentCount = 1 }
            @{ Case = 'duplicate application'; ApplicationCount = 2; AssignmentCount = 1 }
            @{ Case = 'missing assignment'; ApplicationCount = 1; AssignmentCount = 0 }
            @{ Case = 'duplicate assignment'; ApplicationCount = 1; AssignmentCount = 2 }
        ) {
            $contract = Get-SetupCmMarkerFixedContract

            {
                Wait-SetupCmMarkerPolicyPublication -Contract $contract `
                    -SnapshotProvider {
                        [pscustomobject]@{
                            ApplicationCount = $ApplicationCount
                            AssignmentCount = $AssignmentCount
                            ApplicationRevision = 5
                            AssignmentRevision = 5
                            ApplicationLastModifiedUtc = [datetime]::UtcNow.AddMinutes(-5)
                            AssignmentCollectionName = $contract.CollectionName
                        }
                    }.GetNewClosure()
            } | Should -Throw '*policy publication identity changed*'
        }

        It 'times policy publication out without sending a notification' {
            $contract = Get-SetupCmMarkerFixedContract
            $contract.ClientPolicy.PublicationSettleSeconds = 10
            $contract.ClientPolicy.PublicationTimeoutSeconds = 10
            $contract.ClientPolicy.PollSeconds = 5
            $clock = [pscustomobject]@{
                Now = [datetime]::SpecifyKind(
                    [datetime]'2026-08-30T12:00:00',
                    [System.DateTimeKind]::Utc
                )
            }
            $delays = [System.Collections.Generic.List[int]]::new()
            $snapshotProvider = {
                [pscustomobject]@{
                    ApplicationCount = 1
                    AssignmentCount = 1
                    ApplicationIdentity = 'ScopeId_test/Application_test'
                    AssignmentIdentity = '16777217'
                    ApplicationRevision = 5
                    AssignmentRevision = 4
                    ApplicationLastModifiedUtc = $clock.Now
                    AssignmentCollectionName = $contract.CollectionName
                }
            }.GetNewClosure()
            $clockProvider = { $clock.Now }.GetNewClosure()
            $delayProvider = {
                param($Seconds)
                [void]$delays.Add($Seconds)
                $clock.Now = $clock.Now.AddSeconds($Seconds)
            }.GetNewClosure()

            {
                Wait-SetupCmMarkerPolicyPublication -Contract $contract `
                    -SnapshotProvider $snapshotProvider `
                    -UtcNowProvider $clockProvider `
                    -DelayProvider $delayProvider
            } | Should -Throw '*policy publication timed out after 10 seconds*'
            $delays | Should -BeExactly @(5, 5)
        }

        It 'bounds every publication snapshot by the remaining overall deadline' {
            $contract = Get-SetupCmMarkerFixedContract
            $contract.ClientPolicy.PublicationSettleSeconds = 10
            $contract.ClientPolicy.PublicationTimeoutSeconds = 10
            $contract.ClientPolicy.PollSeconds = 5
            $clock = [pscustomobject]@{
                Now = [datetime]::SpecifyKind(
                    [datetime]'2026-08-30T12:00:00',
                    [System.DateTimeKind]::Utc
                )
            }
            $snapshotTimeouts = [System.Collections.Generic.List[int]]::new()
            $snapshotProvider = {
                param($TimeoutMilliseconds)
                [void]$snapshotTimeouts.Add($TimeoutMilliseconds)
                [pscustomobject]@{
                    ApplicationCount = 1
                    AssignmentCount = 1
                    ApplicationIdentity = 'ScopeId_test/Application_test'
                    AssignmentIdentity = '16777217'
                    ApplicationRevision = 5
                    AssignmentRevision = 4
                    ApplicationLastModifiedUtc = $clock.Now
                    AssignmentCollectionName = $contract.CollectionName
                }
            }.GetNewClosure()
            $clockProvider = { $clock.Now }.GetNewClosure()
            $delayProvider = {
                param($Seconds)
                $clock.Now = $clock.Now.AddSeconds($Seconds)
            }.GetNewClosure()

            {
                Wait-SetupCmMarkerPolicyPublication -Contract $contract `
                    -SnapshotProvider $snapshotProvider `
                    -UtcNowProvider $clockProvider `
                    -DelayProvider $delayProvider
            } | Should -Throw '*policy publication timed out after 10 seconds*'

            $snapshotTimeouts | Should -BeExactly @(10000, 5000)
        }

        It 'caps one publication snapshot below the overall deadline' {
            $contract = Get-SetupCmMarkerFixedContract
            $snapshotTimeouts = [System.Collections.Generic.List[int]]::new()
            $snapshotProvider = {
                param($TimeoutMilliseconds)
                [void]$snapshotTimeouts.Add($TimeoutMilliseconds)
                throw 'stop after recording the bound'
            }.GetNewClosure()

            {
                Wait-SetupCmMarkerPolicyPublication -Contract $contract `
                    -SnapshotProvider $snapshotProvider
            } | Should -Throw '*stop after recording the bound*'

            $snapshotTimeouts | Should -BeExactly @(90000)
        }

        It 'gets a publication snapshot in an isolated read-only process with the supplied bound' {
            $contract = Get-SetupCmMarkerFixedContract
            $script:decodedMarkerSnapshot = ''
            $script:markerSnapshotTimeout = 0

            $snapshot = Get-SetupCmMarkerPolicyPublicationSnapshot `
                -Contract $contract -TimeoutMilliseconds 4321 `
                -ProcessProvider {
                    param($EncodedCommand, $TimeoutMilliseconds)
                    $script:decodedMarkerSnapshot = [Text.Encoding]::Unicode.GetString(
                        [Convert]::FromBase64String($EncodedCommand)
                    )
                    $script:markerSnapshotTimeout = $TimeoutMilliseconds
                    @'
{"ApplicationCount":1,"AssignmentCount":1,"ApplicationIdentity":"ScopeId_test/Application_test","AssignmentIdentity":"16777217","ApplicationRevision":5,"AssignmentRevision":5,"ApplicationLastModifiedUtc":"2026-08-30T17:35:09Z","AssignmentCollectionName":"Setup-CM Phase 1 Marker - RING0IVY24-01 Only"}
'@
                }

            $snapshot.ApplicationIdentity | Should -BeExactly 'ScopeId_test/Application_test'
            $snapshot.AssignmentIdentity | Should -BeExactly '16777217'
            $snapshot.ApplicationRevision | Should -Be 5
            $snapshot.AssignmentRevision | Should -Be 5
            $script:markerSnapshotTimeout | Should -Be 4321
            $script:decodedMarkerSnapshot | Should -Match 'Get-CMApplication'
            $script:decodedMarkerSnapshot | Should -Match 'Get-CMApplicationDeployment'
            $script:decodedMarkerSnapshot | Should -Match 'Get-CimInstance'
            $script:decodedMarkerSnapshot | Should -Not -Match 'New-CM|Set-CM|Remove-CM|Invoke-CMClientAction'
        }

        It 'fails closed on invalid isolated publication snapshot output' {
            {
                Get-SetupCmMarkerPolicyPublicationSnapshot `
                    -Contract (Get-SetupCmMarkerFixedContract) `
                    -TimeoutMilliseconds 1000 `
                    -ProcessProvider { 'not-json' }
            } | Should -Throw '*invalid output*'
        }

        It 'separates the paired machine-policy and application-evaluation notifications' {
            $contract = Get-SetupCmMarkerFixedContract
            $contract.ClientPolicy.EvaluationSettleSeconds = 30
            $calls = [System.Collections.Generic.List[string]]::new()
            $requestTimestamp = [datetime]'2026-08-30T12:00:30Z'

            $minimumReceiptUtc = Invoke-SetupCmMarkerClientPolicyEvaluation `
                -Contract $contract `
                -MachinePolicyProvider { [void]$calls.Add('MachinePolicy') }.GetNewClosure() `
                -ApplicationEvaluationProvider { [void]$calls.Add('ApplicationEvaluation') }.GetNewClosure() `
                -UtcNowProvider {
                    [void]$calls.Add('RequestTimestamp')
                    $requestTimestamp
                }.GetNewClosure() `
                -DelayProvider {
                    param($Seconds)
                    [void]$calls.Add("Delay:$Seconds")
                }.GetNewClosure()

            $calls | Should -BeExactly @(
                'MachinePolicy',
                'RequestTimestamp',
                'Delay:30',
                'ApplicationEvaluation'
            )
            ([datetime]$minimumReceiptUtc).ToUniversalTime().ToString('o') |
                Should -BeExactly $requestTimestamp.ToUniversalTime().ToString('o')
        }

        It 'routes the live client request through policy-publication and paired-notification guards' {
            $requestText = (Get-SetupCmMarkerDefaultProviders).RequestClientPolicy.ToString()

            $requestText | Should -Match 'Wait-SetupCmMarkerPolicyPublication'
            $requestText | Should -Match 'Get-SetupCmMarkerPolicyPublicationSnapshot'
            $requestText | Should -Match 'Invoke-SetupCmMarkerClientPolicyEvaluation'
        }

        It 'converges from pending to compliant with one 15-second read-only delay' {
            $states = [System.Collections.Generic.Queue[object]]::new()
            $states.Enqueue([pscustomobject]@{
                State = 'NotCompliant'; Components = @()
            })
            $states.Enqueue([pscustomobject]@{
                State = 'Compliant'; Components = @()
            })
            $delays = [System.Collections.Generic.List[int]]::new()

            $result = Wait-SetupCmMarkerConvergence `
                -Config (New-TestMarkerConfig) `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -MinimumEvidenceReceiptUtc ([datetime]'2026-08-30T12:00:00Z') `
                -StateProvider { $states.Dequeue() }.GetNewClosure() `
                -UtcNowProvider { [datetime]'2026-08-30T12:00:00Z' } `
                -DelayProvider { param($Seconds) [void]$delays.Add($Seconds) }.GetNewClosure()

            $result.State | Should -BeExactly 'Compliant'
            $delays | Should -BeExactly @(15)
        }

        It 'stops convergence immediately on conflict without delaying' {
            $delays = [System.Collections.Generic.List[int]]::new()

            {
                Wait-SetupCmMarkerConvergence `
                    -Config (New-TestMarkerConfig) `
                    -Contract (Get-SetupCmMarkerFixedContract) `
                    -MinimumEvidenceReceiptUtc ([datetime]'2026-08-30T12:00:00Z') `
                    -StateProvider {
                        [pscustomobject]@{ State = 'Conflict'; Components = @() }
                    } `
                    -UtcNowProvider { [datetime]'2026-08-30T12:00:00Z' } `
                    -DelayProvider {
                        param($Seconds)
                        [void]$delays.Add($Seconds)
                    }.GetNewClosure()
            } | Should -Throw '*safety conflict*'
            $delays | Should -HaveCount 0
        }

        It 'times convergence out at 900 seconds without another mutation or delay' {
            $timeoutClockState = [pscustomobject]@{ Calls = 0 }
            $timeoutStartTime = [datetime]'2026-08-30T12:00:00Z'
            $probes = [pscustomobject]@{ Count = 0 }
            $delays = [System.Collections.Generic.List[int]]::new()
            $timeoutStateProvider = {
                $probes.Count++
                [pscustomobject]@{
                    State = 'NotCompliant'; Components = @()
                }
            }.GetNewClosure()
            $timeoutUtcNowProvider = {
                $timeoutClockState.Calls++
                if ($timeoutClockState.Calls -eq 1) {
                    $timeoutStartTime
                }
                else {
                    $timeoutStartTime.AddSeconds(900)
                }
            }.GetNewClosure()
            $timeoutDelayProvider = {
                param($Seconds)
                [void]$delays.Add($Seconds)
            }.GetNewClosure()

            {
                Wait-SetupCmMarkerConvergence `
                    -Config (New-TestMarkerConfig) `
                    -Contract (Get-SetupCmMarkerFixedContract) `
                    -MinimumEvidenceReceiptUtc ([datetime]'2026-08-30T12:00:00Z') `
                    -StateProvider $timeoutStateProvider `
                    -UtcNowProvider $timeoutUtcNowProvider `
                    -DelayProvider $timeoutDelayProvider
            } | Should -Throw '*timed out after 900 seconds*'
            $probes.Count | Should -Be 1
            $delays | Should -HaveCount 0
        }

        It 'rejects <CollectionCount> matching collections before deployment update' -ForEach @(
            @{ CollectionCount = 0 }
            @{ CollectionCount = 2 }
        ) {
            $script:matchingCollections = @(
                if ($CollectionCount -gt 0) {
                    1..$CollectionCount | ForEach-Object {
                        [pscustomobject]@{ CollectionID = "LAB0001$_" }
                    }
                }
            )
            Mock Get-CimInstance { $script:matchingCollections }
            Mock Invoke-SetupCmMarkerSiteCommand {
                & $ScriptBlock 'root\SMS\site_LAB'
            }
            $providers = Get-SetupCmMarkerDefaultProviders
            $contract = [pscustomobject]@{
                CollectionName = 'Setup-CM Phase 1 Marker - RING0IVY24-01 Only'
                ApplicationName = 'Setup-CM Phase 1 Marker'
            }

            { & $providers.UpdateDeployment @{ markerAcceptance = @{ siteCode = 'LAB' } } $contract } |
                Should -Throw '*Exactly one bounded marker collection*'
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

        It 'fails closed instead of writing unpinned evidence when run metadata is malformed' {
            $runRoot = Join-Path $TestDrive 'malformed-run'
            New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $runRoot 'run.json'), '{')

            {
                Test-SetupCmMarkerDesiredState -Config (New-TestMarkerConfig) -EvidenceRoot $runRoot `
                    -Providers (New-CompliantMarkerProviders)
            } | Should -Throw
            Test-Path -LiteralPath (Join-Path $runRoot 'marker-state.json') | Should -BeFalse
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
                -ItemProvider {
                    param($Path)
                    @{
                        Length = 78
                        LastWriteTimeUtc = [datetime]::SpecifyKind(
                            [datetime]'2026-08-30T12:00:00',
                            [System.DateTimeKind]::Utc
                        )
                    }
                }

            $script:probedPath | Should -BeExactly `
                '\\RING0IVY24-01.test.gell.one\C$\ProgramData\SetupCm\Phase1\marker.json'
            $state.MarkerHash | Should -BeExactly ('A' * 64)
            $state.MarkerLength | Should -Be 78
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
