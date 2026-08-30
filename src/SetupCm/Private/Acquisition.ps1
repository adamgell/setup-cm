function Get-SetupCmWebRequestTimeoutParameters {
    [CmdletBinding()]
    param(
        [version]$PowerShellVersion = $PSVersionTable.PSVersion
    )

    if ($PowerShellVersion -ge [version]'7.4') {
        return @{
            ConnectionTimeoutSeconds = 30
            OperationTimeoutSeconds = 300
        }
    }

    # Before PowerShell 7.4, TimeoutSec is the only native request timeout.
    # Allow up to two hours so multi-gigabyte lab media can finish while still
    # preventing an indefinitely blocked acquisition.
    return @{ TimeoutSec = 7200 }
}

function Resolve-SetupCmArtifactSignaturePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$SignatureRelativePath
    )

    if ([string]::IsNullOrWhiteSpace($SignatureRelativePath)) {
        return $Path
    }

    $mediaRoot = Get-SetupCmMediaRoot -Path $Path
    $relativePath = $SignatureRelativePath -replace '[\\/]', [IO.Path]::DirectorySeparatorChar
    $signaturePath = Join-Path $mediaRoot $relativePath
    if (-not (Test-Path -LiteralPath $signaturePath -PathType Leaf)) {
        throw "Artifact signature file was not found at $signaturePath."
    }
    return $signaturePath
}

function Test-SetupCmArtifactSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$ExpectedPublisher,

        [string]$SignatureRelativePath
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedPublisher)) {
        return
    }

    if (-not $IsWindows) {
        throw "Authenticode publisher validation for '$ExpectedPublisher' requires Windows."
    }

    $signaturePath = Resolve-SetupCmArtifactSignaturePath -Path $Path -SignatureRelativePath $SignatureRelativePath
    $signature = Get-AuthenticodeSignature -FilePath $signaturePath
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notlike "*$ExpectedPublisher*") {
        throw "Authenticode signature validation failed for $Path."
    }
}

function Get-SetupCmPeArchitecture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        $reader = [System.IO.BinaryReader]::new($stream)
        try {
            if ($reader.ReadUInt16() -ne 0x5A4D) { return $null }
            $stream.Position = 0x3C
            $peOffset = $reader.ReadInt32()
            if ($peOffset -lt 0 -or $peOffset -gt ($stream.Length - 6)) { return $null }
            $stream.Position = $peOffset
            if ($reader.ReadUInt32() -ne 0x00004550) { return $null }
            switch ($reader.ReadUInt16()) {
                0x014C { return 'x86' }
                0x8664 { return 'x64' }
                0xAA64 { return 'arm64' }
                default { return $null }
            }
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-SetupCmMsiIdentity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not $IsWindows) { throw 'MSI identity validation requires Windows.' }
    $installer = New-Object -ComObject WindowsInstaller.Installer
    $database = $null
    $view = $null
    $record = $null
    $summary = $null
    try {
        $database = $installer.GetType().InvokeMember(
            'OpenDatabase', 'InvokeMethod', $null, $installer, @($Path, 0)
        )
        $view = $database.GetType().InvokeMember(
            'OpenView', 'InvokeMethod', $null, $database,
            @("SELECT ``Value`` FROM ``Property`` WHERE ``Property``='ProductVersion'")
        )
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null) | Out-Null
        $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
        $version = if ($null -eq $record) {
            $null
        }
        else {
            [string]$record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)
        }
        $summary = $database.GetType().InvokeMember('SummaryInformation', 'GetProperty', $null, $database, 0)
        $template = [string]$summary.GetType().InvokeMember('Property', 'GetProperty', $null, $summary, 7)
        $architecture = if ($template -match '(?i)\bArm64\b') {
            'arm64'
        }
        elseif ($template -match '(?i)\b(?:x64|Intel64)\b') {
            'x64'
        }
        else {
            'x86'
        }
        [pscustomobject]@{ Version = $version; Architecture = $architecture }
    }
    finally {
        foreach ($item in $record, $view, $summary, $database, $installer) {
            if ($null -ne $item -and [System.Runtime.InteropServices.Marshal]::IsComObject($item)) {
                [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($item)
            }
        }
    }
}

