Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Setup-CM marker evidence fixed contract' {
    InModuleScope SetupCm {
        It 'pins the approved LabZ1 evidence channel and predecessor detector' {
            $contract = Get-SetupCmMarkerFixedContract

            $contract.MarkerLength | Should -Be 78
            $contract.PreviousDetectorFile.Name | Should -BeExactly `
                'Test-SetupCmPhase1Marker.vbs'
            $contract.PreviousDetectorFile.Length | Should -Be 1310
            $contract.PreviousDetectorFile.Hash | Should -BeExactly `
                'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
            $contract.DetectorFile.Name | Should -BeExactly `
                'Test-SetupCmPhase1Marker.vbs'
            $contract.DetectorFile.Length | Should -Be 4075
            $contract.DetectorFile.Hash | Should -BeExactly `
                '4C09CA514339B9C08277189C61B2DC74908309F0268856A3A4FAFD0CBB41F83C'
            $contract.EvidenceChannel.ShareName | Should -BeExactly `
                'SetupCmMarkerEvidence$'
            $contract.EvidenceChannel.ShareDescription | Should -BeExactly `
                'Setup-CM LabZ1 marker evidence for RING0IVY24-01'
            $contract.EvidenceChannel.LocalParent | Should -BeExactly `
                'C:\ProgramData\SetupCm\MarkerEvidence'
            $contract.EvidenceChannel.LocalPath | Should -BeExactly `
                'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01'
            $contract.EvidenceChannel.FileName | Should -BeExactly `
                'marker-evidence.json'
            $contract.EvidenceChannel.UncPath | Should -BeExactly `
                '\\LABZ1-CM01.test.gell.one\SetupCmMarkerEvidence$\marker-evidence.json'
            $contract.EvidenceChannel.ComputerAccount | Should -BeExactly `
                'TEST\RING0IVY24-01$'
            $contract.EvidenceChannel.SchemaVersion | Should -Be 1
            $contract.EvidenceChannel.VerificationMethod | Should -BeExactly `
                'CertUtilSha256Exact'
            $contract.EvidenceChannel.MaximumBytes | Should -Be 2048
            $contract.EvidenceChannel.FreshnessMinutes | Should -Be 30
            $contract.EvidenceChannel.FutureToleranceMinutes | Should -Be 2
            $contract.EvidenceChannel.PollSeconds | Should -Be 15
            $contract.EvidenceChannel.ConvergenceSeconds | Should -Be 900
            $contract.ClientPolicy.PublicationSettleSeconds | Should -Be 60
            $contract.ClientPolicy.PublicationTimeoutSeconds | Should -Be 300
            $contract.ClientPolicy.PublicationSnapshotTimeoutSeconds | Should -Be 90
            $contract.ClientPolicy.PollSeconds | Should -Be 5
            $contract.ClientPolicy.EvaluationSettleSeconds | Should -Be 30
        }
    }
}

