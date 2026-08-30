function Get-SetupCmMarkerFixedContract {
    [CmdletBinding()]
    param()

    $sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../scripts/marker'))
    [ordered]@{
        SiteCode = 'LAB'
        SiteServerFqdn = 'LABZ1-CM01.test.gell.one'
        TargetFqdn = 'RING0IVY24-01.test.gell.one'
        TargetName = 'RING0IVY24-01'
        TargetResourceId = 16777219
        ApplicationName = 'Setup-CM Phase 1 Marker'
        ApplicationDescription = 'Required lab-only marker application for Phase 1 deployment-path acceptance.'
        ApplicationPublisher = 'Setup-CM'
        ApplicationVersion = '1.0.0'
        DeploymentTypeName = 'Install Setup-CM Phase 1 Marker'
        CollectionName = 'Setup-CM Phase 1 Marker - RING0IVY24-01 Only'
        LimitingCollectionId = 'SMS00001'
        ContentSource = 'C:\ProgramData\SetupCm\Phase1MarkerContent'
        ContentLocation = '\\LABZ1-CM01.test.gell.one\C$\ProgramData\SetupCm\Phase1MarkerContent\'
        SourceRoot = $sourceRoot
        MarkerPath = 'C:\ProgramData\SetupCm\Phase1\marker.json'
        MarkerHash = '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
        MarkerLength = 78
        PreviousDetectorFile = [ordered]@{
            Name = 'Test-SetupCmPhase1Marker.vbs'
            Length = 1310
            Hash = 'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
        }
        EvidenceChannel = [ordered]@{
            ShareName = 'SetupCmMarkerEvidence$'
            ShareDescription = 'Setup-CM LabZ1 marker evidence for RING0IVY24-01'
            LocalParent = 'C:\ProgramData\SetupCm\MarkerEvidence'
            LocalPath = 'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01'
            FileName = 'marker-evidence.json'
            UncPath = '\\LABZ1-CM01.test.gell.one\SetupCmMarkerEvidence$\marker-evidence.json'
            ComputerAccount = 'TEST\RING0IVY24-01$'
            SchemaVersion = 1
            VerificationMethod = 'CertUtilSha256Exact'
            MaximumBytes = 2048
            FreshnessMinutes = 30
            FutureToleranceMinutes = 2
            PollSeconds = 15
            ConvergenceSeconds = 900
        }
        ClientPolicy = [ordered]@{
            PublicationSettleSeconds = 60
            PublicationTimeoutSeconds = 300
            PublicationSnapshotTimeoutSeconds = 90
            PollSeconds = 5
            EvaluationSettleSeconds = 30
        }
        DetectorFile = [ordered]@{
            Name = 'Test-SetupCmPhase1Marker.vbs'
            Length = 4075
            Hash = '4C09CA514339B9C08277189C61B2DC74908309F0268856A3A4FAFD0CBB41F83C'
        }
        ContentFiles = @(
            [ordered]@{
                Name = 'Install-SetupCmPhase1Marker.ps1'; Length = 520
                Hash = 'AE7580DAFF7B567A647E2849776D8ABC95CA34FA79D61D9D1B8BB0D583B4A920'
            },
            [ordered]@{
                Name = 'Test-SetupCmPhase1Marker.ps1'; Length = 523
                Hash = 'E6F5BA49569FBEB3571584627DB3AB1B1BA940B4FE5146FB61595BF31A144FD7'
            },
            [ordered]@{
                Name = 'Uninstall-SetupCmPhase1Marker.ps1'; Length = 572
                Hash = '843D94C3DE2E29DAFD5EE82FADD344722FF5670BDB2F755B84277B12215E08AA'
            }
        )
        InstallCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-SetupCmPhase1Marker.ps1'
        UninstallCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall-SetupCmPhase1Marker.ps1'
    }
}

function Get-SetupCmMarkerValue {
    [CmdletBinding()]
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        $DefaultValue = $null
    )

    if ($null -eq $InputObject) { return $DefaultValue }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $DefaultValue
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function New-SetupCmMarkerComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Compliant', 'NotCompliant', 'Conflict')][string]$State,
        [Parameter(Mandatory)][string]$Reason,
        [hashtable]$Details = @{}
    )

    $component = [ordered]@{ Name = $Name; State = $State; Reason = $Reason }
    foreach ($key in $Details.Keys) {
        if ($key -notin 'Name', 'State', 'Reason') { $component[$key] = $Details[$key] }
    }
    [pscustomobject]$component
}

function New-SetupCmMarkerDesiredStateResult {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IEnumerable]$Components)

    $items = @($Components)
    $state = if (@($items | Where-Object State -eq 'Conflict').Count -gt 0) {
        'Conflict'
    }
    elseif (@($items | Where-Object State -eq 'NotCompliant').Count -gt 0) {
        'NotCompliant'
    }
    else {
        'Compliant'
    }
    [pscustomobject]@{ State = $state; Components = $items }
}

function Get-SetupCmMarkerSha256Text {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
        ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-SetupCmMarkerFileInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [string[]]$Names,
        [switch]$IncludeAllFiles
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
    $items = if ($IncludeAllFiles) {
        @(Get-ChildItem -LiteralPath $Root -File -Force)
    }
    else {
        @(foreach ($name in $Names) {
            $path = Join-Path $Root $name
            if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Item -LiteralPath $path -Force }
        })
    }
    @($items | ForEach-Object {
        @{
            Name = $_.Name
            Length = [long]$_.Length
            Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        }
    })
}

function Compare-SetupCmMarkerFileInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IEnumerable]$Actual,
        [Parameter(Mandatory)][System.Collections.IEnumerable]$Expected
    )

    $actualItems = @($Actual)
    $expectedItems = @($Expected)
    $missing = [System.Collections.Generic.List[string]]::new()
    $mismatched = [System.Collections.Generic.List[string]]::new()
    foreach ($expectedFile in $expectedItems) {
        $expectedName = [string](Get-SetupCmMarkerValue -InputObject $expectedFile -Name Name)
        $matchingFiles = @($actualItems | Where-Object {
            [string](Get-SetupCmMarkerValue -InputObject $_ -Name Name) -ceq $expectedName
        })
        if ($matchingFiles.Count -ne 1) {
            [void]$missing.Add($expectedName)
            continue
        }
        $actualFile = $matchingFiles[0]
        if ([long](Get-SetupCmMarkerValue -InputObject $actualFile -Name Length -DefaultValue -1) -ne
                [long](Get-SetupCmMarkerValue -InputObject $expectedFile -Name Length) -or
            [string](Get-SetupCmMarkerValue -InputObject $actualFile -Name Hash) -cne
                [string](Get-SetupCmMarkerValue -InputObject $expectedFile -Name Hash)) {
            [void]$mismatched.Add($expectedName)
        }
    }
    $expectedNames = @($expectedItems | ForEach-Object { [string](Get-SetupCmMarkerValue -InputObject $_ -Name Name) })
    $unexpected = @($actualItems | Where-Object {
        [string](Get-SetupCmMarkerValue -InputObject $_ -Name Name) -cnotin $expectedNames
    } | ForEach-Object { [string](Get-SetupCmMarkerValue -InputObject $_ -Name Name) })
    [pscustomobject]@{
        Exact = $missing.Count -eq 0 -and $mismatched.Count -eq 0 -and $unexpected.Count -eq 0
        Missing = @($missing)
        Mismatched = @($mismatched)
        Unexpected = $unexpected
    }
}

function ConvertTo-SetupCmMarkerComparablePath {
    [CmdletBinding()]
    param([AllowNull()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $Path.Trim().TrimEnd('\', '/')
}

function Test-SetupCmMarkerFixedConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)]$Contract
    )

    if (-not $Config.ContainsKey('markerAcceptance') -or
        -not [bool](Get-SetupCmMarkerValue -InputObject $Config.markerAcceptance -Name enabled -DefaultValue $false) -or
        -not [bool](Get-SetupCmMarkerValue -InputObject $Config.markerAcceptance -Name labOnly -DefaultValue $false) -or
        -not $Config.ContainsKey('safety') -or
        -not [bool](Get-SetupCmMarkerValue -InputObject $Config.safety -Name isolatedLab -DefaultValue $false)) {
        return 'Disabled'
    }

    $marker = $Config.markerAcceptance
    $fixed = [ordered]@{
        siteCode = $Contract.SiteCode
        siteServerFqdn = $Contract.SiteServerFqdn
        targetFqdn = $Contract.TargetFqdn
        targetResourceId = $Contract.TargetResourceId
    }
    foreach ($key in $fixed.Keys) {
        if ([string](Get-SetupCmMarkerValue -InputObject $marker -Name $key) -cne [string]$fixed[$key]) {
            return 'Mismatch'
        }
    }
    return 'Exact'
}

