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

    foreach ($field in 'name', 'cacheFile', 'sha256') {
        if (-not $Source.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($Source[$field])) {
            throw "Artifact source field '$field' is required."
        }
    }

    if (-not $Source.licenseAccepted) {
        throw "Artifact '$($Source.name)' requires licenseAccepted=true."
    }

    New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
    $path = Join-Path $CacheRoot $Source.cacheFile
    $sourceUri = if ($Source.ContainsKey('vaultPath')) {
        $Source['vaultPath']
    }
    elseif ($Source.ContainsKey('uri')) {
        $Source['uri']
    }
    else {
        $null
    }

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        if ([string]::IsNullOrWhiteSpace($sourceUri)) {
            throw "Artifact '$($Source.name)' is absent from cache and has no uri or vaultPath."
        }

        $temporaryPath = "$path.download"
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $sourceUri -PathType Leaf) {
            Copy-Item -LiteralPath $sourceUri -Destination $temporaryPath -Force
        }
        else {
            Invoke-WebRequest -Uri $sourceUri -OutFile $temporaryPath
        }

        Move-Item -LiteralPath $temporaryPath -Destination $path -Force
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($actualHash -ne $Source.sha256.ToLowerInvariant()) {
        throw "SHA-256 mismatch for artifact '$($Source.name)'."
    }

    $publisher = if ($Source.ContainsKey('publisher')) { $Source['publisher'] } else { $null }
    $signatureRelativePath = if ($Source.ContainsKey('signatureRelativePath')) { $Source['signatureRelativePath'] } else { $null }
    Test-SetupCmArtifactSignature -Path $path -ExpectedPublisher $publisher -SignatureRelativePath $signatureRelativePath
    $artifact = [pscustomobject]@{
        Name       = $Source.name
        Path       = $path
        Sha256     = $actualHash
        SourceUri  = $sourceUri
        VerifiedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'acquisition' -Value $artifact | Out-Null
    return $artifact
}
