function Get-SetupCmMarkerEvidenceChannelResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Compliant', 'NotCompliant', 'Conflict')]
        [string]$State,
        [Parameter(Mandatory)][string]$Reason
    )

    [pscustomobject][ordered]@{
        State = $State
        Reason = $Reason
    }
}

function Test-SetupCmMarkerAclEntriesExact {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()][object[]]$Actual = @(),
        [Parameter(Mandatory)][ValidateSet('Ntfs', 'Share')][string]$Kind,
        [Parameter(Mandatory)][object[]]$Expected
    )

    if (@($Actual).Count -ne @($Expected).Count) { return $false }

    $getKey = {
        param($Entry, $EntryKind)

        if ($EntryKind -eq 'Share') {
            return '{0}|{1}|{2}' -f
                [string](Get-SetupCmMarkerValue -InputObject $Entry -Name Sid),
                [string](Get-SetupCmMarkerValue -InputObject $Entry -Name AccessRight),
                [int](Get-SetupCmMarkerValue -InputObject $Entry -Name AccessControlType -DefaultValue -1)
        }

        '{0}|{1}|{2}|{3}|{4}|{5}' -f
            [string](Get-SetupCmMarkerValue -InputObject $Entry -Name Sid),
            [int](Get-SetupCmMarkerValue -InputObject $Entry -Name Rights -DefaultValue -1),
            [int](Get-SetupCmMarkerValue -InputObject $Entry -Name InheritanceFlags -DefaultValue -1),
            [int](Get-SetupCmMarkerValue -InputObject $Entry -Name PropagationFlags -DefaultValue -1),
            [int](Get-SetupCmMarkerValue -InputObject $Entry -Name AccessControlType -DefaultValue -1),
            [bool](Get-SetupCmMarkerValue -InputObject $Entry -Name IsInherited -DefaultValue $true)
    }
    $actualKeys = @($Actual | ForEach-Object { & $getKey $_ $Kind } |
        Sort-Object -CaseSensitive)
    $expectedKeys = @($Expected | ForEach-Object { & $getKey $_ $Kind } |
        Sort-Object -CaseSensitive)
    @(Compare-Object -ReferenceObject $expectedKeys -DifferenceObject $actualKeys `
            -CaseSensitive).Count -eq 0
}

function Get-SetupCmMarkerExpectedChannelAces {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Inventory,
        [Parameter(Mandatory)][ValidateSet('Parent', 'Target', 'Share')][string]$Scope
    )

    $administratorsSid = [string](Get-SetupCmMarkerValue `
        -InputObject $Inventory -Name AdministratorsSid)
    $systemSid = [string](Get-SetupCmMarkerValue -InputObject $Inventory -Name SystemSid)
    $targetSid = [string](Get-SetupCmMarkerValue `
        -InputObject $Inventory -Name TargetComputerSid)
    if ($Scope -eq 'Share') {
        return @(
            [pscustomobject]@{
                Sid = $administratorsSid
                AccessRight = 'Full'
                AccessControlType = 0
            }
            [pscustomobject]@{
                Sid = $targetSid
                AccessRight = 'Change'
                AccessControlType = 0
            }
        )
    }

    $expected = @(
        [pscustomobject]@{
            Sid = $administratorsSid
            Rights = 2032127
            InheritanceFlags = 3
            PropagationFlags = 0
            AccessControlType = 0
            IsInherited = $false
        }
        [pscustomobject]@{
            Sid = $systemSid
            Rights = 2032127
            InheritanceFlags = 3
            PropagationFlags = 0
            AccessControlType = 0
            IsInherited = $false
        }
    )
    if ($Scope -eq 'Target') {
        $expected += @(
            [pscustomobject]@{
                Sid = $targetSid
                Rights = 1179819
                InheritanceFlags = 0
                PropagationFlags = 0
                AccessControlType = 0
                IsInherited = $false
            }
            [pscustomobject]@{
                Sid = $targetSid
                Rights = 1245631
                InheritanceFlags = 2
                PropagationFlags = 2
                AccessControlType = 0
                IsInherited = $false
            }
        )
    }
    $expected
}

function Get-SetupCmMarkerApprovedPredecessorTargetAces {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Inventory)

    $expected = @(Get-SetupCmMarkerExpectedChannelAces `
        -Inventory $Inventory -Scope Target)
    foreach ($entry in $expected) {
        if ([string]$entry.Sid -ceq [string]$Inventory.TargetComputerSid -and
            [int]$entry.Rights -eq 1245631) {
            $entry.InheritanceFlags = 1
        }
    }
    $expected
}

function Resolve-SetupCmMarkerSid {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$AccountName)

    ([System.Security.Principal.NTAccount]::new($AccountName)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
}