function Get-SetupCmMarkerDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [hashtable]$Providers,
        [Nullable[datetime]]$MinimumEvidenceReceiptUtc
    )

    $contract = Get-SetupCmMarkerFixedContract
    $components = [System.Collections.Generic.List[object]]::new()
    $configurationState = Test-SetupCmMarkerFixedConfiguration -Config $Config -Contract $contract
    if ($configurationState -eq 'Disabled') {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Boundary -State Conflict -Reason MarkerAcceptanceDisabled))
        return New-SetupCmMarkerDesiredStateResult -Components $components
    }
    if ($configurationState -ne 'Exact') {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Boundary -State Conflict -Reason ConfigurationBoundaryMismatch))
        return New-SetupCmMarkerDesiredStateResult -Components $components
    }
    if ($null -eq $Providers) { $Providers = Get-SetupCmMarkerDefaultProviders }

    try {
        $boundary = & $Providers.Boundary $Config $contract
        $targetResources = @(Get-SetupCmMarkerValue -InputObject $boundary -Name TargetResources -DefaultValue @())
        $target = $targetResources | Select-Object -First 1
        $boundaryExact =
            [string](Get-SetupCmMarkerValue -InputObject $boundary -Name HostFqdn) -ieq $contract.SiteServerFqdn -and
            [string](Get-SetupCmMarkerValue -InputObject $boundary -Name SiteCode) -ceq $contract.SiteCode -and
            [string](Get-SetupCmMarkerValue -InputObject $boundary -Name SiteServerFqdn) -ieq $contract.SiteServerFqdn -and
            [string](Get-SetupCmMarkerValue -InputObject $boundary -Name ProviderMachine) -ieq $contract.SiteServerFqdn -and
            [string](Get-SetupCmMarkerValue -InputObject $boundary -Name ResolvedTargetFqdn) -ieq $contract.TargetFqdn -and
            $targetResources.Count -eq 1 -and
            [string](Get-SetupCmMarkerValue -InputObject $target -Name Name) -ieq $contract.TargetName -and
            [int](Get-SetupCmMarkerValue -InputObject $target -Name ResourceId) -eq $contract.TargetResourceId -and
            [int](Get-SetupCmMarkerValue -InputObject $target -Name Active) -eq 1 -and
            [int](Get-SetupCmMarkerValue -InputObject $target -Name Obsolete) -eq 0 -and
            [int](Get-SetupCmMarkerValue -InputObject $target -Name Client) -eq 1
        if (-not $boundaryExact) {
            [void]$components.Add((New-SetupCmMarkerComponent -Name Boundary -State Conflict -Reason LiveBoundaryMismatch))
            return New-SetupCmMarkerDesiredStateResult -Components $components
        }
        [void]$components.Add((New-SetupCmMarkerComponent -Name Boundary -State Compliant -Reason Exact -Details @{
            SiteCode = $contract.SiteCode; SiteServerFqdn = $contract.SiteServerFqdn
            TargetFqdn = $contract.TargetFqdn; TargetResourceId = $contract.TargetResourceId
        }))
    }
    catch {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Boundary -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMarkerDesiredStateResult -Components $components
    }

    try {
        $source = & $Providers.SourcePayload $Config $contract
        $sourceFiles = Compare-SetupCmMarkerFileInventory `
            -Actual @(Get-SetupCmMarkerValue -InputObject $source -Name Files -DefaultValue @()) `
            -Expected $contract.ContentFiles
        $detector = Get-SetupCmMarkerValue -InputObject $source -Name Detector
        $detectorExact =
            [string](Get-SetupCmMarkerValue -InputObject $detector -Name Name) -ceq $contract.DetectorFile.Name -and
            [long](Get-SetupCmMarkerValue -InputObject $detector -Name Length -DefaultValue -1) -eq $contract.DetectorFile.Length -and
            [string](Get-SetupCmMarkerValue -InputObject $detector -Name Hash) -ceq $contract.DetectorFile.Hash
        if (-not $sourceFiles.Exact -or -not $detectorExact) {
            [void]$components.Add((New-SetupCmMarkerComponent -Name SourcePayload -State Conflict -Reason HashMismatch))
            return New-SetupCmMarkerDesiredStateResult -Components $components
        }
        [void]$components.Add((New-SetupCmMarkerComponent -Name SourcePayload -State Compliant -Reason Exact -Details @{
            DetectorHash = $contract.DetectorFile.Hash
            ContentHashes = @($contract.ContentFiles | ForEach-Object { $_.Hash })
        }))
    }
    catch {
        [void]$components.Add((New-SetupCmMarkerComponent -Name SourcePayload -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMarkerDesiredStateResult -Components $components
    }

    try {
        $content = & $Providers.ContentSource $Config $contract
        $contentComparison = Compare-SetupCmMarkerFileInventory `
            -Actual @(Get-SetupCmMarkerValue -InputObject $content -Name Files -DefaultValue @()) `
            -Expected $contract.ContentFiles
        if ($contentComparison.Unexpected.Count -gt 0) {
            [void]$components.Add((New-SetupCmMarkerComponent -Name ContentSource -State Conflict -Reason UnexpectedContentFile))
        }
        elseif (-not $contentComparison.Exact) {
            [void]$components.Add((New-SetupCmMarkerComponent -Name ContentSource -State NotCompliant -Reason OwnedContentDrift -Details @{
                Missing = $contentComparison.Missing; Mismatched = $contentComparison.Mismatched
            }))
        }
        else {
            [void]$components.Add((New-SetupCmMarkerComponent -Name ContentSource -State Compliant -Reason Exact -Details @{
                ContentHashes = @($contract.ContentFiles | ForEach-Object { $_.Hash })
            }))
        }
    }
    catch {
        [void]$components.Add((New-SetupCmMarkerComponent -Name ContentSource -State Conflict -Reason ProbeUnavailable))
    }

    $evidenceChannelInventory = $null
    try {
        $evidenceChannelInventory = & $Providers.EvidenceChannel $Config $contract
        $evidenceChannelAssessment = Get-SetupCmMarkerEvidenceChannelAssessment `
            -Contract $contract -Inventory $evidenceChannelInventory
        $evidenceChannelDetails = @{
            ShareName = [string]$contract.EvidenceChannel.ShareName
            LocalPath = [string]$contract.EvidenceChannel.LocalPath
            SchemaVersion = [int]$contract.EvidenceChannel.SchemaVersion
            TargetComputerSid = [string](Get-SetupCmMarkerValue `
                -InputObject $evidenceChannelInventory -Name TargetComputerSid)
        }
        [void]$components.Add((New-SetupCmMarkerComponent `
            -Name EvidenceChannel -State $evidenceChannelAssessment.State `
            -Reason $evidenceChannelAssessment.Reason `
            -Details $evidenceChannelDetails))
    }
    catch {
        [void]$components.Add((New-SetupCmMarkerComponent `
            -Name EvidenceChannel -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMarkerDesiredStateResult -Components $components
    }

    try {
        $inventory = & $Providers.Inventory $Config $contract `
            $evidenceChannelInventory $MinimumEvidenceReceiptUtc
    }
    catch {
        [void]$components.Add((New-SetupCmMarkerComponent -Name ProviderInventory -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMarkerDesiredStateResult -Components $components
    }

    $applications = @(Get-SetupCmMarkerValue -InputObject $inventory -Name Applications -DefaultValue @())
    $application = $applications | Select-Object -First 1
    if ($applications.Count -gt 1) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Application -State Conflict -Reason SameNameConflict))
    }
    elseif ($applications.Count -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Application -State NotCompliant -Reason Missing))
    }
    else {
        $appIdentityExact =
            [string](Get-SetupCmMarkerValue -InputObject $application -Name Name) -ceq $contract.ApplicationName -and
            [string](Get-SetupCmMarkerValue -InputObject $application -Name Publisher) -ceq $contract.ApplicationPublisher -and
            [string](Get-SetupCmMarkerValue -InputObject $application -Name Version) -ceq $contract.ApplicationVersion -and
            [bool](Get-SetupCmMarkerValue -InputObject $application -Name Enabled -DefaultValue $false) -and
            -not [bool](Get-SetupCmMarkerValue -InputObject $application -Name Expired -DefaultValue $true)
        if (-not $appIdentityExact) {
            [void]$components.Add((New-SetupCmMarkerComponent -Name Application -State Conflict -Reason SameNameIdentityMismatch))
        }
        else {
            [void]$components.Add((New-SetupCmMarkerComponent -Name Application -State Compliant -Reason Exact -Details @{
                CI_ID = [int](Get-SetupCmMarkerValue -InputObject $application -Name CI_ID)
                Revision = [int](Get-SetupCmMarkerValue -InputObject $application -Name Revision)
                ModelName = [string](Get-SetupCmMarkerValue -InputObject $application -Name ModelName)
            }))
        }
    }

    $deploymentTypes = @(Get-SetupCmMarkerValue -InputObject $inventory -Name DeploymentTypes -DefaultValue @())
    $deploymentType = $deploymentTypes | Select-Object -First 1
    if ($deploymentTypes.Count -gt 1) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name DeploymentType -State Conflict -Reason SameNameConflict))
    }
    elseif ($deploymentTypes.Count -eq 0) {
        $reason = if ($applications.Count -eq 0) { 'PendingApplication' } else { 'Missing' }
        [void]$components.Add((New-SetupCmMarkerComponent -Name DeploymentType -State NotCompliant -Reason $reason))
    }
    elseif ([string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name Name) -cne $contract.DeploymentTypeName -or
        [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name Technology) -cne 'Script') {
        [void]$components.Add((New-SetupCmMarkerComponent -Name DeploymentType -State Conflict -Reason SameNameIdentityMismatch))
    }
    else {
        $ownedPropertiesExact =
            [bool](Get-SetupCmMarkerValue -InputObject $deploymentType -Name Enabled -DefaultValue $false) -and
            (ConvertTo-SetupCmMarkerComparablePath -Path ([string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name ContentLocation))) -ieq
                (ConvertTo-SetupCmMarkerComparablePath -Path $contract.ContentLocation) -and
            [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name DetectionLanguage) -ieq 'VBScript' -and
            [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name InstallCommand) -ceq $contract.InstallCommand -and
            [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name UninstallCommand) -ceq $contract.UninstallCommand -and
            [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name ExecutionContext) -ceq 'System' -and
            [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name UserInteractionMode) -ceq 'Hidden' -and
            [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name RebootBehavior) -ceq 'NoAction' -and
            -not [string]::IsNullOrWhiteSpace([string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name ContentId)) -and
            -not [string]::IsNullOrWhiteSpace([string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name PackageId))
        $detectorHash = [string](Get-SetupCmMarkerValue `
            -InputObject $deploymentType -Name DetectorHash)
        $detectorLength = [long](Get-SetupCmMarkerValue `
            -InputObject $deploymentType -Name DetectorLength -DefaultValue -1L)
        $previousDetectorExact =
            $detectorHash -ceq [string]$contract.PreviousDetectorFile.Hash -and
            $detectorLength -eq [long]$contract.PreviousDetectorFile.Length
        $currentDetectorExact =
            $detectorHash -ceq [string]$contract.DetectorFile.Hash -and
            $detectorLength -eq [long]$contract.DetectorFile.Length
        if ($previousDetectorExact) {
            if ($ownedPropertiesExact) {
                [void]$components.Add((New-SetupCmMarkerComponent `
                    -Name DeploymentType -State NotCompliant `
                    -Reason ApprovedDetectorUpgrade))
            }
            else {
                [void]$components.Add((New-SetupCmMarkerComponent `
                    -Name DeploymentType -State Conflict `
                    -Reason DetectorUpgradeWithPropertyDrift))
            }
        }
        elseif (-not $currentDetectorExact) {
            [void]$components.Add((New-SetupCmMarkerComponent `
                -Name DeploymentType -State Conflict -Reason DetectorHashMismatch))
        }
        elseif (-not $ownedPropertiesExact) {
            [void]$components.Add((New-SetupCmMarkerComponent -Name DeploymentType -State NotCompliant -Reason OwnedPropertiesDrift))
        }
        else {
            [void]$components.Add((New-SetupCmMarkerComponent -Name DeploymentType -State Compliant -Reason Exact -Details @{
                CI_ID = [int](Get-SetupCmMarkerValue -InputObject $deploymentType -Name CI_ID)
                Revision = [int](Get-SetupCmMarkerValue -InputObject $deploymentType -Name Revision)
                ModelName = [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name ModelName)
                ContentId = [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name ContentId)
                PackageId = [string](Get-SetupCmMarkerValue -InputObject $deploymentType -Name PackageId)
                DetectorHash = $contract.DetectorFile.Hash
            }))
        }
    }

    $distributions = @(Get-SetupCmMarkerValue -InputObject $inventory -Name Distributions -DefaultValue @())
    if ($deploymentTypes.Count -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Distribution -State NotCompliant -Reason PendingDeploymentType))
    }
    elseif (@($distributions | Where-Object {
        [string](Get-SetupCmMarkerValue -InputObject $_ -Name DistributionPoint) -ine $contract.SiteServerFqdn
    }).Count -gt 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Distribution -State Conflict -Reason UnexpectedDistributionPoint))
    }
    elseif ($distributions.Count -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Distribution -State NotCompliant -Reason Missing))
    }
    elseif ($distributions.Count -ne 1 -or
        [string](Get-SetupCmMarkerValue -InputObject $distributions[0] -Name State) -cne 'Success' -or
        [int](Get-SetupCmMarkerValue -InputObject $distributions[0] -Name Success -DefaultValue 0) -ne 1 -or
        [int](Get-SetupCmMarkerValue -InputObject $distributions[0] -Name Errors -DefaultValue 0) -ne 0 -or
        [int](Get-SetupCmMarkerValue -InputObject $distributions[0] -Name InProgress -DefaultValue 0) -ne 0 -or
        [int](Get-SetupCmMarkerValue -InputObject $distributions[0] -Name Unknown -DefaultValue 0) -ne 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Distribution -State NotCompliant -Reason DistributionNotReady))
    }
    else {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Distribution -State Compliant -Reason Exact -Details @{
            PackageId = [string](Get-SetupCmMarkerValue -InputObject $distributions[0] -Name PackageId)
            DistributionPoint = $contract.SiteServerFqdn; Success = 1; Errors = 0; InProgress = 0; Unknown = 0
        }))
    }

    $collections = @(Get-SetupCmMarkerValue -InputObject $inventory -Name Collections -DefaultValue @())
    $collection = $collections | Select-Object -First 1
    $collectionId = [string](Get-SetupCmMarkerValue -InputObject $collection -Name CollectionId)
    if ($collections.Count -gt 1) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Collection -State Conflict -Reason SameNameConflict))
    }
    elseif ($collections.Count -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Collection -State NotCompliant -Reason Missing))
    }
    elseif ([string](Get-SetupCmMarkerValue -InputObject $collection -Name Name) -cne $contract.CollectionName -or
        [int](Get-SetupCmMarkerValue -InputObject $collection -Name Type) -ne 2 -or
        [string](Get-SetupCmMarkerValue -InputObject $collection -Name LimitingCollectionId) -cne $contract.LimitingCollectionId) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Collection -State Conflict -Reason SameNameIdentityMismatch))
    }
    else {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Collection -State Compliant -Reason Exact -Details @{
            CollectionId = $collectionId
        }))
    }

    $directRules = @(Get-SetupCmMarkerValue -InputObject $inventory -Name DirectRules -DefaultValue @())
    $otherRules = @(Get-SetupCmMarkerValue -InputObject $inventory -Name OtherRules -DefaultValue @())
    $members = @(Get-SetupCmMarkerValue -InputObject $inventory -Name Members -DefaultValue @())
    $memberCount = [int](Get-SetupCmMarkerValue -InputObject $collection -Name MemberCount -DefaultValue $members.Count)
    $unexpectedDirect = @($directRules | Where-Object {
        [int](Get-SetupCmMarkerValue -InputObject $_ -Name ResourceId) -ne $contract.TargetResourceId -or
        [string](Get-SetupCmMarkerValue -InputObject $_ -Name RuleName) -ine $contract.TargetName
    })
    $unexpectedMembers = @($members | Where-Object {
        [int](Get-SetupCmMarkerValue -InputObject $_ -Name ResourceId) -ne $contract.TargetResourceId -or
        [string](Get-SetupCmMarkerValue -InputObject $_ -Name Name) -ine $contract.TargetName
    })
    if ($collections.Count -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Membership -State NotCompliant -Reason PendingCollection))
    }
    elseif ($otherRules.Count -gt 0 -or $unexpectedDirect.Count -gt 0 -or $unexpectedMembers.Count -gt 0 -or
        $directRules.Count -gt 1 -or $members.Count -gt 1 -or $memberCount -gt 1) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Membership -State Conflict -Reason BroadOrUnexpectedMembership))
    }
    elseif ($directRules.Count -eq 0 -and $members.Count -eq 0 -and $memberCount -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Membership -State NotCompliant -Reason MissingDirectRule))
    }
    elseif ($directRules.Count -ne 1 -or $members.Count -ne 1 -or $memberCount -ne 1) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Membership -State NotCompliant -Reason RefreshRequired))
    }
    else {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Membership -State Compliant -Reason Exact -Details @{
            CollectionId = $collectionId; MemberName = $contract.TargetName; MemberResourceId = $contract.TargetResourceId
            DirectRuleCount = 1; MemberCount = 1
        }))
    }

    $assignments = @(Get-SetupCmMarkerValue -InputObject $inventory -Name Assignments -DefaultValue @())
    $assignment = $assignments | Select-Object -First 1
    $wrongAssignments = @($assignments | Where-Object {
        [string](Get-SetupCmMarkerValue -InputObject $_ -Name TargetCollectionId) -cne $collectionId
    })
    if ($wrongAssignments.Count -gt 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Assignment -State Conflict -Reason AssignmentScopeConflict))
    }
    elseif ($assignments.Count -gt 1) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Assignment -State Conflict -Reason DuplicateAssignment))
    }
    elseif ($assignments.Count -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Assignment -State NotCompliant -Reason Missing))
    }
    elseif ([int](Get-SetupCmMarkerValue -InputObject $assignment -Name DesiredConfigType) -ne 1 -or
        [int](Get-SetupCmMarkerValue -InputObject $assignment -Name OfferTypeId) -ne 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Assignment -State Conflict -Reason PurposeConflict))
    }
    elseif (-not [bool](Get-SetupCmMarkerValue -InputObject $assignment -Name Enabled -DefaultValue $false)) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Assignment -State Conflict -Reason DisabledAssignmentRequiresOperator))
    }
    elseif (-not [bool](Get-SetupCmMarkerValue -InputObject $assignment -Name NotifyUser -DefaultValue $false) -or
        -not [bool](Get-SetupCmMarkerValue -InputObject $assignment -Name UserUIExperience -DefaultValue $false)) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Assignment -State NotCompliant -Reason OwnedPropertiesDrift))
    }
    else {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Assignment -State Compliant -Reason Exact -Details @{
            AssignmentId = [int](Get-SetupCmMarkerValue -InputObject $assignment -Name AssignmentId)
            TargetCollectionId = $collectionId; Purpose = 'Required'; Intent = 'Install'; Visible = $true
            PolicyRevision = [string](Get-SetupCmMarkerValue -InputObject $assignment -Name PolicyRevision)
        }))
    }

    $client = Get-SetupCmMarkerValue -InputObject $inventory -Name Client
    $markerHashVerification = [string](Get-SetupCmMarkerValue -InputObject $client -Name MarkerHashVerification)
    $successfulClientProof = $markerHashVerification -cin @(
        'DirectAuthenticatedFileRead',
        'DirectAuthenticatedClientEvidence'
    )
    $clientEvidenceDetails = @{
        MarkerHash = [string](Get-SetupCmMarkerValue `
            -InputObject $client -Name MarkerHash)
        MarkerLength = [long](Get-SetupCmMarkerValue `
            -InputObject $client -Name MarkerLength -DefaultValue 0L)
        MarkerHashVerification = $markerHashVerification
        EvidenceReceiptTimeUtc = [string](Get-SetupCmMarkerValue `
            -InputObject $client -Name EvidenceReceiptTimeUtc)
        EvidenceOwnerSid = [string](Get-SetupCmMarkerValue `
            -InputObject $client -Name EvidenceOwnerSid)
        EvidenceReason = [string](Get-SetupCmMarkerValue `
            -InputObject $client -Name EvidenceReason)
    }
    $clientExact = $null -ne $client -and
        [string](Get-SetupCmMarkerValue -InputObject $client -Name Name) -ieq $contract.TargetName -and
        [int](Get-SetupCmMarkerValue -InputObject $client -Name ResourceId) -eq $contract.TargetResourceId -and
        [string](Get-SetupCmMarkerValue -InputObject $client -Name MarkerHash) -ceq $contract.MarkerHash -and
        [long](Get-SetupCmMarkerValue -InputObject $client -Name MarkerLength -DefaultValue -1L) -eq
            [long]$contract.MarkerLength -and
        $successfulClientProof -and
        [string](Get-SetupCmMarkerValue -InputObject $client -Name InstallState) -ceq 'Installed' -and
        [int](Get-SetupCmMarkerValue -InputObject $client -Name EvaluationState) -eq 1 -and
        [string](Get-SetupCmMarkerValue -InputObject $client -Name ResolvedState) -ceq 'Installed' -and
        [int](Get-SetupCmMarkerValue -InputObject $client -Name ExitCode) -eq 0 -and
        [string](Get-SetupCmMarkerValue -InputObject $client -Name ExecutionContext) -ceq 'System' -and
        [string](Get-SetupCmMarkerValue -InputObject $client -Name SelectedDistributionPoint) -ieq $contract.SiteServerFqdn -and
        [string](Get-SetupCmMarkerValue -InputObject $client -Name ContentDownload) -ceq 'Verified' -and
        @((Get-SetupCmMarkerValue -InputObject $client -Name StateMessages -DefaultValue @()) | Where-Object {
            $_ -in 'APP_CI_PRESENT', 'APP_CI_ENFORCEMENT_SUCCEEDED'
        }).Count -gt 0
    if ($assignments.Count -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Client -State NotCompliant -Reason PendingDeployment))
    }
    elseif ($null -ne $client -and $markerHashVerification -ceq 'ProbeUnavailable') {
        [void]$components.Add((New-SetupCmMarkerComponent `
            -Name Client -State Conflict -Reason ClientProbeUnavailable `
            -Details $clientEvidenceDetails))
    }
    elseif ($null -ne $client -and $markerHashVerification -ceq 'EvidenceConflict') {
        [void]$components.Add((New-SetupCmMarkerComponent `
            -Name Client -State Conflict -Reason ClientEvidenceConflict `
            -Details $clientEvidenceDetails))
    }
    elseif ($null -ne $client -and $markerHashVerification -ceq 'ClientEvidencePending') {
        [void]$components.Add((New-SetupCmMarkerComponent `
            -Name Client -State NotCompliant -Reason ClientEvidencePending `
            -Details $clientEvidenceDetails))
    }
    elseif (-not $clientExact) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Client -State NotCompliant -Reason ClientNotCompliant))
    }
    else {
        [void]$components.Add((New-SetupCmMarkerComponent -Name Client -State Compliant -Reason Exact -Details @{
            ClientName = $contract.TargetName; ResourceId = $contract.TargetResourceId
            MarkerHash = $contract.MarkerHash
            MarkerLength = [long](Get-SetupCmMarkerValue -InputObject $client -Name MarkerLength -DefaultValue 0L)
            MarkerHashVerification = $markerHashVerification
            MarkerLastWriteTime = [string](Get-SetupCmMarkerValue -InputObject $client -Name MarkerLastWriteTime)
            EvidenceReceiptTimeUtc = [string](Get-SetupCmMarkerValue `
                -InputObject $client -Name EvidenceReceiptTimeUtc)
            EvidenceOwnerSid = [string](Get-SetupCmMarkerValue `
                -InputObject $client -Name EvidenceOwnerSid)
            InstallState = 'Installed'; EvaluationState = 1; ResolvedState = 'Installed'; ExitCode = 0
            ExecutionContext = 'System'; SelectedDistributionPoint = $contract.SiteServerFqdn
            ContentDownload = 'Verified'; StateMessages = @(Get-SetupCmMarkerValue -InputObject $client -Name StateMessages)
        }))
    }

    $serverRows = @(Get-SetupCmMarkerValue -InputObject $inventory -Name ServerCompliance -DefaultValue @())
    $serverRow = $serverRows | Select-Object -First 1
    $unexpectedServerRows = @($serverRows | Where-Object {
        [string](Get-SetupCmMarkerValue -InputObject $_ -Name MachineName) -ine $contract.TargetName -or
        [int](Get-SetupCmMarkerValue -InputObject $_ -Name MachineId) -ne $contract.TargetResourceId -or
        [string](Get-SetupCmMarkerValue -InputObject $_ -Name CollectionId) -cne $collectionId
    })
    if ($unexpectedServerRows.Count -gt 0 -or $serverRows.Count -gt 1) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name ServerCompliance -State Conflict -Reason TargetIdentityMismatch))
    }
    elseif ($serverRows.Count -eq 0) {
        [void]$components.Add((New-SetupCmMarkerComponent -Name ServerCompliance -State NotCompliant -Reason Missing))
    }
    else {
        $serverExact =
            [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name AppCI) -eq [int](Get-SetupCmMarkerValue -InputObject $application -Name CI_ID) -and
            [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name DTCI) -eq [int](Get-SetupCmMarkerValue -InputObject $deploymentType -Name CI_ID) -and
            [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name ComplianceState) -eq 1 -and
            [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name EnforcementState) -in 1000, 1001 -and
            [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name InstalledState) -eq 2 -and
            [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name Revision) -eq [int](Get-SetupCmMarkerValue -InputObject $application -Name Revision)
        if (-not $serverExact) {
            [void]$components.Add((New-SetupCmMarkerComponent -Name ServerCompliance -State NotCompliant -Reason ClientStatePending))
        }
        else {
            [void]$components.Add((New-SetupCmMarkerComponent -Name ServerCompliance -State Compliant -Reason Exact -Details @{
                AssignmentId = [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name AssignmentId)
                MachineName = $contract.TargetName; MachineId = $contract.TargetResourceId; CollectionId = $collectionId
                AppCI = [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name AppCI)
                DTCI = [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name DTCI)
                ComplianceState = 1; EnforcementState = [int](Get-SetupCmMarkerValue -InputObject $serverRow -Name EnforcementState)
                InstalledState = 2
            }))
        }
    }

    New-SetupCmMarkerDesiredStateResult -Components $components
}

function Test-SetupCmMarkerDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [hashtable]$Providers,
        [Nullable[datetime]]$MinimumEvidenceReceiptUtc,
        [switch]$PassThru
    )

    $state = Get-SetupCmMarkerDesiredState -Config $Config -Providers $Providers `
        -MinimumEvidenceReceiptUtc $MinimumEvidenceReceiptUtc
    $evidence = [ordered]@{
        evaluatedAt = (Get-Date).ToUniversalTime().ToString('o')
        state = $state.State
        components = @($state.Components | Sort-Object Name)
    }
    $runPath = Join-Path $EvidenceRoot 'run.json'
    if (Test-Path -LiteralPath $runPath -PathType Leaf) {
        $run = Get-Content -LiteralPath $runPath -Raw | ConvertFrom-Json
        if ($null -ne $run.PSObject.Properties['sourceCommit']) { $evidence.sourceCommit = [string]$run.sourceCommit }
    }
    Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'marker-state' -Value $evidence | Out-Null
    if ($PassThru) { return $state }
    return [string]$state.State
}

function Invoke-SetupCmMarkerProviderAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Providers,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)]$Contract,
        [object[]]$Arguments = @()
    )

    if (-not $Providers.ContainsKey($Name) -or $null -eq $Providers[$Name]) {
        throw "Marker repair provider '$Name' is unavailable."
    }
    & $Providers[$Name] $Config $Contract @Arguments
}