function Get-SetupCmArtifactIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Source
    )

    $signatureRelativePath = if ($Source.ContainsKey('signatureRelativePath')) {
        [string]$Source.signatureRelativePath
    }
    else {
        $null
    }
    $identityPath = Resolve-SetupCmArtifactSignaturePath -Path $Path -SignatureRelativePath $signatureRelativePath
    $publisher = if ($Source.ContainsKey('publisher')) { [string]$Source.publisher } else { $null }
    try {
        Test-SetupCmArtifactSignature -Path $Path -ExpectedPublisher $publisher -SignatureRelativePath $signatureRelativePath
    }
    catch {
        if ($_.Exception.Message -like 'Authenticode signature validation failed*') {
            return [pscustomobject]@{
                Version = $null
                Architecture = $null
                PublisherValid = $false
            }
        }
        throw
    }

    if ([IO.Path]::GetExtension($identityPath) -ieq '.msi') {
        $msiIdentity = Get-SetupCmMsiIdentity -Path $identityPath
        return [pscustomobject]@{
            Version = $msiIdentity.Version
            Architecture = $msiIdentity.Architecture
            PublisherValid = $true
        }
    }

    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($identityPath)
    $version = if (-not [string]::IsNullOrWhiteSpace($versionInfo.ProductVersion)) {
        $versionInfo.ProductVersion
    }
    else {
        $versionInfo.FileVersion
    }
    $architecture = if ([string]$Source.architecture -eq 'neutral') {
        'neutral'
    }
    else {
        Get-SetupCmPeArchitecture -Path $identityPath
    }
    [pscustomobject]@{
        Version = $version
        Architecture = $architecture
        PublisherValid = $true
    }
}

function ConvertTo-SetupCmComparableVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)

    $match = [regex]::Match($Value, '\d+(?:\.\d+){0,3}')
    if (-not $match.Success) { return $Value.Trim() }
    $candidate = if ($match.Value -notmatch '\.') { "$($match.Value).0" } else { $match.Value }
    try {
        $parsed = [version]$candidate
        return ('{0}.{1}.{2}.{3}' -f
            $parsed.Major,
            [Math]::Max($parsed.Minor, 0),
            [Math]::Max($parsed.Build, 0),
            [Math]::Max($parsed.Revision, 0))
    }
    catch { return $match.Value }
}