function ConvertTo-SetupCmMarkerNtfsAce {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$AccessRule)

    $sid = if ($AccessRule.IdentityReference -is
        [System.Security.Principal.SecurityIdentifier]) {
        $AccessRule.IdentityReference.Value
    }
    else {
        Resolve-SetupCmMarkerSid -AccountName ([string]$AccessRule.IdentityReference)
    }
    [pscustomobject][ordered]@{
        Sid = [string]$sid
        Rights = [int]$AccessRule.FileSystemRights
        InheritanceFlags = [int]$AccessRule.InheritanceFlags
        PropagationFlags = [int]$AccessRule.PropagationFlags
        AccessControlType = [int]$AccessRule.AccessControlType
        IsInherited = [bool]$AccessRule.IsInherited
    }
}

function Get-SetupCmMarkerDirectoryInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Any)) {
        return [pscustomobject][ordered]@{
            Exists = $false
            IsDirectory = $false
            IsReparsePoint = $false
            OwnerSid = ''
            AclProtected = $false
            Aces = @()
        }
    }

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $rules = @($acl.GetAccessRules(
            $true,
            $true,
            [System.Security.Principal.SecurityIdentifier]
        ) | ForEach-Object { ConvertTo-SetupCmMarkerNtfsAce -AccessRule $_ })
    [pscustomobject][ordered]@{
        Exists = $true
        IsDirectory = [bool]($item.Attributes -band [System.IO.FileAttributes]::Directory)
        IsReparsePoint = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        OwnerSid = [string]$acl.GetOwner(
            [System.Security.Principal.SecurityIdentifier]
        ).Value
        AclProtected = [bool]$acl.AreAccessRulesProtected
        Aces = $rules
    }
}

function Read-SetupCmMarkerBoundedBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateRange(1, 1048576)][int]$MaximumBytes
    )

    $limit = $MaximumBytes + 1
    $buffer = [byte[]]::new($limit)
    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
    )
    try {
        $total = 0
        while ($total -lt $limit) {
            $read = $stream.Read($buffer, $total, $limit - $total)
            if ($read -eq 0) { break }
            $total += $read
        }
        if ($total -eq 0) { return [byte[]]@() }
        [byte[]]$buffer[0..($total - 1)]
    }
    finally {
        $stream.Dispose()
    }
}

function Get-SetupCmMarkerEvidenceFileInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$TargetComputerSid,
        [Parameter(Mandatory)][ValidateRange(1, 1048576)][int]$MaximumBytes
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Any)) {
        return [pscustomobject][ordered]@{
            Exists = $false
            IsDirectory = $false
            IsReparsePoint = $false
            Length = 0L
            Bytes = [byte[]]@()
            OwnerSid = ''
            AclExact = $false
            Aces = @()
            LastWriteTimeUtc = $null
            ReadError = ''
        }
    }

    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        $aces = @($acl.GetAccessRules(
                $true,
                $true,
                [System.Security.Principal.SecurityIdentifier]
            ) | ForEach-Object { ConvertTo-SetupCmMarkerNtfsAce -AccessRule $_ })
        $expected = @(
            [pscustomobject]@{
                Sid = 'S-1-5-32-544'; Rights = 2032127
                InheritanceFlags = 0; PropagationFlags = 0
                AccessControlType = 0; IsInherited = $true
            }
            [pscustomobject]@{
                Sid = 'S-1-5-18'; Rights = 2032127
                InheritanceFlags = 0; PropagationFlags = 0
                AccessControlType = 0; IsInherited = $true
            }
            [pscustomobject]@{
                Sid = $TargetComputerSid; Rights = 1245631
                InheritanceFlags = 0; PropagationFlags = 0
                AccessControlType = 0; IsInherited = $true
            }
        )
        [pscustomobject][ordered]@{
            Exists = $true
            IsDirectory = [bool]($item.Attributes -band [System.IO.FileAttributes]::Directory)
            IsReparsePoint = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
            Length = [long]$item.Length
            Bytes = Read-SetupCmMarkerBoundedBytes `
                -Path $Path -MaximumBytes $MaximumBytes
            OwnerSid = [string]$acl.GetOwner(
                [System.Security.Principal.SecurityIdentifier]
            ).Value
            AclExact = Test-SetupCmMarkerAclEntriesExact `
                -Actual $aces -Expected $expected -Kind Ntfs
            Aces = $aces
            LastWriteTimeUtc = [datetime]$item.LastWriteTimeUtc
            ReadError = ''
        }
    }
    catch {
        [pscustomobject][ordered]@{
            Exists = $true
            IsDirectory = $false
            IsReparsePoint = $false
            Length = -1L
            Bytes = [byte[]]@()
            OwnerSid = ''
            AclExact = $false
            Aces = @()
            LastWriteTimeUtc = $null
            ReadError = 'ReadUnavailable'
        }
    }
}