function Get-SetupCmMarkerPolicyPublicationSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Contract,
        [Parameter(Mandatory)]
        [ValidateRange(1, 300000)]
        [int]$TimeoutMilliseconds,
        [scriptblock]$ProcessProvider = {
            param($EncodedCommand, $ProcessTimeoutMilliseconds)

            $powerShellPath = Join-Path $PSHOME 'pwsh.exe'
            if (-not [IO.File]::Exists($powerShellPath)) {
                throw 'PowerShell is unavailable for the isolated marker policy snapshot.'
            }
            $startInfo = [Diagnostics.ProcessStartInfo]::new()
            $startInfo.FileName = $powerShellPath
            $startInfo.ArgumentList.Add('-NoLogo')
            $startInfo.ArgumentList.Add('-NoProfile')
            $startInfo.ArgumentList.Add('-NonInteractive')
            $startInfo.ArgumentList.Add('-EncodedCommand')
            $startInfo.ArgumentList.Add($EncodedCommand)
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true

            $process = [Diagnostics.Process]::new()
            $process.StartInfo = $startInfo
            try {
                if (-not $process.Start()) {
                    throw 'The isolated marker policy snapshot did not start.'
                }
                $stdoutTask = $process.StandardOutput.ReadToEndAsync()
                $stderrTask = $process.StandardError.ReadToEndAsync()
                if (-not $process.WaitForExit($ProcessTimeoutMilliseconds)) {
                    $process.Kill($true)
                    $process.WaitForExit()
                    [void]$stdoutTask.GetAwaiter().GetResult()
                    [void]$stderrTask.GetAwaiter().GetResult()
                    throw 'The isolated marker policy snapshot timed out.'
                }
                $stdout = $stdoutTask.GetAwaiter().GetResult().Trim()
                [void]$stderrTask.GetAwaiter().GetResult()
                if ($process.ExitCode -ne 0) {
                    throw 'The isolated marker policy snapshot failed.'
                }
                return $stdout
            }
            finally {
                $process.Dispose()
            }
        }
    )

    $fixedContract = Get-SetupCmMarkerFixedContract
    foreach ($propertyName in 'SiteCode', 'ApplicationName', 'CollectionName') {
        $actual = [string](Get-SetupCmMarkerValue `
            -InputObject $Contract -Name $propertyName)
        $expected = [string](Get-SetupCmMarkerValue `
            -InputObject $fixedContract -Name $propertyName)
        if ($actual -cne $expected) {
            throw 'The marker policy snapshot requires the fixed lab-only contract.'
        }
    }

    $payloadJson = [ordered]@{
        SiteCode = [string]$Contract.SiteCode
        ApplicationName = [string]$Contract.ApplicationName
        CollectionName = [string]$Contract.CollectionName
    } | ConvertTo-Json -Compress
    $payload = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes($payloadJson)
    )
    $childScript = @'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