Describe 'Setup-CM marker evidence channel desired state' {
    InModuleScope SetupCm {
        BeforeAll {
            function New-TestMarkerNtfsAce {
                param(
                    [Parameter(Mandatory)][string]$Sid,
                    [Parameter(Mandatory)][int]$Rights,
                    [Parameter(Mandatory)][int]$InheritanceFlags,
                    [Parameter(Mandatory)][int]$PropagationFlags,
                    [int]$AccessControlType = 0,
                    [bool]$IsInherited = $false
                )

                [pscustomobject][ordered]@{
                    Sid = $Sid
                    Rights = $Rights
                    InheritanceFlags = $InheritanceFlags
                    PropagationFlags = $PropagationFlags
                    AccessControlType = $AccessControlType
                    IsInherited = $IsInherited
                }
            }

            function New-TestMarkerShareAce {
                param(
                    [Parameter(Mandatory)][string]$Sid,
                    [Parameter(Mandatory)][ValidateSet('Full', 'Change', 'Read')]
                    [string]$AccessRight,
                    [int]$AccessControlType = 0
                )

                [pscustomobject][ordered]@{
                    Sid = $Sid
                    AccessRight = $AccessRight
                    AccessControlType = $AccessControlType
                }
            }

            function New-TestMarkerEvidenceChannelInventory {
                param(
                    [bool]$ParentExists = $true,
                    [bool]$TargetExists = $true,
                    [bool]$ShareExists = $true,
                    [bool]$EvidenceExists = $false,
                    [switch]$UseApprovedPredecessorTargetAcl
                )

                $administratorsSid = 'S-1-5-32-544'
                $systemSid = 'S-1-5-18'
                $targetSid = 'S-1-5-21-1-2-3-1001'
                $administrativeAces = @(
                    New-TestMarkerNtfsAce -Sid $administratorsSid -Rights 2032127 `
                        -InheritanceFlags 3 -PropagationFlags 0
                    New-TestMarkerNtfsAce -Sid $systemSid -Rights 2032127 `
                        -InheritanceFlags 3 -PropagationFlags 0
                )

                [pscustomobject][ordered]@{
                    TargetComputerSid = $targetSid
                    AdministratorsSid = $administratorsSid
                    SystemSid = $systemSid
                    ProbeError = ''
                    Parent = [pscustomobject][ordered]@{
                        Exists = $ParentExists
                        IsDirectory = $true
                        IsReparsePoint = $false
                        OwnerSid = $administratorsSid
                        AclProtected = $true
                        Aces = @($administrativeAces)
                    }
                    Target = [pscustomobject][ordered]@{
                        Exists = $TargetExists
                        IsDirectory = $true
                        IsReparsePoint = $false
                        OwnerSid = $administratorsSid
                        AclProtected = $true
                        Aces = @(
                            $administrativeAces
                            New-TestMarkerNtfsAce -Sid $targetSid -Rights 1179819 `
                                -InheritanceFlags 0 -PropagationFlags 0
                            New-TestMarkerNtfsAce -Sid $targetSid -Rights 1245631 `
                                -InheritanceFlags $(if ($UseApprovedPredecessorTargetAcl) { 1 } else { 2 }) `
                                -PropagationFlags 2
                        )
                    }
                    Share = [pscustomobject][ordered]@{
                        Exists = $ShareExists
                        Path = 'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01'
                        Description = 'Setup-CM LabZ1 marker evidence for RING0IVY24-01'
                        CachingMode = 'None'
                        Aces = @(
                            New-TestMarkerShareAce -Sid $administratorsSid -AccessRight Full
                            New-TestMarkerShareAce -Sid $targetSid -AccessRight Change
                        )
                    }
                    Evidence = [pscustomobject][ordered]@{
                        Exists = $EvidenceExists
                        IsDirectory = $false
                        IsReparsePoint = $false
                        OwnerSid = if ($EvidenceExists) { $targetSid } else { '' }
                        AclExact = $true
                    }
                }
            }
        }

        It 'accepts the exact protected channel even when the evidence file is absent' {
            $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory (New-TestMarkerEvidenceChannelInventory)

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
        }

        It 'classifies a fully absent channel as missing' {
            $inventory = New-TestMarkerEvidenceChannelInventory `
                -ParentExists $false -TargetExists $false -ShareExists $false

            $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) -Inventory $inventory

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'Missing'
        }

        It 'classifies an exact protected administrative subset as safely incomplete' {
            $inventory = New-TestMarkerEvidenceChannelInventory `
                -TargetExists $false -ShareExists $false

            $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) -Inventory $inventory

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'IncompleteOwnedChannel'
        }

        It 'classifies only the container-inherit predecessor as a bounded file-ACL upgrade' {
            $inventory = New-TestMarkerEvidenceChannelInventory `
                -UseApprovedPredecessorTargetAcl

            $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) -Inventory $inventory

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly `
                'ApprovedTargetFileInheritanceUpgrade'
        }

        It 'keeps the predecessor plus a missing share in the safe-partial state' {
            $inventory = New-TestMarkerEvidenceChannelInventory `
                -ShareExists $false -UseApprovedPredecessorTargetAcl

            $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) -Inventory $inventory

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'IncompleteOwnedChannel'
        }

        It 'fails closed when the existing share points at another path' {
            $inventory = New-TestMarkerEvidenceChannelInventory
            $inventory.Share.Path = 'C:\Other\MarkerEvidence'

            $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) -Inventory $inventory

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'SharePathConflict'
        }

        It 'fails closed on an unsafe ACL shape: <Name>' -ForEach @(
            @{ Name = 'inherited ACE'; Mutation = 'Inherited' }
            @{ Name = 'deny ACE'; Mutation = 'Deny' }
            @{ Name = 'broad trustee'; Mutation = 'Broad' }
            @{ Name = 'unknown trustee'; Mutation = 'Unknown' }
            @{ Name = 'duplicate ACE'; Mutation = 'Duplicate' }
            @{ Name = 'excessive rights'; Mutation = 'Excessive' }
            @{ Name = 'unapproved inheritance flags'; Mutation = 'WrongInheritance' }
        ) {
            $inventory = New-TestMarkerEvidenceChannelInventory
            switch ($Mutation) {
                'Inherited' { $inventory.Parent.Aces[0].IsInherited = $true }
                'Deny' { $inventory.Target.Aces[2].AccessControlType = 1 }
                'Broad' {
                    $inventory.Share.Aces += New-TestMarkerShareAce `
                        -Sid 'S-1-1-0' -AccessRight Change
                }
                'Unknown' {
                    $inventory.Parent.Aces += New-TestMarkerNtfsAce `
                        -Sid 'S-1-5-21-9-9-9-9999' -Rights 1 `
                        -InheritanceFlags 0 -PropagationFlags 0
                }
                'Duplicate' { $inventory.Target.Aces += $inventory.Target.Aces[2].PSObject.Copy() }
                'Excessive' { $inventory.Target.Aces[2].Rights = 2032127 }
                'WrongInheritance' { $inventory.Target.Aces[3].InheritanceFlags = 3 }
            }

            $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) -Inventory $inventory

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceAclConflict'
        }

        It 'fails closed on evidence-channel identity drift: <Name>' -ForEach @(
            @{ Name = 'wrong parent owner'; Mutation = 'ParentOwner' }
            @{ Name = 'wrong target owner'; Mutation = 'TargetOwner' }
            @{ Name = 'unresolved target SID'; Mutation = 'UnresolvedTarget' }
            @{ Name = 'parent reparse point'; Mutation = 'ParentReparse' }
            @{ Name = 'target reparse point'; Mutation = 'TargetReparse' }
            @{ Name = 'evidence reparse point'; Mutation = 'EvidenceReparse' }
        ) {
            $inventory = New-TestMarkerEvidenceChannelInventory
            switch ($Mutation) {
                'ParentOwner' { $inventory.Parent.OwnerSid = 'S-1-5-21-9-9-9-9999' }
                'TargetOwner' { $inventory.Target.OwnerSid = 'S-1-5-21-9-9-9-9999' }
                'UnresolvedTarget' { $inventory.TargetComputerSid = '' }
                'ParentReparse' { $inventory.Parent.IsReparsePoint = $true }
                'TargetReparse' { $inventory.Target.IsReparsePoint = $true }
                'EvidenceReparse' {
                    $inventory.Evidence.Exists = $true
                    $inventory.Evidence.OwnerSid = $inventory.TargetComputerSid
                    $inventory.Evidence.IsReparsePoint = $true
                }
            }

            $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) -Inventory $inventory

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceIdentityConflict'
        }
    }
}

Describe 'Setup-CM marker evidence channel inventory' {
    InModuleScope SetupCm {
        BeforeAll {
            if (-not (Get-Command Resolve-SetupCmMarkerSid -ErrorAction SilentlyContinue)) {
                function Resolve-SetupCmMarkerSid { param([string]$AccountName) }
            }
            if (-not (Get-Command Get-SetupCmMarkerDirectoryInventory `
                    -ErrorAction SilentlyContinue)) {
                function Get-SetupCmMarkerDirectoryInventory { param([string]$Path) }
            }
            if (-not (Get-Command Get-SetupCmMarkerEvidenceFileInventory `
                    -ErrorAction SilentlyContinue)) {
                function Get-SetupCmMarkerEvidenceFileInventory {
                    param([string]$Path, [string]$TargetComputerSid, [int]$MaximumBytes)
                }
            }
            if (-not (Get-Command Get-SetupCmMarkerShareInventory `
                    -ErrorAction SilentlyContinue)) {
                function Get-SetupCmMarkerShareInventory {
                    param([string]$Name)
                }
            }
        }

        BeforeEach {
            $script:parentInventory = [pscustomobject]@{ Exists = $true; Label = 'Parent' }
            $script:targetInventory = [pscustomobject]@{ Exists = $true; Label = 'Target' }
            $script:evidenceInventory = [pscustomobject]@{ Exists = $false; Label = 'Evidence' }
            $script:shareInventory = [pscustomobject]@{ Exists = $true; Label = 'Share' }
            Mock Resolve-SetupCmMarkerSid { 'S-1-5-21-1-2-3-1001' }
            Mock Get-SetupCmMarkerDirectoryInventory {
                if ($Path -eq 'C:\ProgramData\SetupCm\MarkerEvidence') {
                    return $script:parentInventory
                }
                $script:targetInventory
            }
            Mock Get-SetupCmMarkerEvidenceFileInventory { $script:evidenceInventory }
            Mock Get-SetupCmMarkerShareInventory { $script:shareInventory }
        }

        It 'assembles normalized inventory from only the fixed channel paths and identity' {
            $contract = Get-SetupCmMarkerFixedContract

            $inventory = Get-SetupCmMarkerEvidenceChannelInventory -Contract $contract

            $inventory.TargetComputerSid | Should -BeExactly 'S-1-5-21-1-2-3-1001'
            $inventory.AdministratorsSid | Should -BeExactly 'S-1-5-32-544'
            $inventory.SystemSid | Should -BeExactly 'S-1-5-18'
            $inventory.ProbeError | Should -BeNullOrEmpty
            $inventory.Parent.Label | Should -BeExactly 'Parent'
            $inventory.Target.Label | Should -BeExactly 'Target'
            $inventory.Share.Label | Should -BeExactly 'Share'
            $inventory.Evidence.Label | Should -BeExactly 'Evidence'
            Should -Invoke Resolve-SetupCmMarkerSid -Times 1 -Exactly -ParameterFilter {
                $AccountName -eq 'TEST\RING0IVY24-01$'
            }
            Should -Invoke Get-SetupCmMarkerDirectoryInventory -Times 1 -Exactly `
                -ParameterFilter { $Path -eq 'C:\ProgramData\SetupCm\MarkerEvidence' }
            Should -Invoke Get-SetupCmMarkerDirectoryInventory -Times 1 -Exactly `
                -ParameterFilter {
                    $Path -eq 'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01'
                }
            Should -Invoke Get-SetupCmMarkerEvidenceFileInventory -Times 1 -Exactly `
                -ParameterFilter {
                    $Path -eq 'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01\marker-evidence.json' -and
                    $TargetComputerSid -eq 'S-1-5-21-1-2-3-1001' -and
                    $MaximumBytes -eq 2048
                }
            Should -Invoke Get-SetupCmMarkerShareInventory -Times 1 -Exactly `
                -ParameterFilter { $Name -eq 'SetupCmMarkerEvidence$' }
        }

        It 'bounds identity resolution failures without returning the exception text' {
            Mock Resolve-SetupCmMarkerSid { throw 'private directory and domain details' }

            $inventory = Get-SetupCmMarkerEvidenceChannelInventory `
                -Contract (Get-SetupCmMarkerFixedContract)

            $inventory.TargetComputerSid | Should -BeNullOrEmpty
            $inventory.ProbeError | Should -BeExactly 'InventoryUnavailable'
            ($inventory | ConvertTo-Json -Depth 8) | Should -Not -Match 'private directory'
            Should -Invoke Get-SetupCmMarkerDirectoryInventory -Times 0 -Exactly
            Should -Invoke Get-SetupCmMarkerShareInventory -Times 0 -Exactly
        }
    }
}

Describe 'Setup-CM marker evidence channel creation provider' {
    InModuleScope SetupCm {
        BeforeAll {
            function New-TestMarkerNtfsAce {
                param(
                    [Parameter(Mandatory)][string]$Sid,
                    [Parameter(Mandatory)][int]$Rights,
                    [Parameter(Mandatory)][int]$InheritanceFlags,
                    [Parameter(Mandatory)][int]$PropagationFlags,
                    [int]$AccessControlType = 0,
                    [bool]$IsInherited = $false
                )

                [pscustomobject][ordered]@{
                    Sid = $Sid
                    Rights = $Rights
                    InheritanceFlags = $InheritanceFlags
                    PropagationFlags = $PropagationFlags
                    AccessControlType = $AccessControlType
                    IsInherited = $IsInherited
                }
            }

            if (-not (Get-Command Get-SetupCmMarkerDirectorySecurity `
                    -ErrorAction SilentlyContinue)) {
                function Get-SetupCmMarkerDirectorySecurity {
                    param([string]$Role, [string]$TargetComputerSid)
                }
            }
            if (-not (Get-Command Set-Acl -ErrorAction SilentlyContinue)) {
                function Set-Acl {
                    [CmdletBinding()]
                    param([string]$LiteralPath, $AclObject)
                }
            }
            if (-not (Get-Command New-SmbShare -ErrorAction SilentlyContinue)) {
                function New-SmbShare {
                    param(
                        [string]$Name,
                        [string]$Path,
                        [string]$Description,
                        [string]$CachingMode,
                        [string]$FullAccess,
                        [string]$ChangeAccess,
                        [string]$ErrorAction
                    )
                }
            }
        }

        BeforeEach {
            $script:sequence = [System.Collections.Generic.List[string]]::new()
            $script:inventoryCalls = 0
            $script:initialState = 'NotCompliant'
            $script:initialReason = 'Missing'
            $script:initialInventory = [pscustomobject]@{
                Tag = 'Initial'
                TargetComputerSid = 'S-1-5-21-1-2-3-1001'
                Parent = [pscustomobject]@{ Exists = $false }
                Target = [pscustomobject]@{ Exists = $false }
                Share = [pscustomobject]@{ Exists = $false }
            }
            $script:finalInventory = [pscustomobject]@{ Tag = 'Final' }

            Mock Get-SetupCmMarkerEvidenceChannelInventory {
                $script:inventoryCalls++
                if ($script:inventoryCalls -eq 1) { return $script:initialInventory }
                $script:finalInventory
            }
            Mock Get-SetupCmMarkerEvidenceChannelAssessment {
                if ($Inventory.Tag -eq 'Final') {
                    return [pscustomobject]@{ State = 'Compliant'; Reason = 'Exact' }
                }
                [pscustomobject]@{
                    State = $script:initialState
                    Reason = $script:initialReason
                }
            }
            Mock New-Item {
                [void]$script:sequence.Add("New:$Path")
                [pscustomobject]@{ FullName = $Path }
            }
            Mock Get-SetupCmMarkerDirectorySecurity {
                [void]$script:sequence.Add("Build:$Role")
                [pscustomobject]@{
                    Role = $Role
                    TargetComputerSid = $TargetComputerSid
                }
            }
            Mock Set-Acl {
                $scope = if ($LiteralPath -like '*RING0IVY24-01') { 'Target' } else { 'Parent' }
                [void]$script:sequence.Add("Set:$scope")
            }
            Mock New-SmbShare {
                [void]$script:sequence.Add('Share')
                [pscustomobject]@{ Name = $Name }
            }
            Mock Remove-Item {}
        }

        It 'creates the parent ACL, target ACL, and exact hidden share in order' {
            $result = New-SetupCmMarkerEvidenceChannel `
                -Contract (Get-SetupCmMarkerFixedContract)

            $expectedSequence =
                'New:C:\ProgramData\SetupCm\MarkerEvidence|Build:Parent|Set:Parent|' +
                'New:C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01|' +
                'Build:Target|Set:Target|Share'
            $result.Changed | Should -BeTrue
            $result.State | Should -BeExactly 'Compliant'
            ($script:sequence -join '|') | Should -BeExactly $expectedSequence
            Should -Invoke Get-SetupCmMarkerDirectorySecurity -Times 2 -Exactly `
                -ParameterFilter {
                    $TargetComputerSid -eq 'S-1-5-21-1-2-3-1001' -and
                    $Role -in 'Parent', 'Target'
                }
            Should -Invoke New-SmbShare -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'SetupCmMarkerEvidence$' -and
                $Path -eq 'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01' -and
                $Description -eq 'Setup-CM LabZ1 marker evidence for RING0IVY24-01' -and
                $CachingMode -eq 'None' -and
                $FullAccess -eq 'BUILTIN\Administrators' -and
                $ChangeAccess -eq 'TEST\RING0IVY24-01$' -and
                $FullAccess -notin 'Everyone', 'Authenticated Users', 'Domain Computers' -and
                $ChangeAccess -notin 'Everyone', 'Authenticated Users', 'Domain Computers'
            }
            Should -Invoke Get-SetupCmMarkerEvidenceChannelInventory -Times 2 -Exactly
        }

        It 'does not mutate an already compliant channel' {
            $script:initialState = 'Compliant'
            $script:initialReason = 'Exact'

            $result = New-SetupCmMarkerEvidenceChannel `
                -Contract (Get-SetupCmMarkerFixedContract)

            $result.Changed | Should -BeFalse
            $result.State | Should -BeExactly 'Compliant'
            Should -Invoke New-Item -Times 0 -Exactly
            Should -Invoke Set-Acl -Times 0 -Exactly
            Should -Invoke New-SmbShare -Times 0 -Exactly
            Should -Invoke Get-SetupCmMarkerEvidenceChannelInventory -Times 1 -Exactly
        }

        It 'normalizes only the approved target file-inheritance predecessor' {
            $script:initialState = 'NotCompliant'
            $script:initialReason = 'ApprovedTargetFileInheritanceUpgrade'
            $script:initialInventory.Parent.Exists = $true
            $script:initialInventory.Target.Exists = $true
            $script:initialInventory.Share.Exists = $true

            $result = New-SetupCmMarkerEvidenceChannel `
                -Contract (Get-SetupCmMarkerFixedContract)

            $result.Changed | Should -BeTrue
            $result.State | Should -BeExactly 'Compliant'
            $result.Actions | Should -BeExactly @('NormalizeTargetFileInheritance')
            ($script:sequence -join '|') | Should -BeExactly 'Build:Target|Set:Target'
            Should -Invoke New-Item -Times 0 -Exactly
            Should -Invoke New-SmbShare -Times 0 -Exactly
            Should -Invoke Get-SetupCmMarkerEvidenceChannelInventory -Times 2 -Exactly
        }

        It 'completes a missing share while normalizing the approved predecessor' {
            $script:initialReason = 'IncompleteOwnedChannel'
            Add-Member -InputObject $script:initialInventory `
                -MemberType NoteProperty -Name AdministratorsSid `
                -Value 'S-1-5-32-544'
            Add-Member -InputObject $script:initialInventory `
                -MemberType NoteProperty -Name SystemSid -Value 'S-1-5-18'
            $script:initialInventory.Parent.Exists = $true
            $script:initialInventory.Target = [pscustomobject]@{
                Exists = $true
                Aces = @(
                    New-TestMarkerNtfsAce -Sid 'S-1-5-32-544' -Rights 2032127 `
                        -InheritanceFlags 3 -PropagationFlags 0
                    New-TestMarkerNtfsAce -Sid 'S-1-5-18' -Rights 2032127 `
                        -InheritanceFlags 3 -PropagationFlags 0
                    New-TestMarkerNtfsAce -Sid 'S-1-5-21-1-2-3-1001' `
                        -Rights 1179819 -InheritanceFlags 0 -PropagationFlags 0
                    New-TestMarkerNtfsAce -Sid 'S-1-5-21-1-2-3-1001' `
                        -Rights 1245631 -InheritanceFlags 1 -PropagationFlags 2
                )
            }
            $script:initialInventory.Share.Exists = $false

            $result = New-SetupCmMarkerEvidenceChannel `
                -Contract (Get-SetupCmMarkerFixedContract)

            $result.Changed | Should -BeTrue
            $result.Actions | Should -BeExactly @(
                'NormalizeTargetFileInheritance',
                'CreateBoundedShare'
            )
            ($script:sequence -join '|') |
                Should -BeExactly 'Build:Target|Set:Target|Share'
            Should -Invoke New-Item -Times 0 -Exactly
        }

        It 'refuses a conflicting channel without mutation' {
            $script:initialState = 'Conflict'
            $script:initialReason = 'EvidenceAclConflict'

            { New-SetupCmMarkerEvidenceChannel `
                    -Contract (Get-SetupCmMarkerFixedContract) } |
                Should -Throw '*EvidenceAclConflict*'

            Should -Invoke New-Item -Times 0 -Exactly
            Should -Invoke Set-Acl -Times 0 -Exactly
            Should -Invoke New-SmbShare -Times 0 -Exactly
        }

        It 'leaves a failed safe partial in place without creating a share or deleting paths' {
            Mock Set-Acl {
                $scope = if ($LiteralPath -like '*RING0IVY24-01') { 'Target' } else { 'Parent' }
                [void]$script:sequence.Add("Set:$scope")
                if ($scope -eq 'Target') { throw 'injected target ACL failure' }
            }

            { New-SetupCmMarkerEvidenceChannel `
                    -Contract (Get-SetupCmMarkerFixedContract) } |
                Should -Throw '*injected target ACL failure*'

            Should -Invoke New-SmbShare -Times 0 -Exactly
            Should -Invoke Remove-Item -Times 0 -Exactly
            ($script:sequence -join '|') | Should -Not -Match 'Everyone|Authenticated|Domain Computers'
        }
    }
}