function Get-SetupCmArtifactState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Source,
        [Parameter(Mandatory)][string]$CacheRoot,
        [string]$ArtifactPath,
        [scriptblock]$PathProvider = { param($Path) Test-Path -LiteralPath $Path -PathType Leaf },
        [scriptblock]$LengthProvider = { param($Path) (Get-Item -LiteralPath $Path -ErrorAction Stop).Length },
        [scriptblock]$HashProvider = { param($Path) (Get-FileHash -Algorithm SHA256 -LiteralPath $Path -ErrorAction Stop).Hash },
        [scriptblock]$IdentityProvider = { param($Path, $ArtifactSource) Get-SetupCmArtifactIdentity -Path $Path -Source $ArtifactSource }
    )

    $name = if ($Source.ContainsKey('name')) { [string]$Source.name } else { '<unnamed>' }
    $state = [ordered]@{
        Name = $name
        State = 'Conflict'
        Reason = 'InvalidSourceMetadata'
        CacheFile = if ($Source.ContainsKey('cacheFile')) { [string]$Source.cacheFile } else { $null }
        SizeBytes = if ($Source.ContainsKey('sizeBytes')) { $Source.sizeBytes } else { $null }
        Sha256 = if ($Source.ContainsKey('sha256')) { ([string]$Source.sha256).ToLowerInvariant() } else { $null }
        Version = if ($Source.ContainsKey('version')) { [string]$Source.version } else { $null }
        Architecture = if ($Source.ContainsKey('architecture')) { [string]$Source.architecture } else { $null }
    }

    foreach ($field in 'name', 'cacheFile', 'sha256', 'sizeBytes', 'version', 'architecture', 'publisher') {
        if (-not $Source.ContainsKey($field) -or [string]::IsNullOrWhiteSpace([string]$Source[$field])) {
            $state.Reason = "MissingSourceField:$field"
            return [pscustomobject]$state
        }
    }
    if (-not $Source.ContainsKey('licenseAccepted') -or -not $Source.licenseAccepted) {
        $state.Reason = 'LicenseNotAccepted'
        return [pscustomobject]$state
    }
    try { $expectedSize = [long]$Source.sizeBytes } catch { $expectedSize = 0 }
    if ($expectedSize -le 0 -or [string]$Source.sha256 -notmatch '^[0-9a-fA-F]{64}$' -or
        [string]$Source.architecture -notin 'x64', 'x86', 'neutral') {
        return [pscustomobject]$state
    }

    $path = if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
        Join-Path $CacheRoot $Source.cacheFile
    }
    else {
        $ArtifactPath
    }
    try {
        $pathExists = [bool](& $PathProvider $path)
    }
    catch {
        $state.State = 'Conflict'
        $state.Reason = 'PathProbeUnavailable'
        return [pscustomobject]$state
    }
    if (-not $pathExists) {
        $state.State = 'NotCompliant'
        $state.Reason = 'Missing'
        return [pscustomobject]$state
    }
    try {
        $actualLength = [long](& $LengthProvider $path)
    }
    catch {
        $state.State = 'Conflict'
        $state.Reason = 'LengthProbeUnavailable'
        return [pscustomobject]$state
    }
    if ($actualLength -ne $expectedSize) {
        $state.State = 'NotCompliant'
        $state.Reason = 'SizeMismatch'
        return [pscustomobject]$state
    }
    try {
        $actualHash = ([string](& $HashProvider $path)).ToLowerInvariant()
    }
    catch {
        $state.State = 'Conflict'
        $state.Reason = 'HashProbeUnavailable'
        return [pscustomobject]$state
    }
    if ($actualHash -ne ([string]$Source.sha256).ToLowerInvariant()) {
        $state.State = 'NotCompliant'
        $state.Reason = 'Sha256Mismatch'
        return [pscustomobject]$state
    }
    try {
        $identity = & $IdentityProvider $path $Source
    }
    catch {
        $state.State = 'Conflict'
        $state.Reason = 'IdentityProbeUnavailable'
        return [pscustomobject]$state
    }
    if ($null -eq $identity) {
        $state.State = 'Conflict'
        $state.Reason = 'IdentityProbeUnavailable'
        return [pscustomobject]$state
    }
    $hasPublisherState = if ($identity -is [System.Collections.IDictionary]) {
        $identity.Contains('PublisherValid')
    }
    else {
        $identity.PSObject.Properties.Name -contains 'PublisherValid'
    }
    if ($hasPublisherState -and -not [bool]$identity.PublisherValid) {
        $state.State = 'Conflict'
        $state.Reason = 'PublisherMismatch'
        return [pscustomobject]$state
    }
    if ([string]::IsNullOrWhiteSpace([string]$identity.Version)) {
        $state.State = 'Conflict'
        $state.Reason = 'VersionUnavailable'
        return [pscustomobject]$state
    }
    if ((ConvertTo-SetupCmComparableVersion -Value ([string]$identity.Version)) -ne
        (ConvertTo-SetupCmComparableVersion -Value ([string]$Source.version))) {
        $state.State = 'Conflict'
        $state.Reason = 'VersionMismatch'
        return [pscustomobject]$state
    }
    if ([string]$Source.architecture -ne 'neutral') {
        if ([string]::IsNullOrWhiteSpace([string]$identity.Architecture)) {
            $state.State = 'Conflict'
            $state.Reason = 'ArchitectureUnavailable'
            return [pscustomobject]$state
        }
        if ([string]$identity.Architecture -ine [string]$Source.architecture) {
            $state.State = 'Conflict'
            $state.Reason = 'ArchitectureMismatch'
            return [pscustomobject]$state
        }
    }

    $state.State = 'Compliant'
    $state.Reason = 'Verified'
    [pscustomobject]$state
}

function Get-SetupCmNormalizedSources {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Sources)

    foreach ($sourceName in ($Sources.Keys | Sort-Object)) {
        if ($Sources[$sourceName] -isnot [hashtable]) {
            if ([string]$sourceName -ceq 'prerequisites' -and
                $Sources[$sourceName] -is [System.Collections.IEnumerable] -and
                $Sources[$sourceName] -isnot [string]) {
                continue
            }
            @{
                name = [string]$sourceName
                setupCmNormalizationError = 'InvalidSourceType'
            }
            continue
        }
        $source = $Sources[$sourceName].Clone()
        if (-not $source.ContainsKey('name') -or [string]::IsNullOrWhiteSpace($source.name)) {
            $source.name = $sourceName
        }
        $source
    }
}