if (-not $IsWindows) {
    throw 'Marker policy snapshots require Windows on the accepted site server.'
}
$payloadJson = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('__MARKER_POLICY_PAYLOAD__')
)
$payload = $payloadJson | ConvertFrom-Json -ErrorAction Stop
$siteCode = [string]$payload.SiteCode
$applicationName = [string]$payload.ApplicationName
$collectionName = [string]$payload.CollectionName
if ($siteCode -cne 'LAB' -or
    $applicationName -cne 'Setup-CM Phase 1 Marker' -or
    $collectionName -cne 'Setup-CM Phase 1 Marker - RING0IVY24-01 Only') {
    throw 'The marker policy snapshot payload is outside the fixed lab boundary.'
}
if ([string]::IsNullOrWhiteSpace($env:SMS_ADMIN_UI_PATH)) {
    throw 'SMS_ADMIN_UI_PATH is required to locate the ConfigurationManager module.'
}
$modulePath = Join-Path $env:SMS_ADMIN_UI_PATH '..\ConfigurationManager.psd1'
Import-Module $modulePath -Force -ErrorAction Stop
$provider = Get-CimInstance -Namespace 'root\SMS' `
    -ClassName SMS_ProviderLocation -ErrorAction Stop |
    Where-Object {
        [bool]$_.ProviderForLocalSite -and [string]$_.SiteCode -ieq $siteCode
    } |
    Select-Object -First 1
if ($null -eq $provider) {
    throw "No local SMS Provider exists for site $siteCode."
}
$drive = Get-PSDrive -Name $siteCode -PSProvider CMSite `
    -ErrorAction SilentlyContinue