Describe 'Setup-CM marker published evidence parser' {
    InModuleScope SetupCm {
        BeforeAll {
            $script:exactEvidenceJson = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
        }

        It 'parses the exact six-field marker evidence record without coercion' {
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($script:exactEvidenceJson)

            $record = ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes

            $record.PSObject.Properties.Name | Should -BeExactly @(
                'schemaVersion',
                'computerName',
                'markerPath',
                'markerSha256',
                'markerLength',
                'verificationMethod'
            )
            $record.schemaVersion | Should -BeOfType ([int])
            $record.schemaVersion | Should -Be 1
            $record.computerName | Should -BeExactly 'RING0IVY24-01'
            $record.markerPath | Should -BeExactly 'C:\ProgramData\SetupCm\Phase1\marker.json'
            $record.markerSha256 | Should -BeExactly `
                '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
            $record.markerLength | Should -BeOfType ([long])
            $record.markerLength | Should -Be 78
            $record.verificationMethod | Should -BeExactly 'CertUtilSha256Exact'
        }

        It 'rejects an unknown property instead of ignoring it' {
            $json = $script:exactEvidenceJson.Substring(0, $script:exactEvidenceJson.Length - 1) +
                ',"extra":"unexpected"}'
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw '*properties are not exact*'
        }

        It 'rejects a duplicate property even when the property count is six' {
            $json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78}'
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw '*properties are not exact*'
        }

        It 'rejects a record larger than 2,048 bytes before parsing it' {
            $encoding = [System.Text.UTF8Encoding]::new($false)
            $exactBytes = $encoding.GetBytes($script:exactEvidenceJson)
            $oversizedJson = $script:exactEvidenceJson + (' ' * (2049 - $exactBytes.Count))
            $bytes = $encoding.GetBytes($oversizedJson)

            $bytes.Count | Should -Be 2049
            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw '*2,048-byte limit*'
        }

        It 'rejects non-ASCII JSON even when its UTF-8 encoding is valid' {
            $nonAscii = [char]0x00E9
            $json = $script:exactEvidenceJson.Replace(
                'RING0IVY24-01', "RING0IVY24-01$nonAscii")
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw '*ASCII-compatible*'
        }

        It 'rejects invalid UTF-8 bytes' {
            $bytes = [byte[]](0x7b, 0x22, 0x78, 0x22, 0x3a, 0xc3, 0x28, 0x7d)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw
        }

        It 'rejects a non-exact JSON envelope: <Name>' -ForEach @(
            @{ Name = 'empty bytes'; Json = '' }
            @{ Name = 'array root'; Json = '[]' }
            @{
                Name = 'missing property'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78}'
            }
            @{
                Name = 'string schema version'
                Json = '{"schemaVersion":"1","computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'fractional marker length'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78.5,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'null computer name'
                Json = '{"schemaVersion":1,"computerName":null,"markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'comment'
                Json = '{/*comment*/"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'trailing comma'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact",}'
            }
            @{
                Name = 'trailing non-whitespace'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}x'
            }
        ) {
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Json)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } | Should -Throw
        }
    }
}

Describe 'Setup-CM marker published evidence assessment' {
    InModuleScope SetupCm {
        BeforeAll {
            function New-TestPublishedEvidenceInventory {
                param(
                    [string]$Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}',
                    [string]$TargetComputerSid = 'S-1-5-21-1-2-3-1001',
                    [string]$OwnerSid = 'S-1-5-21-1-2-3-1001',
                    [datetime]$LastWriteTimeUtc = [datetime]'2026-08-30T12:00:00Z',
                    [bool]$Exists = $true,
                    [bool]$IsReparsePoint = $false,
                    [bool]$AclExact = $true,
                    [string]$ReadError = '',
                    [Nullable[long]]$Length
                )

                $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Json)
                [pscustomobject]@{
                    TargetComputerSid = $TargetComputerSid
                    Evidence = [pscustomobject]@{
                        Exists = $Exists
                        IsReparsePoint = $IsReparsePoint
                        Length = if ($null -eq $Length) { [long]$bytes.Count } else { [long]$Length }
                        Bytes = $bytes
                        OwnerSid = $OwnerSid
                        AclExact = $AclExact
                        LastWriteTimeUtc = $LastWriteTimeUtc
                        ReadError = $ReadError
                    }
                }
            }
        }

        It 'accepts exact client-owned evidence received within the freshness window' {
            $inventory = New-TestPublishedEvidenceInventory

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
            $assessment.MarkerHash | Should -BeExactly `
                '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
            $assessment.MarkerLength | Should -Be 78
            $assessment.MarkerHashVerification | Should -BeExactly `
                'DirectAuthenticatedClientEvidence'
            $assessment.ReceiptTimeUtc.ToUniversalTime().ToString('o') | Should -BeExactly `
                '2026-08-30T12:00:00.0000000Z'
            $assessment.OwnerSid | Should -BeExactly 'S-1-5-21-1-2-3-1001'
        }

        It 'classifies a missing final record as pending evidence' {
            $inventory = New-TestPublishedEvidenceInventory -Exists $false

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'ClientEvidencePending'
            $assessment.MarkerHash | Should -BeNullOrEmpty
            $assessment.MarkerHashVerification | Should -BeExactly 'ClientEvidencePending'
        }

        It 'classifies a record older than 30 minutes as pending evidence' {
            $inventory = New-TestPublishedEvidenceInventory

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:30:01Z')

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'ClientEvidencePending'
            $assessment.MarkerHashVerification | Should -BeExactly 'ClientEvidencePending'
        }

        It 'accepts a record at the exact 30-minute freshness boundary' {
            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory (New-TestPublishedEvidenceInventory) `
                -NowUtc ([datetime]'2026-08-30T12:30:00Z')

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
        }

        It 'fails closed when the server receipt is more than two minutes in the future' {
            $inventory = New-TestPublishedEvidenceInventory `
                -LastWriteTimeUtc ([datetime]'2026-08-30T12:12:01Z')

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceReceiptInFuture'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'accepts a server receipt at the exact two-minute future tolerance' {
            $inventory = New-TestPublishedEvidenceInventory `
                -LastWriteTimeUtc ([datetime]'2026-08-30T12:12:00Z')

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
        }

        It 'matches the fixed computer name case-insensitively' {
            $inventory = New-TestPublishedEvidenceInventory
            $json = [System.Text.UTF8Encoding]::new($false).GetString(
                $inventory.Evidence.Bytes).Replace('RING0IVY24-01', 'ring0ivy24-01')
            $inventory = New-TestPublishedEvidenceInventory -Json $json

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
        }

        It 'keeps evidence pending when it predates this run evaluation request' {
            $inventory = New-TestPublishedEvidenceInventory `
                -LastWriteTimeUtc ([datetime]'2026-08-30T12:05:00Z')

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z') `
                -MinimumReceiptUtc ([datetime]'2026-08-30T12:06:00Z')

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'ClientEvidencePending'
            $assessment.MarkerHashVerification | Should -BeExactly 'ClientEvidencePending'
        }

        It 'fails closed when the final record owner is not the target computer SID' {
            $inventory = New-TestPublishedEvidenceInventory `
                -OwnerSid 'S-1-5-21-1-2-3-9999'

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceOwnerMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'fails closed when the final record ACL is not the exact inherited set' {
            $inventory = New-TestPublishedEvidenceInventory -AclExact $false

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceAclMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'fails closed when the final record is a reparse point' {
            $inventory = New-TestPublishedEvidenceInventory -IsReparsePoint $true

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceReparsePoint'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'fails closed on a contradictory record field: <Name>' -ForEach @(
            @{
                Name = 'schema version'
                Json = '{"schemaVersion":2,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'computer name'
                Json = '{"schemaVersion":1,"computerName":"OTHER-CLIENT","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'marker path'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\Other\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'marker hash'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"0000000000000000000000000000000000000000000000000000000000000000","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'marker length'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":79,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'verification method'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"ProjectedServerState"}'
            }
        ) {
            $inventory = New-TestPublishedEvidenceInventory -Json $Json

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceRecordMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'returns a bounded conflict for malformed evidence instead of throwing' {
            $inventory = New-TestPublishedEvidenceInventory -Json '{'

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceMalformed'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'returns a bounded unavailable result when the local read fails' {
            $inventory = New-TestPublishedEvidenceInventory -ReadError 'Access denied at a private path'

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceReadUnavailable'
            $assessment.MarkerHashVerification | Should -BeExactly 'ProbeUnavailable'
            $assessment.PSObject.Properties.Name | Should -Not -Contain 'ReadError'
        }

        It 'fails closed when filesystem length and bounded bytes disagree' {
            $inventory = New-TestPublishedEvidenceInventory -Length 999

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceLengthMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'fails closed when the authoritative server receipt time is missing' {
            $inventory = New-TestPublishedEvidenceInventory
            $inventory.Evidence.LastWriteTimeUtc = $null

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceReceiptUnavailable'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'never accepts evidence when the target and owner SID are unresolved' {
            $inventory = New-TestPublishedEvidenceInventory `
                -TargetComputerSid '' -OwnerSid ''

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceOwnerMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'keeps an authenticated direct read authoritative without fallback' {
            $direct = [pscustomobject]@{
                MarkerHash = ('A' * 64)
                MarkerHashVerification = 'DirectAuthenticatedFileRead'
                MarkerLastWriteTime = '2026-08-30T12:00:00.0000000Z'
            }
            $inventory = New-TestPublishedEvidenceInventory -Json '{'

            $selection = Get-SetupCmMarkerClientEvidenceSelection `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -DirectState $direct -EvidenceInventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $selection.MarkerHash | Should -BeExactly ('A' * 64)
            $selection.MarkerHashVerification | Should -BeExactly `
                'DirectAuthenticatedFileRead'
        }

        It 'keeps an authenticated direct missing result authoritative without fallback' {
            $direct = [pscustomobject]@{
                MarkerHash = ''
                MarkerHashVerification = 'Missing'
                MarkerLastWriteTime = ''
            }

            $selection = Get-SetupCmMarkerClientEvidenceSelection `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -DirectState $direct `
                -EvidenceInventory (New-TestPublishedEvidenceInventory) `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $selection.MarkerHash | Should -BeNullOrEmpty
            $selection.MarkerHashVerification | Should -BeExactly 'Missing'
        }

        It 'falls back from unavailable direct read to exact published evidence' {
            $direct = [pscustomobject]@{
                MarkerHash = ''
                MarkerHashVerification = 'ProbeUnavailable'
                MarkerLastWriteTime = ''
            }

            $selection = Get-SetupCmMarkerClientEvidenceSelection `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -DirectState $direct `
                -EvidenceInventory (New-TestPublishedEvidenceInventory) `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $selection.MarkerHash | Should -BeExactly `
                '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
            $selection.MarkerLength | Should -Be 78
            $selection.MarkerHashVerification | Should -BeExactly `
                'DirectAuthenticatedClientEvidence'
            $selection.EvidenceOwnerSid | Should -BeExactly 'S-1-5-21-1-2-3-1001'
        }

        It 'maps missing or stale fallback evidence to pending' {
            $direct = [pscustomobject]@{
                MarkerHash = ''
                MarkerHashVerification = 'ProbeUnavailable'
                MarkerLastWriteTime = ''
            }
            $inventory = New-TestPublishedEvidenceInventory -Exists $false

            $selection = Get-SetupCmMarkerClientEvidenceSelection `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -DirectState $direct -EvidenceInventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $selection.MarkerHashVerification | Should -BeExactly `
                'ClientEvidencePending'
        }

        It 'maps malformed, foreign, or future fallback evidence to conflict' {
            $direct = [pscustomobject]@{
                MarkerHash = ''
                MarkerHashVerification = 'ProbeUnavailable'
                MarkerLastWriteTime = ''
            }
            $inventory = New-TestPublishedEvidenceInventory -Json '{'

            $selection = Get-SetupCmMarkerClientEvidenceSelection `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -DirectState $direct -EvidenceInventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $selection.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
            $selection.EvidenceReason | Should -BeExactly 'EvidenceMalformed'
        }

        It 'keeps both unexpectedly unavailable reads as probe unavailable' {
            $direct = [pscustomobject]@{
                MarkerHash = ''
                MarkerHashVerification = 'ProbeUnavailable'
                MarkerLastWriteTime = ''
            }
            $inventory = New-TestPublishedEvidenceInventory `
                -ReadError 'private transport details'

            $selection = Get-SetupCmMarkerClientEvidenceSelection `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -DirectState $direct -EvidenceInventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $selection.MarkerHashVerification | Should -BeExactly 'ProbeUnavailable'
            $selection.EvidenceReason | Should -BeExactly 'EvidenceReadUnavailable'
            ($selection | ConvertTo-Json -Depth 5) | Should -Not -Match `
                'private transport details'
        }
    }
}