function Test-SetupCmAcquire {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [string]$EvidenceRoot
    )

    $sources = @(Get-SetupCmNormalizedSources -Sources $Config.sources)
    $components = if ($sources.Count -eq 0) {
        @([pscustomobject][ordered]@{
            Name = 'Sources'; State = 'Conflict'; Reason = 'EmptySourceSet'
            CacheFile = $null; SizeBytes = $null; Sha256 = $null
            Version = $null; Architecture = $null
        })
    }
    else {
        @(foreach ($source in $sources) {
            if ($source.ContainsKey('setupCmNormalizationError')) {
                [pscustomobject][ordered]@{
                    Name = [string]$source.name; State = 'Conflict'
                    Reason = [string]$source.setupCmNormalizationError
                    CacheFile = $null; SizeBytes = $null; Sha256 = $null
                    Version = $null; Architecture = $null
                }
            }
            else {
                Get-SetupCmArtifactState -Source $source -CacheRoot $Config.cacheRoot
            }
        })
    }
    $state = if ($components.State -contains 'Conflict') {
        'Conflict'
    }
    elseif ($components.State -contains 'NotCompliant') {
        'NotCompliant'
    }
    else {
        'Compliant'
    }
    if (-not [string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'acquire-state' -Value ([ordered]@{
            state = $state
            components = $components
        }) | Out-Null
    }
    $state
}

function Get-SetupCmArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Source,

        [Parameter(Mandatory)]
        [string]$CacheRoot,

        [Parameter(Mandatory)]
        [string]$EvidenceRoot
    )

    $initialState = Get-SetupCmArtifactState -Source $Source -CacheRoot $CacheRoot
    $artifactName = [string]$initialState.Name
    if ($initialState.State -eq 'Conflict') {
        if ($initialState.Reason -eq 'LicenseNotAccepted') {
            throw "Artifact '$artifactName' requires licenseAccepted=true."
        }
        throw "Artifact '$artifactName' cannot be acquired safely: $($initialState.Reason)."
    }
    $path = Join-Path $CacheRoot ([string]$Source.cacheFile)
    if ($initialState.State -eq 'Compliant') {
        return [pscustomobject]@{
            Name = $artifactName
            State = 'Compliant'
            Reason = 'Verified'
            Path = $path
            Sha256 = $initialState.Sha256
            SizeBytes = [long]$initialState.SizeBytes
            Version = $initialState.Version
            Architecture = $initialState.Architecture
            VerifiedAt = (Get-Date).ToUniversalTime().ToString('o')
        }
    }

    $sourceUri = if ($Source.ContainsKey('vaultPath')) {
        $Source.vaultPath
    }
    elseif ($Source.ContainsKey('uri')) {
        $Source.uri
    }
    else {
        $null
    }
    if ([string]::IsNullOrWhiteSpace($sourceUri)) {
        throw "Artifact '$artifactName' is not compliant ($($initialState.Reason)) and has no approved source."
    }

    New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
    $extension = [IO.Path]::GetExtension($path)
    $temporaryPath = if ([string]::IsNullOrEmpty($extension)) {
        "$path.download"
    }
    else {
        $path.Substring(0, $path.Length - $extension.Length) + ".download$extension"
    }
    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    try {
        if (Test-Path -LiteralPath $sourceUri -PathType Leaf) {
            Copy-Item -LiteralPath $sourceUri -Destination $temporaryPath -Force
        }
        else {
            $timeoutParameters = Get-SetupCmWebRequestTimeoutParameters
            Invoke-WebRequest -Uri $sourceUri -OutFile $temporaryPath @timeoutParameters
        }
    }
    catch {
        $detail = ConvertTo-SetupCmSanitizedEvidenceString -Value ([string]$_.Exception.Message)
        if (-not [string]::IsNullOrWhiteSpace([string]$sourceUri)) {
            $detail = [regex]::Replace(
                $detail,
                [regex]::Escape([string]$sourceUri),
                '<redacted-source>',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
        }
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($detail)) {
            throw "Acquisition failed for artifact '$artifactName'."
        }
        throw "Acquisition failed for artifact '$artifactName': $detail"
    }

    $downloadedState = Get-SetupCmArtifactState -Source $Source -CacheRoot $CacheRoot -ArtifactPath $temporaryPath
    if ($downloadedState.State -ne 'Compliant') {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        throw "Downloaded artifact '$artifactName' failed verification: $($downloadedState.Reason)."
    }

    Move-Item -LiteralPath $temporaryPath -Destination $path -Force
    [pscustomobject]@{
        Name = $artifactName
        State = 'Compliant'
        Reason = 'AcquiredAndVerified'
        Path = $path
        Sha256 = $downloadedState.Sha256
        SizeBytes = [long]$downloadedState.SizeBytes
        Version = $downloadedState.Version
        Architecture = $downloadedState.Architecture
        VerifiedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
}