if ($null -eq $drive) {
    New-PSDrive -Name $siteCode -PSProvider CMSite `
        -Root ([string]$provider.Machine) | Out-Null
}
elseif ([string]$drive.Root -ine [string]$provider.Machine) {
    throw "The existing $siteCode CMSite drive targets a different provider."
}

Push-Location ($siteCode + ':')
try {
    $namespace = "root\SMS\site_$siteCode"
    $applications = @(Get-CMApplication -Name $applicationName `
        -Fast -ErrorAction Stop)
    $assignments = @(Get-CMApplicationDeployment -Name $applicationName `
        -ErrorAction Stop)
    $escapedCollectionName = $collectionName.Replace("'", "''")
    $collections = @(Get-CimInstance -Namespace $namespace `
        -ClassName SMS_Collection -Filter "Name = '$escapedCollectionName'" `
        -ErrorAction Stop)
    $application = $applications | Select-Object -First 1
    $assignment = $assignments | Select-Object -First 1
    $collection = $collections | Select-Object -First 1
    $assignmentRevision = if ($null -eq $assignment) {
        0
    }
    else {
        [int](([string]$assignment.AssignedCI_UniqueID -split '/')[-1])
    }
    $assignmentCollectionName = if (
        $collections.Count -eq 1 -and
        $null -ne $assignment -and
        [string]$assignment.TargetCollectionID -ceq `
            [string]$collection.CollectionID
    ) {
        $collectionName
    }
    else { '' }

    [pscustomobject][ordered]@{
        ApplicationCount = $applications.Count
        AssignmentCount = $assignments.Count
        ApplicationIdentity = if ($null -eq $application) {
            ''
        }
        else { [string]$application.ModelName }
        AssignmentIdentity = if ($null -eq $assignment) {
            ''
        }
        else { [string]$assignment.AssignmentID }
        ApplicationRevision = if ($null -eq $application) {
            0
        }
        else { [int]$application.CIVersion }
        AssignmentRevision = $assignmentRevision
        ApplicationLastModifiedUtc = if ($null -eq $application) {
            $null
        }
        else {
            ([datetime]$application.DateLastModified).ToUniversalTime().ToString('o')
        }
        AssignmentCollectionName = $assignmentCollectionName
    } | ConvertTo-Json -Compress
}
finally {
    Pop-Location
}
'@.Replace('__MARKER_POLICY_PAYLOAD__', $payload)
    $encodedCommand = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($childScript)
    )
    $rawResult = [string](& $ProcessProvider $encodedCommand $TimeoutMilliseconds)
    if ([string]::IsNullOrWhiteSpace($rawResult) -or $rawResult.Length -gt 4096) {
        throw 'The isolated marker policy snapshot returned invalid output.'
    }
    try {
        $result = $rawResult | ConvertFrom-Json -ErrorAction Stop
        if ($result -is [array]) {
            throw 'Array output is not accepted.'
        }
        foreach ($propertyName in @(
                'ApplicationCount',
                'AssignmentCount',
                'ApplicationIdentity',
                'AssignmentIdentity',
                'ApplicationRevision',
                'AssignmentRevision',
                'ApplicationLastModifiedUtc',
                'AssignmentCollectionName'
            )) {
            if ($null -eq $result.PSObject.Properties[$propertyName]) {
                throw "Missing snapshot property $propertyName."
            }
        }
        $snapshot = [pscustomobject][ordered]@{
            ApplicationCount = [int]$result.ApplicationCount
            AssignmentCount = [int]$result.AssignmentCount
            ApplicationIdentity = [string]$result.ApplicationIdentity
            AssignmentIdentity = [string]$result.AssignmentIdentity
            ApplicationRevision = [int]$result.ApplicationRevision
            AssignmentRevision = [int]$result.AssignmentRevision
            ApplicationLastModifiedUtc = $result.ApplicationLastModifiedUtc
            AssignmentCollectionName = [string]$result.AssignmentCollectionName
        }
    }
    catch {
        throw 'The isolated marker policy snapshot returned invalid output.'
    }
    return $snapshot
}

function Wait-SetupCmMarkerPolicyPublication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Contract,
        [Parameter(Mandatory)][scriptblock]$SnapshotProvider,
        [scriptblock]$UtcNowProvider = {
            (Get-Date).ToUniversalTime()
        },
        [scriptblock]$DelayProvider = {
            param($Seconds)
            Start-Sleep -Seconds $Seconds
        }
    )

    $startedAt = ([datetime](& $UtcNowProvider)).ToUniversalTime()
    $deadline = $startedAt.AddSeconds(
        [int]$Contract.ClientPolicy.PublicationTimeoutSeconds)
    $expectedApplicationIdentity = ''
    $expectedAssignmentIdentity = ''
    $stableKey = ''
    $stableSinceUtc = $null
    while ($true) {
        $snapshotStartedAt = ([datetime](& $UtcNowProvider)).ToUniversalTime()
        if ($snapshotStartedAt -ge $deadline) {
            throw "Marker policy publication timed out after $($Contract.ClientPolicy.PublicationTimeoutSeconds) seconds."
        }
        $remainingMilliseconds = [int][Math]::Max(
            1,
            [Math]::Min(
                [int]$Contract.ClientPolicy.PublicationSnapshotTimeoutSeconds * 1000,
                [Math]::Ceiling(
                    ($deadline - $snapshotStartedAt).TotalMilliseconds
                )
            )
        )
        $snapshot = & $SnapshotProvider $remainingMilliseconds
        $now = ([datetime](& $UtcNowProvider)).ToUniversalTime()
        if ($now -ge $deadline) {
            throw "Marker policy publication timed out after $($Contract.ClientPolicy.PublicationTimeoutSeconds) seconds."
        }
        $applicationCount = [int](Get-SetupCmMarkerValue `
            -InputObject $snapshot -Name ApplicationCount -DefaultValue 0)
        $assignmentCount = [int](Get-SetupCmMarkerValue `
            -InputObject $snapshot -Name AssignmentCount -DefaultValue 0)
        if ($applicationCount -ne 1 -or $assignmentCount -ne 1) {
            throw 'Marker policy publication identity changed while waiting.'
        }

        $assignmentCollectionName = [string](Get-SetupCmMarkerValue `
            -InputObject $snapshot -Name AssignmentCollectionName)
        if ($assignmentCollectionName -cne [string]$Contract.CollectionName) {
            throw 'Marker policy publication assignment scope changed while waiting.'
        }

        $applicationIdentity = [string](Get-SetupCmMarkerValue `
            -InputObject $snapshot -Name ApplicationIdentity)
        $assignmentIdentity = [string](Get-SetupCmMarkerValue `
            -InputObject $snapshot -Name AssignmentIdentity)
        if ([string]::IsNullOrWhiteSpace($applicationIdentity) -or
            [string]::IsNullOrWhiteSpace($assignmentIdentity)) {
            throw 'Marker policy publication object identity is unavailable.'
        }
        if ([string]::IsNullOrEmpty($expectedApplicationIdentity)) {
            $expectedApplicationIdentity = $applicationIdentity
            $expectedAssignmentIdentity = $assignmentIdentity
        }
        elseif ($applicationIdentity -cne $expectedApplicationIdentity -or
            $assignmentIdentity -cne $expectedAssignmentIdentity) {
            throw 'Marker policy publication object identity changed while waiting.'
        }

        $applicationRevision = [int](Get-SetupCmMarkerValue `
            -InputObject $snapshot -Name ApplicationRevision -DefaultValue 0)
        $assignmentRevision = [int](Get-SetupCmMarkerValue `
            -InputObject $snapshot -Name AssignmentRevision -DefaultValue 0)
        $lastModifiedValue = Get-SetupCmMarkerValue `
            -InputObject $snapshot -Name ApplicationLastModifiedUtc
        if ($applicationRevision -le 0 -or $null -eq $lastModifiedValue) {
            throw 'Marker policy publication metadata is unavailable.'
        }
        try {
            $lastModifiedUtc = ([datetime]$lastModifiedValue).ToUniversalTime()
        }
        catch {
            throw 'Marker policy publication metadata is invalid.'
        }

        if ($assignmentRevision -eq $applicationRevision) {
            $currentStableKey = '{0}|{1}|{2}|{3}|{4}|{5}' -f
                $applicationIdentity,
                $assignmentIdentity,
                $applicationRevision,
                $assignmentRevision,
                $lastModifiedUtc.ToString('o'),
                $assignmentCollectionName
            if ($currentStableKey -cne $stableKey) {
                $stableKey = $currentStableKey
                $stableSinceUtc = $now
            }
            $settledAt = ([datetime]$stableSinceUtc).AddSeconds(
                [int]$Contract.ClientPolicy.PublicationSettleSeconds)
            if ($now -ge $settledAt) { return $snapshot }
        }
        else {
            $stableKey = ''
            $stableSinceUtc = $null
        }
        & $DelayProvider ([int]$Contract.ClientPolicy.PollSeconds)
    }
}

function Invoke-SetupCmMarkerClientPolicyEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Contract,
        [Parameter(Mandatory)][scriptblock]$MachinePolicyProvider,
        [Parameter(Mandatory)][scriptblock]$ApplicationEvaluationProvider,
        [scriptblock]$UtcNowProvider = {
            (Get-Date).ToUniversalTime()
        },
        [scriptblock]$DelayProvider = {
            param($Seconds)
            Start-Sleep -Seconds $Seconds
        }
    )

    & $MachinePolicyProvider | Out-Null
    $minimumEvidenceReceiptUtc = `
        ([datetime](& $UtcNowProvider)).ToUniversalTime()
    & $DelayProvider ([int]$Contract.ClientPolicy.EvaluationSettleSeconds)
    & $ApplicationEvaluationProvider | Out-Null
    return $minimumEvidenceReceiptUtc
}

function Wait-SetupCmMarkerConvergence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)]$Contract,
        [Parameter(Mandatory)][datetime]$MinimumEvidenceReceiptUtc,
        [hashtable]$Providers,
        [scriptblock]$StateProvider,
        [scriptblock]$UtcNowProvider = {
            (Get-Date).ToUniversalTime()
        },
        [scriptblock]$DelayProvider = {
            param($Seconds)
            Start-Sleep -Seconds $Seconds
        }
    )

    if ($null -eq $Providers) { $Providers = Get-SetupCmMarkerDefaultProviders }
    if ($null -eq $StateProvider) {
        $StateProvider = {
            param(
                $StateConfig,
                $StateContract,
                $StateMinimumReceiptUtc,
                $StateProviders
            )
            Get-SetupCmMarkerDesiredState -Config $StateConfig `
                -Providers $StateProviders `
                -MinimumEvidenceReceiptUtc $StateMinimumReceiptUtc
        }
    }

    $startedAt = ([datetime](& $UtcNowProvider)).ToUniversalTime()
    $deadline = $startedAt.AddSeconds(
        [int]$Contract.EvidenceChannel.ConvergenceSeconds)
    while ($true) {
        $state = & $StateProvider $Config $Contract `
            $MinimumEvidenceReceiptUtc $Providers
        if ([string]$state.State -ceq 'Compliant') { return $state }
        if ([string]$state.State -ceq 'Conflict') {
            throw 'Marker convergence encountered a safety conflict.'
        }

        $now = ([datetime](& $UtcNowProvider)).ToUniversalTime()
        if ($now -ge $deadline) {
            throw "Marker convergence timed out after $($Contract.EvidenceChannel.ConvergenceSeconds) seconds."
        }
        & $DelayProvider ([int]$Contract.EvidenceChannel.PollSeconds)
    }
}