function Get-SetupCmMarkerShareInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $shares = @(Get-SmbShare -Name $Name -ErrorAction SilentlyContinue)
    if ($shares.Count -eq 0) {
        return [pscustomobject][ordered]@{
            Exists = $false
            Path = ''
            Description = ''
            CachingMode = ''
            Aces = @()
        }
    }
    if ($shares.Count -ne 1) {
        throw 'Marker evidence share identity is not unique.'
    }

    $aces = @(Get-SmbShareAccess -Name $Name -ErrorAction Stop | ForEach-Object {
            [pscustomobject][ordered]@{
                Sid = Resolve-SetupCmMarkerSid -AccountName ([string]$_.AccountName)
                AccessRight = [string]$_.AccessRight
                AccessControlType = [int]$_.AccessControlType
            }
        })
    [pscustomobject][ordered]@{
        Exists = $true
        Path = [string]$shares[0].Path
        Description = [string]$shares[0].Description
        CachingMode = [string]$shares[0].CachingMode
        Aces = $aces
    }
}

function Get-SetupCmMarkerEvidenceChannelInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Contract)

    $emptyDirectory = {
        [pscustomobject][ordered]@{
            Exists = $false; IsDirectory = $false; IsReparsePoint = $false
            OwnerSid = ''; AclProtected = $false; Aces = @()
        }
    }
    $emptyEvidence = {
        [pscustomobject][ordered]@{
            Exists = $false; IsDirectory = $false; IsReparsePoint = $false
            Length = 0L; Bytes = [byte[]]@(); OwnerSid = ''; AclExact = $false
            Aces = @(); LastWriteTimeUtc = $null; ReadError = ''
        }
    }
    $emptyShare = {
        [pscustomobject][ordered]@{
            Exists = $false; Path = ''; Description = ''; CachingMode = ''; Aces = @()
        }
    }

    try {
        $targetSid = Resolve-SetupCmMarkerSid `
            -AccountName ([string]$Contract.EvidenceChannel.ComputerAccount)
        $parent = Get-SetupCmMarkerDirectoryInventory `
            -Path ([string]$Contract.EvidenceChannel.LocalParent)
        $target = Get-SetupCmMarkerDirectoryInventory `
            -Path ([string]$Contract.EvidenceChannel.LocalPath)
        $evidencePath = '{0}\{1}' -f
            ([string]$Contract.EvidenceChannel.LocalPath).TrimEnd('\'),
            [string]$Contract.EvidenceChannel.FileName
        $evidence = Get-SetupCmMarkerEvidenceFileInventory `
            -Path $evidencePath `
            -TargetComputerSid $targetSid `
            -MaximumBytes ([int]$Contract.EvidenceChannel.MaximumBytes)
        $share = Get-SetupCmMarkerShareInventory `
            -Name ([string]$Contract.EvidenceChannel.ShareName)
        [pscustomobject][ordered]@{
            TargetComputerSid = [string]$targetSid
            AdministratorsSid = 'S-1-5-32-544'
            SystemSid = 'S-1-5-18'
            ProbeError = ''
            Parent = $parent
            Target = $target
            Share = $share
            Evidence = $evidence
        }
    }
    catch {
        [pscustomobject][ordered]@{
            TargetComputerSid = ''
            AdministratorsSid = 'S-1-5-32-544'
            SystemSid = 'S-1-5-18'
            ProbeError = 'InventoryUnavailable'
            Parent = & $emptyDirectory
            Target = & $emptyDirectory
            Share = & $emptyShare
            Evidence = & $emptyEvidence
        }
    }
}

function Get-SetupCmMarkerDirectorySecurity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Parent', 'Target')][string]$Role,
        [Parameter(Mandatory)][string]$TargetComputerSid
    )

    $administratorsSid = [System.Security.Principal.SecurityIdentifier]::new(
        'S-1-5-32-544'
    )
    $systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $targetSid = [System.Security.Principal.SecurityIdentifier]::new(
        $TargetComputerSid
    )
    $security = [System.Security.AccessControl.DirectorySecurity]::new()
    $security.SetAccessRuleProtection($true, $false)
    $security.SetOwner($administratorsSid)
    $security.AddAccessRule(
        [System.Security.AccessControl.FileSystemAccessRule]::new(
            $administratorsSid,
            [System.Security.AccessControl.FileSystemRights]2032127,
            [System.Security.AccessControl.InheritanceFlags]3,
            [System.Security.AccessControl.PropagationFlags]0,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
    )
    $security.AddAccessRule(
        [System.Security.AccessControl.FileSystemAccessRule]::new(
            $systemSid,
            [System.Security.AccessControl.FileSystemRights]2032127,
            [System.Security.AccessControl.InheritanceFlags]3,
            [System.Security.AccessControl.PropagationFlags]0,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
    )
    if ($Role -eq 'Target') {
        $security.AddAccessRule(
            [System.Security.AccessControl.FileSystemAccessRule]::new(
                $targetSid,
                [System.Security.AccessControl.FileSystemRights]1179819,
                [System.Security.AccessControl.InheritanceFlags]0,
                [System.Security.AccessControl.PropagationFlags]0,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
        )
        $security.AddAccessRule(
            [System.Security.AccessControl.FileSystemAccessRule]::new(
                $targetSid,
                [System.Security.AccessControl.FileSystemRights]1245631,
                [System.Security.AccessControl.InheritanceFlags]2,
                [System.Security.AccessControl.PropagationFlags]2,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
        )
    }
    $security
}

function New-SetupCmMarkerEvidenceChannel {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param([Parameter(Mandatory)]$Contract)

    $inventory = Get-SetupCmMarkerEvidenceChannelInventory -Contract $Contract
    $assessment = Get-SetupCmMarkerEvidenceChannelAssessment `
        -Contract $Contract -Inventory $inventory
    if ($assessment.State -eq 'Compliant') {
        return [pscustomobject][ordered]@{
            Changed = $false
            State = 'Compliant'
            Reason = 'Exact'
            Actions = @()
        }
    }
    if ($assessment.State -eq 'Conflict' -or
        $assessment.Reason -notin @(
            'Missing',
            'IncompleteOwnedChannel',
            'ApprovedTargetFileInheritanceUpgrade'
        )) {
        throw "Marker evidence channel conflict: $($assessment.Reason)."
    }

    $targetSid = [string](Get-SetupCmMarkerValue `
        -InputObject $inventory -Name TargetComputerSid)
    if ([string]::IsNullOrWhiteSpace($targetSid)) {
        throw 'Marker evidence target computer SID is unavailable.'
    }
    if (-not $PSCmdlet.ShouldProcess(
            [string]$Contract.EvidenceChannel.LocalPath,
            'Create the exact marker evidence channel'
        )) {
        return [pscustomobject][ordered]@{
            Changed = $false
            State = [string]$assessment.State
            Reason = 'WhatIf'
            Actions = @()
        }
    }

    $actions = [System.Collections.Generic.List[string]]::new()
    $parent = Get-SetupCmMarkerValue -InputObject $inventory -Name Parent
    if (-not [bool](Get-SetupCmMarkerValue `
            -InputObject $parent -Name Exists -DefaultValue $false)) {
        New-Item -ItemType Directory `
            -Path ([string]$Contract.EvidenceChannel.LocalParent) `
            -ErrorAction Stop | Out-Null
        $parentAcl = Get-SetupCmMarkerDirectorySecurity `
            -Role Parent -TargetComputerSid $targetSid
        Set-Acl -LiteralPath ([string]$Contract.EvidenceChannel.LocalParent) `
            -AclObject $parentAcl -ErrorAction Stop
        [void]$actions.Add('CreateProtectedParent')
    }

    $target = Get-SetupCmMarkerValue -InputObject $inventory -Name Target
    $targetExists = [bool](Get-SetupCmMarkerValue `
        -InputObject $target -Name Exists -DefaultValue $false)
    $targetUsesApprovedPredecessorAcl = $targetExists -and
        (Test-SetupCmMarkerAclEntriesExact `
            -Actual @(Get-SetupCmMarkerValue -InputObject $target -Name Aces) `
            -Expected @(Get-SetupCmMarkerApprovedPredecessorTargetAces `
                -Inventory $inventory) -Kind Ntfs)
    $normalizeTargetFileInheritance =
        $assessment.Reason -eq 'ApprovedTargetFileInheritanceUpgrade' -or
        ($assessment.Reason -eq 'IncompleteOwnedChannel' -and
            $targetUsesApprovedPredecessorAcl)
    if (-not $targetExists -or $normalizeTargetFileInheritance) {
        if (-not $targetExists) {
            New-Item -ItemType Directory `
                -Path ([string]$Contract.EvidenceChannel.LocalPath) `
                -ErrorAction Stop | Out-Null
        }
        $targetAcl = Get-SetupCmMarkerDirectorySecurity `
            -Role Target -TargetComputerSid $targetSid
        Set-Acl -LiteralPath ([string]$Contract.EvidenceChannel.LocalPath) `
            -AclObject $targetAcl -ErrorAction Stop
        $targetAction = if ($normalizeTargetFileInheritance) {
            'NormalizeTargetFileInheritance'
        }
        else {
            'CreateProtectedTarget'
        }
        [void]$actions.Add($targetAction)
    }

    $share = Get-SetupCmMarkerValue -InputObject $inventory -Name Share
    if (-not [bool](Get-SetupCmMarkerValue `
            -InputObject $share -Name Exists -DefaultValue $false)) {
        New-SmbShare `
            -Name ([string]$Contract.EvidenceChannel.ShareName) `
            -Path ([string]$Contract.EvidenceChannel.LocalPath) `
            -Description ([string]$Contract.EvidenceChannel.ShareDescription) `
            -CachingMode None `
            -FullAccess 'BUILTIN\Administrators' `
            -ChangeAccess ([string]$Contract.EvidenceChannel.ComputerAccount) `
            -ErrorAction Stop | Out-Null
        [void]$actions.Add('CreateBoundedShare')
    }

    $finalInventory = Get-SetupCmMarkerEvidenceChannelInventory -Contract $Contract
    $finalAssessment = Get-SetupCmMarkerEvidenceChannelAssessment `
        -Contract $Contract -Inventory $finalInventory
    if ($finalAssessment.State -ne 'Compliant') {
        throw "Marker evidence channel verification failed: $($finalAssessment.Reason)."
    }
    [pscustomobject][ordered]@{
        Changed = $actions.Count -gt 0
        State = [string]$finalAssessment.State
        Reason = [string]$finalAssessment.Reason
        Actions = @($actions)
    }
}

function Get-SetupCmMarkerEvidenceChannelAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Contract,
        [Parameter(Mandatory)]$Inventory
    )

    $targetSid = [string](Get-SetupCmMarkerValue `
        -InputObject $Inventory -Name TargetComputerSid)
    $administratorsSid = [string](Get-SetupCmMarkerValue `
        -InputObject $Inventory -Name AdministratorsSid)
    $systemSid = [string](Get-SetupCmMarkerValue -InputObject $Inventory -Name SystemSid)
    $probeError = [string](Get-SetupCmMarkerValue -InputObject $Inventory -Name ProbeError)
    if ([string]::IsNullOrWhiteSpace($targetSid) -or
        [string]::IsNullOrWhiteSpace($administratorsSid) -or
        [string]::IsNullOrWhiteSpace($systemSid) -or
        -not [string]::IsNullOrWhiteSpace($probeError)) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State Conflict -Reason EvidenceIdentityConflict
    }

    $parent = Get-SetupCmMarkerValue -InputObject $Inventory -Name Parent
    $target = Get-SetupCmMarkerValue -InputObject $Inventory -Name Target
    $share = Get-SetupCmMarkerValue -InputObject $Inventory -Name Share
    $evidence = Get-SetupCmMarkerValue -InputObject $Inventory -Name Evidence
    $parentExists = [bool](Get-SetupCmMarkerValue `
        -InputObject $parent -Name Exists -DefaultValue $false)
    $targetExists = [bool](Get-SetupCmMarkerValue `
        -InputObject $target -Name Exists -DefaultValue $false)
    $shareExists = [bool](Get-SetupCmMarkerValue `
        -InputObject $share -Name Exists -DefaultValue $false)
    $evidenceExists = [bool](Get-SetupCmMarkerValue `
        -InputObject $evidence -Name Exists -DefaultValue $false)

    if (-not $parentExists -and -not $targetExists -and
        -not $shareExists -and -not $evidenceExists) {
        return Get-SetupCmMarkerEvidenceChannelResult -State NotCompliant -Reason Missing
    }
    if ((-not $parentExists -and ($targetExists -or $shareExists -or $evidenceExists)) -or
        (-not $targetExists -and ($shareExists -or $evidenceExists))) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State Conflict -Reason EvidenceIdentityConflict
    }

    foreach ($directory in @($parent, $target)) {
        if (-not [bool](Get-SetupCmMarkerValue `
                    -InputObject $directory -Name Exists -DefaultValue $false)) {
            continue
        }
        if (-not [bool](Get-SetupCmMarkerValue `
                    -InputObject $directory -Name IsDirectory -DefaultValue $false) -or
            [bool](Get-SetupCmMarkerValue `
                    -InputObject $directory -Name IsReparsePoint -DefaultValue $false) -or
            [string](Get-SetupCmMarkerValue `
                    -InputObject $directory -Name OwnerSid) -cne $administratorsSid) {
            return Get-SetupCmMarkerEvidenceChannelResult `
                -State Conflict -Reason EvidenceIdentityConflict
        }
    }
    if ($evidenceExists -and
        ([bool](Get-SetupCmMarkerValue `
                -InputObject $evidence -Name IsDirectory -DefaultValue $false) -or
        [bool](Get-SetupCmMarkerValue `
                -InputObject $evidence -Name IsReparsePoint -DefaultValue $false) -or
        [string](Get-SetupCmMarkerValue `
                -InputObject $evidence -Name OwnerSid) -cne $targetSid)) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State Conflict -Reason EvidenceIdentityConflict
    }

    if ($shareExists -and
        [string](Get-SetupCmMarkerValue -InputObject $share -Name Path) -cne
        [string]$Contract.EvidenceChannel.LocalPath) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State Conflict -Reason SharePathConflict
    }
    if ($shareExists -and
        ([string](Get-SetupCmMarkerValue -InputObject $share -Name Description) -cne
            [string]$Contract.EvidenceChannel.ShareDescription -or
        [string](Get-SetupCmMarkerValue -InputObject $share -Name CachingMode) -cne 'None')) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State Conflict -Reason ShareConfigurationConflict
    }

    if ($parentExists -and
        (-not [bool](Get-SetupCmMarkerValue `
                -InputObject $parent -Name AclProtected -DefaultValue $false) -or
        -not (Test-SetupCmMarkerAclEntriesExact `
            -Actual @(Get-SetupCmMarkerValue -InputObject $parent -Name Aces) `
            -Expected @(Get-SetupCmMarkerExpectedChannelAces `
                -Inventory $Inventory -Scope Parent) -Kind Ntfs))) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State Conflict -Reason EvidenceAclConflict
    }
    $approvedTargetFileInheritanceUpgrade = $false
    if ($targetExists) {
        if (-not [bool](Get-SetupCmMarkerValue `
                -InputObject $target -Name AclProtected -DefaultValue $false)) {
            return Get-SetupCmMarkerEvidenceChannelResult `
                -State Conflict -Reason EvidenceAclConflict
        }
        $targetAces = @(Get-SetupCmMarkerValue -InputObject $target -Name Aces)
        if (-not (Test-SetupCmMarkerAclEntriesExact `
                -Actual $targetAces `
                -Expected @(Get-SetupCmMarkerExpectedChannelAces `
                    -Inventory $Inventory -Scope Target) -Kind Ntfs)) {
            $approvedTargetFileInheritanceUpgrade =
                Test-SetupCmMarkerAclEntriesExact `
                    -Actual $targetAces `
                    -Expected @(Get-SetupCmMarkerApprovedPredecessorTargetAces `
                        -Inventory $Inventory) -Kind Ntfs
            if (-not $approvedTargetFileInheritanceUpgrade) {
                return Get-SetupCmMarkerEvidenceChannelResult `
                    -State Conflict -Reason EvidenceAclConflict
            }
        }
    }
    if ($shareExists -and
        -not (Test-SetupCmMarkerAclEntriesExact `
            -Actual @(Get-SetupCmMarkerValue -InputObject $share -Name Aces) `
            -Expected @(Get-SetupCmMarkerExpectedChannelAces `
                -Inventory $Inventory -Scope Share) -Kind Share)) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State Conflict -Reason EvidenceAclConflict
    }
    if ($evidenceExists -and
        -not [bool](Get-SetupCmMarkerValue `
            -InputObject $evidence -Name AclExact -DefaultValue $false)) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State Conflict -Reason EvidenceAclConflict
    }

    if ($approvedTargetFileInheritanceUpgrade -and $shareExists) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State NotCompliant -Reason ApprovedTargetFileInheritanceUpgrade
    }

    if (-not $targetExists -or -not $shareExists) {
        return Get-SetupCmMarkerEvidenceChannelResult `
            -State NotCompliant -Reason IncompleteOwnedChannel
    }
    Get-SetupCmMarkerEvidenceChannelResult -State Compliant -Reason Exact
}

function ConvertFrom-SetupCmMarkerEvidenceJsonStrict {
    [CmdletBinding()]
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $contract = Get-SetupCmMarkerFixedContract
    if ($Bytes.Count -gt [int]$contract.EvidenceChannel.MaximumBytes) {
        throw 'Marker evidence exceeds the 2,048-byte limit.'
    }
    if (@($Bytes | Where-Object { $_ -gt 0x7f }).Count -gt 0) {
        throw 'Marker evidence must contain only ASCII-compatible JSON.'
    }

    $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    $document = [System.Text.Json.JsonDocument]::Parse($text)
    try {
        $expectedNames = @(
            'schemaVersion',
            'computerName',
            'markerPath',
            'markerSha256',
            'markerLength',
            'verificationMethod'
        )
        $properties = @($document.RootElement.EnumerateObject())
        $propertyNames = @($properties | ForEach-Object Name)
        $uniqueNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::Ordinal
        )
        foreach ($propertyName in $propertyNames) {
            [void]$uniqueNames.Add($propertyName)
        }
        if ($propertyNames.Count -ne $expectedNames.Count -or
            $uniqueNames.Count -ne $expectedNames.Count -or
            @($propertyNames | Where-Object { $_ -cnotin $expectedNames }).Count -gt 0) {
            throw 'Marker evidence properties are not exact.'
        }
        foreach ($property in $properties) {
            $expectedKind = if ($property.Name -in 'schemaVersion', 'markerLength') {
                [System.Text.Json.JsonValueKind]::Number
            }
            else {
                [System.Text.Json.JsonValueKind]::String
            }
            if ($property.Value.ValueKind -ne $expectedKind) {
                throw 'Marker evidence property types are not exact.'
            }
        }

        [pscustomobject][ordered]@{
            schemaVersion = $document.RootElement.GetProperty('schemaVersion').GetInt32()
            computerName = $document.RootElement.GetProperty('computerName').GetString()
            markerPath = $document.RootElement.GetProperty('markerPath').GetString()
            markerSha256 = $document.RootElement.GetProperty('markerSha256').GetString()
            markerLength = $document.RootElement.GetProperty('markerLength').GetInt64()
            verificationMethod = $document.RootElement.GetProperty('verificationMethod').GetString()
        }
    }
    finally {
        $document.Dispose()
    }
}

function Get-SetupCmMarkerPublishedEvidenceAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Contract,
        [Parameter(Mandatory)][AllowNull()]$Inventory,
        [datetime]$NowUtc = (Get-Date).ToUniversalTime(),
        [Nullable[datetime]]$MinimumReceiptUtc
    )

    $evidence = Get-SetupCmMarkerValue -InputObject $Inventory -Name Evidence
    if ($null -eq $evidence -or
        -not [bool](Get-SetupCmMarkerValue -InputObject $evidence -Name Exists -DefaultValue $false)) {
        return [pscustomobject][ordered]@{
            State = 'NotCompliant'
            Reason = 'ClientEvidencePending'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'ClientEvidencePending'
            ReceiptTimeUtc = $null
            OwnerSid = ''
        }
    }
    if (-not [string]::IsNullOrWhiteSpace([string](Get-SetupCmMarkerValue `
                -InputObject $evidence -Name ReadError))) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceReadUnavailable'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'ProbeUnavailable'
            ReceiptTimeUtc = $null
            OwnerSid = ''
        }
    }

    $ownerSid = [string](Get-SetupCmMarkerValue -InputObject $evidence -Name OwnerSid)
    if ([bool](Get-SetupCmMarkerValue `
            -InputObject $evidence -Name IsReparsePoint -DefaultValue $false)) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceReparsePoint'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }
    $targetComputerSid = [string](Get-SetupCmMarkerValue `
        -InputObject $Inventory -Name TargetComputerSid)
    if ([string]::IsNullOrWhiteSpace($ownerSid) -or
        [string]::IsNullOrWhiteSpace($targetComputerSid) -or
        $ownerSid -cne $targetComputerSid) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceOwnerMismatch'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }
    if (-not [bool](Get-SetupCmMarkerValue `
            -InputObject $evidence -Name AclExact -DefaultValue $false)) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceAclMismatch'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }

    $bytes = [byte[]](Get-SetupCmMarkerValue -InputObject $evidence -Name Bytes)
    $evidenceLength = [long](Get-SetupCmMarkerValue `
        -InputObject $evidence -Name Length -DefaultValue -1)
    if ($evidenceLength -ne $bytes.Count -or
        $evidenceLength -gt [long]$Contract.EvidenceChannel.MaximumBytes) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceLengthMismatch'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }

    try {
        $record = ConvertFrom-SetupCmMarkerEvidenceJsonStrict `
            -Bytes $bytes
    }
    catch {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceMalformed'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }
    $recordExact =
        [int]$record.schemaVersion -eq [int]$Contract.EvidenceChannel.SchemaVersion -and
        [string]$record.computerName -ieq [string]$Contract.TargetName -and
        [string]$record.markerPath -ceq [string]$Contract.MarkerPath -and
        [string]$record.markerSha256 -ceq [string]$Contract.MarkerHash -and
        [long]$record.markerLength -eq [long]$Contract.MarkerLength -and
        [string]$record.verificationMethod -ceq [string]$Contract.EvidenceChannel.VerificationMethod
    if (-not $recordExact) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceRecordMismatch'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }

    $receiptValue = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
    if ($receiptValue -isnot [datetime]) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceReceiptUnavailable'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = $null
            OwnerSid = $ownerSid
        }
    }
    $receiptTimeUtc = ([datetime]$receiptValue).ToUniversalTime()
    if ($receiptTimeUtc -gt $NowUtc.ToUniversalTime().AddMinutes(
            [int]$Contract.EvidenceChannel.FutureToleranceMinutes)) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceReceiptInFuture'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = $receiptTimeUtc
            OwnerSid = $ownerSid
        }
    }
    if ($receiptTimeUtc -lt $NowUtc.ToUniversalTime().AddMinutes(
            -[int]$Contract.EvidenceChannel.FreshnessMinutes)) {
        return [pscustomobject][ordered]@{
            State = 'NotCompliant'
            Reason = 'ClientEvidencePending'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'ClientEvidencePending'
            ReceiptTimeUtc = $receiptTimeUtc
            OwnerSid = $ownerSid
        }
    }
    if ($null -ne $MinimumReceiptUtc -and
        $receiptTimeUtc -lt ([datetime]$MinimumReceiptUtc).ToUniversalTime()) {
        return [pscustomobject][ordered]@{
            State = 'NotCompliant'
            Reason = 'ClientEvidencePending'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'ClientEvidencePending'
            ReceiptTimeUtc = $receiptTimeUtc
            OwnerSid = $ownerSid
        }
    }

    [pscustomobject][ordered]@{
        State = 'Compliant'
        Reason = 'Exact'
        MarkerHash = [string]$record.markerSha256
        MarkerLength = [long]$record.markerLength
        MarkerHashVerification = 'DirectAuthenticatedClientEvidence'
        ReceiptTimeUtc = $receiptTimeUtc
        OwnerSid = $ownerSid
    }
}

function Get-SetupCmMarkerClientEvidenceSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Contract,
        [AllowNull()]$DirectState,
        [AllowNull()]$EvidenceInventory,
        [datetime]$NowUtc = (Get-Date).ToUniversalTime(),
        [Nullable[datetime]]$MinimumReceiptUtc
    )

    $directRoute = [string](Get-SetupCmMarkerValue `
        -InputObject $DirectState -Name MarkerHashVerification `
        -DefaultValue 'ProbeUnavailable')
    if ($directRoute -cne 'ProbeUnavailable') {
        return [pscustomobject][ordered]@{
            MarkerHash = [string](Get-SetupCmMarkerValue `
                -InputObject $DirectState -Name MarkerHash)
            MarkerLength = [long](Get-SetupCmMarkerValue `
                -InputObject $DirectState -Name MarkerLength -DefaultValue 0L)
            MarkerHashVerification = $directRoute
            MarkerLastWriteTime = [string](Get-SetupCmMarkerValue `
                -InputObject $DirectState -Name MarkerLastWriteTime)
            EvidenceReceiptTimeUtc = ''
            EvidenceOwnerSid = ''
            EvidenceReason = ''
        }
    }

    $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
        -Contract $Contract -Inventory $EvidenceInventory -NowUtc $NowUtc `
        -MinimumReceiptUtc $MinimumReceiptUtc
    $route = switch ([string]$assessment.State) {
        'Compliant' { 'DirectAuthenticatedClientEvidence' }
        'NotCompliant' { 'ClientEvidencePending' }
        default {
            if ([string]$assessment.MarkerHashVerification -ceq 'ProbeUnavailable') {
                'ProbeUnavailable'
            }
            else {
                'EvidenceConflict'
            }
        }
    }
    $receiptTime = Get-SetupCmMarkerValue `
        -InputObject $assessment -Name ReceiptTimeUtc
    [pscustomobject][ordered]@{
        MarkerHash = if ($route -ceq 'DirectAuthenticatedClientEvidence') {
            [string]$assessment.MarkerHash
        }
        else { '' }
        MarkerLength = if ($route -ceq 'DirectAuthenticatedClientEvidence') {
            [long]$assessment.MarkerLength
        }
        else { 0L }
        MarkerHashVerification = $route
        MarkerLastWriteTime = ''
        EvidenceReceiptTimeUtc = if ($receiptTime -is [datetime]) {
            ([datetime]$receiptTime).ToUniversalTime().ToString('o')
        }
        else { '' }
        EvidenceOwnerSid = [string](Get-SetupCmMarkerValue `
            -InputObject $assessment -Name OwnerSid)
        EvidenceReason = [string](Get-SetupCmMarkerValue `
            -InputObject $assessment -Name Reason)
    }
}