function Repair-SetupCmMarkerDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)]$State,
        [string]$EvidenceRoot,
        [hashtable]$Providers
    )

    if ($State.State -eq 'Conflict' -or @($State.Components | Where-Object State -eq 'Conflict').Count -gt 0) {
        throw 'Marker acceptance has a safety conflict; no repair was attempted.'
    }
    foreach ($requiredComponent in 'Boundary', 'SourcePayload') {
        $component = $State.Components | Where-Object Name -eq $requiredComponent | Select-Object -First 1
        if ($null -eq $component -or $component.State -ne 'Compliant') {
            throw "Marker repair requires a compliant $requiredComponent preflight."
        }
    }
    if ($null -eq $Providers) { $Providers = Get-SetupCmMarkerDefaultProviders }
    $contract = Get-SetupCmMarkerFixedContract
    $contentChanged = $false
    $deploymentTypeChanged = $false
    $detectorPolicyChanged = $false
    $deploymentCreated = $false
    $evidenceChannelChanged = $false

    $evidenceChannel = $State.Components |
        Where-Object Name -eq EvidenceChannel | Select-Object -First 1
    if ($null -eq $evidenceChannel) {
        throw 'Marker repair requires an EvidenceChannel component.'
    }
    if ($evidenceChannel.State -eq 'NotCompliant') {
        if ($evidenceChannel.Reason -notin 'Missing', 'IncompleteOwnedChannel') {
            throw 'Marker evidence channel is not safely repairable.'
        }
        Invoke-SetupCmMarkerProviderAction -Providers $Providers `
            -Name CreateEvidenceChannel -Config $Config -Contract $contract
        $evidenceChannelChanged = $true
    }

    $content = $State.Components | Where-Object Name -eq ContentSource | Select-Object -First 1
    if ($content.State -eq 'NotCompliant') {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name SyncContent -Config $Config -Contract $contract
        $contentChanged = $true
    }

    $application = $State.Components | Where-Object Name -eq Application | Select-Object -First 1
    if ($application.State -eq 'NotCompliant') {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name CreateApplication -Config $Config -Contract $contract
    }

    $deploymentType = $State.Components | Where-Object Name -eq DeploymentType | Select-Object -First 1
    if ($deploymentType.State -eq 'NotCompliant' -and
        $deploymentType.Reason -in 'Missing', 'PendingApplication') {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name CreateDeploymentType -Config $Config -Contract $contract
        $deploymentTypeChanged = $true
    }
    elseif ($deploymentType.State -eq 'NotCompliant' -and
        $deploymentType.Reason -eq 'ApprovedDetectorUpgrade' -and
        -not $contentChanged) {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers `
            -Name UpdateDetectorPolicy -Config $Config -Contract $contract
        $detectorPolicyChanged = $true
    }
    elseif ($deploymentType.State -eq 'NotCompliant' -or $contentChanged) {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name UpdateDeploymentType -Config $Config -Contract $contract
        $deploymentTypeChanged = $true
    }

    $distribution = $State.Components | Where-Object Name -eq Distribution | Select-Object -First 1
    if ($distribution.State -eq 'NotCompliant' -or $deploymentTypeChanged) {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name Distribute -Config $Config -Contract $contract
    }

    $collection = $State.Components | Where-Object Name -eq Collection | Select-Object -First 1
    if ($collection.State -eq 'NotCompliant') {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name CreateCollection -Config $Config -Contract $contract
    }

    $membership = $State.Components | Where-Object Name -eq Membership | Select-Object -First 1
    if ($membership.State -eq 'NotCompliant' -and $membership.Reason -in 'MissingDirectRule', 'PendingCollection') {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name AddDirectMembership -Config $Config -Contract $contract
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name RefreshCollection -Config $Config -Contract $contract
    }
    elseif ($membership.State -eq 'NotCompliant') {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name RefreshCollection -Config $Config -Contract $contract
    }

    $assignment = $State.Components | Where-Object Name -eq Assignment | Select-Object -First 1
    if ($assignment.State -eq 'NotCompliant' -and $assignment.Reason -eq 'Missing') {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name CreateDeployment -Config $Config -Contract $contract
        $deploymentCreated = $true
    }
    elseif ($assignment.State -eq 'NotCompliant') {
        Invoke-SetupCmMarkerProviderAction -Providers $Providers -Name UpdateDeployment -Config $Config -Contract $contract
    }

    $client = $State.Components | Where-Object Name -eq Client | Select-Object -First 1
    $server = $State.Components | Where-Object Name -eq ServerCompliance | Select-Object -First 1
    if ($evidenceChannelChanged -or $detectorPolicyChanged -or
        $deploymentCreated -or $client.State -eq 'NotCompliant' -or
        $server.State -eq 'NotCompliant') {
        $requestTimestamp = Invoke-SetupCmMarkerProviderAction `
            -Providers $Providers -Name RequestClientPolicy `
            -Config $Config -Contract $contract
        try {
            if ($null -eq $requestTimestamp) {
                throw 'No timestamp was returned.'
            }
            $minimumEvidenceReceiptUtc = `
                ([datetime]$requestTimestamp).ToUniversalTime()
        }
        catch {
            throw 'The marker policy provider did not return a valid request timestamp.'
        }
        Invoke-SetupCmMarkerProviderAction -Providers $Providers `
            -Name WaitForConvergence -Config $Config -Contract $contract `
            -Arguments @($minimumEvidenceReceiptUtc, $Providers)
    }
}

function Import-SetupCmConfigurationManagerModule {
    [CmdletBinding()]
    param()

    if (-not $IsWindows) { throw 'Marker provider operations require Windows on the accepted site server.' }
    if (-not (Get-Module ConfigurationManager)) {
        if ([string]::IsNullOrWhiteSpace($env:SMS_ADMIN_UI_PATH)) {
            throw 'SMS_ADMIN_UI_PATH is required to locate the ConfigurationManager module.'
        }
        $modulePath = Join-Path $env:SMS_ADMIN_UI_PATH '..\ConfigurationManager.psd1'
        Import-Module $modulePath -Force -ErrorAction Stop
    }
}

function Invoke-SetupCmMarkerSiteCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )

    Import-SetupCmConfigurationManagerModule
    $siteCode = [string]$Config.markerAcceptance.siteCode
    $provider = Get-CimInstance -Namespace 'root\SMS' -ClassName SMS_ProviderLocation -ErrorAction Stop |
        Where-Object { [bool]$_.ProviderForLocalSite -and [string]$_.SiteCode -ieq $siteCode } |
        Select-Object -First 1
    if ($null -eq $provider) { throw "No local SMS Provider exists for site $siteCode." }
    $drive = Get-PSDrive -Name $siteCode -PSProvider CMSite -ErrorAction SilentlyContinue
    if ($null -eq $drive) {
        New-PSDrive -Name $siteCode -PSProvider CMSite -Root ([string]$provider.Machine) | Out-Null
    }
    elseif ([string]$drive.Root -ine [string]$provider.Machine) {
        throw "The existing $siteCode CMSite drive targets a different provider."
    }

    Push-Location ($siteCode + ':')
    try { & $ScriptBlock "root\SMS\site_$siteCode" }
    finally { Pop-Location }
}

function Get-SetupCmMarkerXmlValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][xml]$Xml,
        [Parameter(Mandatory)][string]$LocalName
    )

    $node = $Xml.SelectSingleNode("//*[local-name()='$LocalName']")
    if ($null -eq $node) { return '' }
    [string]$node.InnerText
}

function Get-SetupCmMarkerDirectClientFileState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Contract,
        [scriptblock]$PathProvider = {
            param($Path)
            Test-Path -LiteralPath $Path -PathType Leaf -ErrorAction Stop
        },
        [scriptblock]$HashProvider = {
            param($Path)
            (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
        },
        [scriptblock]$ItemProvider = {
            param($Path)
            Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        }
    )

    $result = [ordered]@{
        MarkerHash = ''
        MarkerLength = 0L
        MarkerHashVerification = 'ProbeUnavailable'
        MarkerLastWriteTime = ''
    }
    try {
        $targetFqdn = [string](Get-SetupCmMarkerValue -InputObject $Contract -Name TargetFqdn)
        $markerPath = [string](Get-SetupCmMarkerValue -InputObject $Contract -Name MarkerPath)
        if ([string]::IsNullOrWhiteSpace($targetFqdn) -or $markerPath -notmatch '^[Cc]:\\') {
            return [pscustomobject]$result
        }
        $relativePath = $markerPath.Substring(3)
        $clientPath = '\\{0}\C$\{1}' -f $targetFqdn, $relativePath
        if (-not [bool](& $PathProvider $clientPath)) {
            $result.MarkerHashVerification = 'Missing'
            return [pscustomobject]$result
        }

        $hash = [string](& $HashProvider $clientPath)
        if ($hash -notmatch '^[0-9a-fA-F]{64}$') {
            throw 'The direct client marker hash is invalid.'
        }
        $item = & $ItemProvider $clientPath
        $lastWriteTime = Get-SetupCmMarkerValue -InputObject $item -Name LastWriteTimeUtc
        $result.MarkerHash = $hash.ToUpperInvariant()
        $result.MarkerLength = [long](Get-SetupCmMarkerValue `
            -InputObject $item -Name Length -DefaultValue 0L)
        $result.MarkerHashVerification = 'DirectAuthenticatedFileRead'
        if ($null -ne $lastWriteTime) {
            $result.MarkerLastWriteTime = ([datetime]$lastWriteTime).ToUniversalTime().ToString('o')
        }
    }
    catch {
        $result.MarkerHash = ''
        $result.MarkerLength = 0L
        $result.MarkerHashVerification = 'ProbeUnavailable'
        $result.MarkerLastWriteTime = ''
    }
    [pscustomobject]$result
}

function Get-SetupCmMarkerProviderInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)]$Contract,
        [AllowNull()]$EvidenceChannelInventory,
        [Nullable[datetime]]$MinimumEvidenceReceiptUtc
    )

    Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
        param($namespace)

        $applications = @(Get-CMApplication -Name $Contract.ApplicationName -Fast)
        $deploymentTypeObjects = @(Get-CMDeploymentType -ApplicationName $Contract.ApplicationName)
        $managementScope = [System.Management.ManagementScope]::new("\\.\$namespace")
        $managementScope.Connect()
        $escapedCollectionName = $Contract.CollectionName.Replace("'", "''")
        $collectionQuery = [System.Management.ObjectQuery]::new(
            "SELECT * FROM SMS_Collection WHERE Name = '$escapedCollectionName'"
        )
        $collectionSearcher = [System.Management.ManagementObjectSearcher]::new(
            $managementScope,
            $collectionQuery
        )
        $collections = @($collectionSearcher.Get())
        foreach ($collectionObject in $collections) { $collectionObject.Get() }
        $collectionId = if ($collections.Count -eq 1) { [string]$collections[0].CollectionID } else { '' }
        $directRules = [System.Collections.Generic.List[object]]::new()
        $otherRules = [System.Collections.Generic.List[object]]::new()
        if ($collections.Count -eq 1) {
            $rules = if ($null -eq $collections[0].CollectionRules) {
                @()
            }
            else { @($collections[0].CollectionRules) }
            foreach ($rule in $rules) {
                $ruleClass = [string]$rule.__CLASS
                if ($ruleClass -ceq 'SMS_CollectionRuleDirect') {
                    [void]$directRules.Add(@{
                        RuleName = [string]$rule.RuleName; ResourceID = [int]$rule.ResourceID
                    })
                }
                else {
                    [void]$otherRules.Add(@{ Type = $ruleClass; RuleName = [string]$rule.RuleName })
                }
            }
        }
        $members = if ($collections.Count -eq 1) {
            @(Get-CimInstance -Namespace $namespace -ClassName SMS_FullCollectionMembership `
                -Filter "CollectionID = '$collectionId'" -ErrorAction Stop)
        }
        else { @() }
        $assignments = @(Get-CMApplicationDeployment -Name $Contract.ApplicationName)

        $packageId = ''
        if ($applications.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace([string]$applications[0].ModelName)) {
            $model = ([string]$applications[0].ModelName).Replace("'", "''")
            $packageLink = Get-CimInstance -Namespace $namespace -ClassName SMS_CIContentPackage `
                -Filter "ModelName = '$model'" -ErrorAction Stop |
                Sort-Object CI_ID -Descending | Select-Object -First 1
            if ($null -ne $packageLink) { $packageId = [string]$packageLink.PackageID }
        }
        $contentSummary = if ([string]::IsNullOrWhiteSpace($packageId)) { $null } else {
            Get-CimInstance -Namespace $namespace -ClassName SMS_ObjectContentExtraInfo `
                -Filter "PackageID = '$packageId'" -ErrorAction Stop | Select-Object -First 1
        }
        $distributionRows = if ([string]::IsNullOrWhiteSpace($packageId)) { @() } else {
            @(Get-CimInstance -Namespace $namespace -ClassName SMS_PackageStatusDistPointsSummarizer `
                -Filter "PackageID = '$packageId'" -ErrorAction Stop)
        }

        $deploymentTypes = @($deploymentTypeObjects | ForEach-Object {
            [xml]$xml = [string]$_.SDMPackageXML
            $detectorNode = $xml.SelectSingleNode("//*[local-name()='DetectionScript']")
            $detectorText = if ($null -eq $detectorNode) { '' } else { [string]$detectorNode.InnerText }
            $detectorLanguage = if ($null -eq $detectorNode -or $null -eq $detectorNode.Attributes['Language']) {
                ''
            }
            else { [string]$detectorNode.Attributes['Language'].Value }
            @{
                Name = [string]$_.LocalizedDisplayName; CI_ID = [int]$_.CI_ID; Revision = [int]$_.CIVersion
                ModelName = [string]$_.ModelName; Technology = [string]$_.Technology; Enabled = [bool]$_.IsEnabled
                ContentId = [string]$_.ContentId; PackageId = $packageId
                ContentLocation = Get-SetupCmMarkerXmlValue -Xml $xml -LocalName Location
                DetectorHash = if ([string]::IsNullOrEmpty($detectorText)) { '' } else { Get-SetupCmMarkerSha256Text -Text $detectorText }
                DetectorLength = if ([string]::IsNullOrEmpty($detectorText)) {
                    0L
                }
                else {
                    [long][System.Text.Encoding]::UTF8.GetByteCount($detectorText)
                }
                DetectionLanguage = $detectorLanguage
                InstallCommand = Get-SetupCmMarkerXmlValue -Xml $xml -LocalName InstallCommandLine
                UninstallCommand = Get-SetupCmMarkerXmlValue -Xml $xml -LocalName UninstallCommandLine
                ExecutionContext = Get-SetupCmMarkerXmlValue -Xml $xml -LocalName ExecutionContext
                UserInteractionMode = Get-SetupCmMarkerXmlValue -Xml $xml -LocalName UserInteractionMode
                RebootBehavior = Get-SetupCmMarkerXmlValue -Xml $xml -LocalName PostInstallBehavior
            }
        })

        $distribution = @($distributionRows | ForEach-Object {
            $nalPath = [string]$_.ServerNALPath
            $distributionPoint = if ($nalPath -match [regex]::Escape($Contract.SiteServerFqdn)) {
                $Contract.SiteServerFqdn
            }
            else { '' }
            $success = [int](Get-SetupCmMarkerValue -InputObject $contentSummary -Name NumberSuccess -DefaultValue 0)
            $errors = [int](Get-SetupCmMarkerValue -InputObject $contentSummary -Name NumberErrors -DefaultValue 0)
            $inProgress = [int](Get-SetupCmMarkerValue -InputObject $contentSummary -Name NumberInProgress -DefaultValue 0)
            $unknown = [int](Get-SetupCmMarkerValue -InputObject $contentSummary -Name NumberUnknown -DefaultValue 0)
            @{
                PackageId = $packageId; DistributionPoint = $distributionPoint
                State = if ($success -eq 1 -and $errors -eq 0 -and $inProgress -eq 0 -and $unknown -eq 0) { 'Success' } else { 'PendingOrFailed' }
                Success = $success; Errors = $errors; InProgress = $inProgress; Unknown = $unknown
            }
        })

        $assignmentItems = @($assignments | ForEach-Object {
            $policyRevision = ([string]$_.AssignedCI_UniqueID -split '/')[-1]
            @{
                AssignmentId = [int]$_.AssignmentID; TargetCollectionId = [string]$_.TargetCollectionID
                Enabled = [bool]$_.Enabled; DesiredConfigType = [int]$_.DesiredConfigType; OfferTypeId = [int]$_.OfferTypeID
                NotifyUser = [bool]$_.NotifyUser; UserUIExperience = [bool]$_.UserUIExperience
                AssignedRevision = if ($null -ne $_.AssignedCIs -and @($_.AssignedCIs).Count -gt 0) { [int]@($_.AssignedCIs)[0] } else { 0 }
                PolicyRevision = $policyRevision
            }
        })
        $serverRows = [System.Collections.Generic.List[object]]::new()
        foreach ($assignmentItem in $assignmentItems) {
            foreach ($row in @(Get-CimInstance -Namespace $namespace -ClassName SMS_AppDeploymentAssetDetails `
                -Filter "AssignmentID = $($assignmentItem.AssignmentId)" -ErrorAction Stop)) {
                [void]$serverRows.Add(@{
                    AssignmentId = [int]$row.AssignmentID; MachineName = [string]$row.MachineName
                    MachineId = [int]$row.MachineID; CollectionId = [string]$row.CollectionID
                    AppCI = [int]$row.AppCI; DTCI = [int]$row.DTCI; ComplianceState = [int]$row.ComplianceState
                    EnforcementState = [int]$row.EnforcementState; InstalledState = [int]$row.InstalledState
                    Revision = [int]$row.Revision
                })
            }
        }
        $acceptedServerRow = @($serverRows | Where-Object {
            [string](Get-SetupCmMarkerValue -InputObject $_ -Name MachineName) -ieq $Contract.TargetName -and
            [int](Get-SetupCmMarkerValue -InputObject $_ -Name MachineId) -eq $Contract.TargetResourceId -and
            [int](Get-SetupCmMarkerValue -InputObject $_ -Name ComplianceState) -eq 1 -and
            [int](Get-SetupCmMarkerValue -InputObject $_ -Name EnforcementState) -in 1000, 1001 -and
            [int](Get-SetupCmMarkerValue -InputObject $_ -Name InstalledState) -eq 2
        } | Select-Object -First 1)
        $distributionAccepted = @($distribution | Where-Object State -eq Success).Count -eq 1
        $directClientMarker = if ($acceptedServerRow.Count -eq 1) {
            Get-SetupCmMarkerDirectClientFileState -Contract $Contract
        }
        else { $null }
        $selectedClientMarker = if ($acceptedServerRow.Count -eq 1) {
            Get-SetupCmMarkerClientEvidenceSelection -Contract $Contract `
                -DirectState $directClientMarker `
                -EvidenceInventory $EvidenceChannelInventory `
                -MinimumReceiptUtc $MinimumEvidenceReceiptUtc
        }
        else { $null }
        $clientProjection = if ($acceptedServerRow.Count -eq 1) {
            @{
                Name = $Contract.TargetName; ResourceId = $Contract.TargetResourceId
                MarkerHash = [string]$selectedClientMarker.MarkerHash
                MarkerLength = [long]$selectedClientMarker.MarkerLength
                MarkerHashVerification = [string]$selectedClientMarker.MarkerHashVerification
                MarkerLastWriteTime = [string]$selectedClientMarker.MarkerLastWriteTime
                EvidenceReceiptTimeUtc = [string]$selectedClientMarker.EvidenceReceiptTimeUtc
                EvidenceOwnerSid = [string]$selectedClientMarker.EvidenceOwnerSid
                EvidenceReason = [string]$selectedClientMarker.EvidenceReason
                InstallState = 'Installed'; EvaluationState = 1; ResolvedState = 'Installed'; ExitCode = 0
                ExecutionContext = 'System'
                SelectedDistributionPoint = if ($distributionAccepted) { $Contract.SiteServerFqdn } else { '' }
                ContentDownload = if ($distributionAccepted) { 'Verified' } else { 'Unknown' }
                StateMessages = if ([int]$acceptedServerRow[0].EnforcementState -eq 1000) {
                    @('APP_CI_ENFORCEMENT_SUCCEEDED', 'APP_CI_PRESENT')
                }
                else { @('APP_CI_PRESENT') }
            }
        }
        else { $null }

        @{
            Applications = @($applications | ForEach-Object {
                @{
                    Name = [string]$_.LocalizedDisplayName; CI_ID = [int]$_.CI_ID; Revision = [int]$_.CIVersion
                    ModelName = [string]$_.ModelName; Enabled = [bool]$_.IsEnabled; Expired = [bool]$_.IsExpired
                    DeploymentTypeCount = [int]$_.NumberOfDeploymentTypes
                    Publisher = [string]$_.Manufacturer; Version = [string]$_.SoftwareVersion
                }
            })
            DeploymentTypes = $deploymentTypes
            Distributions = $distribution
            Collections = @($collections | ForEach-Object {
                @{
                    Name = [string]$_.Name; CollectionId = [string]$_.CollectionID
                    Type = [int]$_.CollectionType; LimitingCollectionId = [string]$_.LimitToCollectionID
                    MemberCount = [int]$_.MemberCount
                }
            })
            DirectRules = @($directRules | ForEach-Object {
                @{ RuleName = [string]$_.RuleName; ResourceId = [int]$_.ResourceID }
            })
            OtherRules = @($otherRules)
            Members = @($members | ForEach-Object {
                @{ Name = [string]$_.Name; ResourceId = [int]$_.ResourceID }
            })
            Assignments = $assignmentItems
            Client = $clientProjection
            ServerCompliance = @($serverRows)
        }
    }
}

function Get-SetupCmMarkerDefaultProviders {
    [CmdletBinding()]
    param()

    @{
        Boundary = {
            param($Config, $Contract)
            $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            $hostFqdn = if ([string]::IsNullOrWhiteSpace([string]$computer.Domain) -or [string]$computer.Domain -ieq 'WORKGROUP') {
                [System.Net.Dns]::GetHostEntry([string]$computer.Name).HostName
            }
            else { '{0}.{1}' -f $computer.Name, $computer.Domain }
            $providers = @(Get-CimInstance -Namespace 'root\SMS' -ClassName SMS_ProviderLocation -ErrorAction Stop |
                Where-Object { [bool]$_.ProviderForLocalSite -and [string]$_.SiteCode -ieq $Contract.SiteCode })
            $sites = @(Get-CimInstance -Namespace "root\SMS\site_$($Contract.SiteCode)" -ClassName SMS_Site -ErrorAction Stop |
                Where-Object { [string]$_.SiteCode -ieq $Contract.SiteCode })
            $escapedTarget = $Contract.TargetName.Replace("'", "''")
            $targets = @(Get-CimInstance -Namespace "root\SMS\site_$($Contract.SiteCode)" -ClassName SMS_R_System `
                -Filter "Name = '$escapedTarget'" -ErrorAction Stop)
            $resolvedTarget = [System.Net.Dns]::GetHostEntry($Contract.TargetFqdn).HostName
            @{
                HostFqdn = $hostFqdn; SiteCode = if ($sites.Count -eq 1) { [string]$sites[0].SiteCode } else { '' }
                SiteServerFqdn = if ($sites.Count -eq 1) { [string]$sites[0].ServerName } else { '' }
                ProviderMachine = if ($providers.Count -eq 1) { [string]$providers[0].Machine } else { '' }
                ResolvedTargetFqdn = $resolvedTarget
                TargetResources = @($targets | ForEach-Object {
                    @{
                        Name = [string]$_.Name; ResourceId = [int]$_.ResourceId; Active = [int]$_.Active
                        Obsolete = [int]$_.Obsolete; Client = [int]$_.Client
                    }
                })
            }
        }
        SourcePayload = {
            param($Config, $Contract)
            $contentNames = @($Contract.ContentFiles | ForEach-Object { $_.Name })
            $detectorPath = Join-Path $Contract.SourceRoot $Contract.DetectorFile.Name
            $detector = if (Test-Path -LiteralPath $detectorPath -PathType Leaf) {
                $item = Get-Item -LiteralPath $detectorPath -Force
                @{
                    Name = $item.Name; Length = [long]$item.Length
                    Hash = (Get-FileHash -LiteralPath $detectorPath -Algorithm SHA256 -ErrorAction Stop).Hash
                }
            }
            else { $null }
            @{
                Files = @(Get-SetupCmMarkerFileInventory -Root $Contract.SourceRoot -Names $contentNames)
                Detector = $detector
            }
        }
        ContentSource = {
            param($Config, $Contract)
            @{ Files = @(Get-SetupCmMarkerFileInventory -Root $Contract.ContentSource -IncludeAllFiles) }
        }
        EvidenceChannel = {
            param($Config, $Contract)
            Get-SetupCmMarkerEvidenceChannelInventory -Contract $Contract
        }
        Inventory = {
            param(
                $Config,
                $Contract,
                $EvidenceChannelInventory,
                $MinimumEvidenceReceiptUtc
            )
            Get-SetupCmMarkerProviderInventory -Config $Config -Contract $Contract `
                -EvidenceChannelInventory $EvidenceChannelInventory `
                -MinimumEvidenceReceiptUtc $MinimumEvidenceReceiptUtc
        }
        SyncContent = {
            param($Config, $Contract)
            $contentNames = @($Contract.ContentFiles | ForEach-Object { $_.Name })
            $source = Get-SetupCmMarkerFileInventory -Root $Contract.SourceRoot -Names $contentNames
            $comparison = Compare-SetupCmMarkerFileInventory -Actual $source -Expected $Contract.ContentFiles
            if (-not $comparison.Exact) { throw 'Reviewed marker source payload is not exact.' }
            New-Item -ItemType Directory -Path $Contract.ContentSource -Force | Out-Null
            foreach ($name in $contentNames) {
                Copy-Item -LiteralPath (Join-Path $Contract.SourceRoot $name) `
                    -Destination (Join-Path $Contract.ContentSource $name) -Force
            }
        }
        CreateApplication = {
            param($Config, $Contract)
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                New-CMApplication -Name $Contract.ApplicationName -Description $Contract.ApplicationDescription `
                    -Publisher $Contract.ApplicationPublisher -SoftwareVersion $Contract.ApplicationVersion `
                    -AutoInstall $true | Out-Null
            }
        }
        CreateDeploymentType = {
            param($Config, $Contract)
            $detector = [System.IO.File]::ReadAllText((Join-Path $Contract.SourceRoot $Contract.DetectorFile.Name))
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                Add-CMScriptDeploymentType -ApplicationName $Contract.ApplicationName `
                    -DeploymentTypeName $Contract.DeploymentTypeName -ContentLocation $Contract.ContentLocation `
                    -InstallCommand $Contract.InstallCommand -UninstallCommand $Contract.UninstallCommand `
                    -ScriptLanguage VBScript -ScriptText $detector -InstallationBehaviorType InstallForSystem `
                    -LogonRequirementType WhetherOrNotUserLoggedOn -UserInteractionMode Hidden `
                    -RebootBehavior NoAction -EstimatedRuntimeMins 1 -MaximumRuntimeMins 15 -Force | Out-Null
            }
        }
        UpdateDeploymentType = {
            param($Config, $Contract)
            $detector = [System.IO.File]::ReadAllText((Join-Path $Contract.SourceRoot $Contract.DetectorFile.Name))
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                Set-CMScriptDeploymentType -ApplicationName $Contract.ApplicationName `
                    -DeploymentTypeName $Contract.DeploymentTypeName -ContentLocation $Contract.ContentLocation `
                    -InstallCommand $Contract.InstallCommand -UninstallCommand $Contract.UninstallCommand `
                    -ScriptLanguage VBScript -ScriptText $detector -InstallationBehaviorType InstallForSystem `
                    -LogonRequirementType WhetherOrNotUserLoggedOn -UserInteractionMode Hidden `
                    -RebootBehavior NoAction -EstimatedRuntimeMins 1 -MaximumRuntimeMins 15 -Force | Out-Null
            }
        }
        CreateEvidenceChannel = {
            param($Config, $Contract)
            New-SetupCmMarkerEvidenceChannel -Contract $Contract | Out-Null
        }
        UpdateDetectorPolicy = {
            param($Config, $Contract)
            $detector = [System.IO.File]::ReadAllText(
                (Join-Path $Contract.SourceRoot $Contract.DetectorFile.Name)
            )
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                Set-CMScriptDeploymentType `
                    -ApplicationName $Contract.ApplicationName `
                    -DeploymentTypeName $Contract.DeploymentTypeName `
                    -ScriptLanguage VBScript -ScriptText $detector -Force |
                    Out-Null
            }
        }
        Distribute = {
            param($Config, $Contract)
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                Start-CMContentDistribution -ApplicationName $Contract.ApplicationName `
                    -DistributionPointName $Contract.SiteServerFqdn -DisableContentDependencyDetection
            }
        }
        CreateCollection = {
            param($Config, $Contract)
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                New-CMDeviceCollection -Name $Contract.CollectionName `
                    -LimitingCollectionId $Contract.LimitingCollectionId -RefreshType Manual | Out-Null
            }
        }
        AddDirectMembership = {
            param($Config, $Contract)
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                Add-CMDeviceCollectionDirectMembershipRule -CollectionName $Contract.CollectionName `
                    -ResourceId $Contract.TargetResourceId | Out-Null
            }
        }
        RefreshCollection = {
            param($Config, $Contract)
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                Invoke-CMDeviceCollectionUpdate -Name $Contract.CollectionName | Out-Null
            }
        }
        CreateDeployment = {
            param($Config, $Contract)
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                $available = Get-Date
                New-CMApplicationDeployment -Name $Contract.ApplicationName -CollectionName $Contract.CollectionName `
                    -DeployAction Install -DeployPurpose Required -UserNotification DisplayAll `
                    -AvailableDateTime $available -DeadlineDateTime $available.AddMinutes(5) `
                    -DistributeContent:$false | Out-Null
            }
        }
        UpdateDeployment = {
            param($Config, $Contract)
            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                param($namespace)
                $escapedCollectionName = $Contract.CollectionName.Replace("'", "''")
                $collections = @(Get-CimInstance -Namespace $namespace -ClassName SMS_Collection `
                        -Filter "Name = '$escapedCollectionName'" -ErrorAction Stop)
                if ($collections.Count -ne 1) {
                    throw 'Exactly one bounded marker collection is required for deployment update.'
                }
                $collection = $collections[0]
                $assignment = Get-CMApplicationDeployment -Name $Contract.ApplicationName |
                    Where-Object { [string]$_.TargetCollectionID -ceq `
                        [string]$collection.CollectionID } |
                    Select-Object -First 1
                if ($null -eq $assignment) { throw 'The bounded marker assignment was not found for update.' }
                if (-not [bool]$assignment.Enabled) {
                    throw 'The bounded marker assignment is disabled and requires explicit operator reconciliation.'
                }
                Set-CMApplicationDeployment -InputObject $assignment -UserNotification DisplayAll | Out-Null
            }
        }
        RequestClientPolicy = {
            param($Config, $Contract)
            $snapshotProvider = {
                param($TimeoutMilliseconds)
                Get-SetupCmMarkerPolicyPublicationSnapshot -Contract $Contract `
                    -TimeoutMilliseconds $TimeoutMilliseconds
            }.GetNewClosure()
            Wait-SetupCmMarkerPolicyPublication -Contract $Contract `
                -SnapshotProvider $snapshotProvider | Out-Null

            Invoke-SetupCmMarkerSiteCommand -Config $Config -ScriptBlock {
                $targetResourceId = [string]$Contract.TargetResourceId
                $machinePolicyProvider = {
                    Invoke-CMClientAction -DeviceId $targetResourceId `
                        -ActionType ClientNotificationRequestMachinePolicyNow |
                        Out-Null
                }.GetNewClosure()
                $applicationEvaluationProvider = {
                    Invoke-CMClientAction -DeviceId $targetResourceId `
                        -ActionType ClientNotificationAppDeplEvalNow | Out-Null
                }.GetNewClosure()
                return Invoke-SetupCmMarkerClientPolicyEvaluation `
                    -Contract $Contract `
                    -MachinePolicyProvider $machinePolicyProvider `
                    -ApplicationEvaluationProvider $applicationEvaluationProvider
            }
        }
        WaitForConvergence = {
            param($Config, $Contract, $MinimumEvidenceReceiptUtc, $AllProviders)
            Wait-SetupCmMarkerConvergence -Config $Config -Contract $Contract `
                -MinimumEvidenceReceiptUtc $MinimumEvidenceReceiptUtc `
                -Providers $AllProviders
        }
    }
}
