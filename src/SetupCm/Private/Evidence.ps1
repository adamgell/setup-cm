function New-SetupCmRunEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [string]$SourceCommit
    )

    if ([string]::IsNullOrWhiteSpace($SourceCommit) -and
        -not [string]::IsNullOrWhiteSpace($env:SETUPCM_SOURCE_COMMIT)) {
        $SourceCommit = $env:SETUPCM_SOURCE_COMMIT
    }
    if (-not [string]::IsNullOrWhiteSpace($SourceCommit) -and $SourceCommit -notmatch '\A[0-9a-fA-F]{40}\z') {
        throw 'SourceCommit must be a full 40-character Git commit.'
    }

    $runId = '{0:yyyyMMdd-HHmmss}-{1}' -f (Get-Date).ToUniversalTime(), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $path = Join-Path $Root $runId
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $metadata = [ordered]@{
        runId = $runId
        startedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    if (-not [string]::IsNullOrWhiteSpace($SourceCommit)) {
        $metadata.sourceCommit = $SourceCommit.ToLowerInvariant()
    }
    Write-SetupCmEvidenceJson -EvidenceRoot $path -Name 'run' -Value $metadata | Out-Null
    return $path
}

function Resolve-SetupCmRequiredSourceCommit {
    [CmdletBinding()]
    param([string]$SourceCommit)

    if ([string]::IsNullOrWhiteSpace($SourceCommit)) {
        $SourceCommit = $env:SETUPCM_SOURCE_COMMIT
    }
    if ([string]::IsNullOrWhiteSpace($SourceCommit) -or
        $SourceCommit -notmatch '\A[0-9a-fA-F]{40}\z') {
        throw 'Marker acceptance requires an exact 40-character source commit through SourceCommit or SETUPCM_SOURCE_COMMIT.'
    }

    $SourceCommit.ToLowerInvariant()
}

function Test-SetupCmSensitiveEvidenceKey {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $normalized = [regex]::Replace($Name, '[_\-\s]', '').ToLowerInvariant()
    if ($normalized -match '(?:password|secret|token|authorization|credential|apikey|privatekey|connectionstring|connstring)') {
        return $true
    }
    if ($normalized -match '(?:uri|url)$') {
        return $true
    }
    if ($normalized -match '(?:source|vault)path$') {
        return $true
    }
    if ($normalized -match '(?:pwd|sas(?:url|value|token)?)$') {
        return $true
    }
    return $false
}

function Test-SetupCmApprovedEvidencePathKey {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $normalized = [regex]::Replace($Name, '[_\-\s]', '').ToLowerInvariant()
    $normalized -in @(
        'path',
        'artifactpath',
        'contentlibrarypath',
        'installdirectory',
        'expectedinstalldirectory',
        'actualinstalldirectory',
        'installerpath',
        'markerpath'
    )
}

function ConvertTo-SetupCmSanitizedEvidenceString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [switch]$PreserveLocalPath
    )

    $sanitized = [regex]::Replace(
        $Value,
        '(?im)(\b(?:password|pwd|token|secret|authorization|(?:x-)?api[_-]?key)\s*(?:=|:)\s*)(?:"[^"]*"|''[^'']*''|[^;\r\n]+)',
        '$1<redacted>'
    )
    $sanitized = [regex]::Replace($sanitized, '(?i)(\bbearer\s+)[A-Za-z0-9._~+/=-]+', '$1<redacted>')
    $sanitized = [regex]::Replace($sanitized, '(?i)\b(?:https?|ftp|file)://[^\s"''<>]+', '<redacted-uri>')
    $sanitized = [regex]::Replace($sanitized, '(?<!\w)\\\\[^\\\s]+\\[^\s;]+', '<redacted-path>')
    if (-not $PreserveLocalPath) {
        $sanitized = [regex]::Replace(
            $sanitized,
            '(?i)(?:"[A-Z]:[\\/][^"\r\n]*"|''[A-Z]:[\\/][^''\r\n]*''|(?<!\w)[A-Z]:[\\/][^;\r\n,"''<>]+)',
            '<redacted-path>'
        )
    }
    $sanitized
}

function ConvertTo-SetupCmSanitizedEvidenceValue {
    [CmdletBinding()]
    param(
        [AllowNull()]$Value,
        [switch]$PreserveLocalPath
    )

    if ($null -eq $Value) { return $null }

    if ($Value -is [string]) {
        return ConvertTo-SetupCmSanitizedEvidenceString -Value $Value `
            -PreserveLocalPath:$PreserveLocalPath
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $name = [string]$key
            if (Test-SetupCmSensitiveEvidenceKey -Name $name) { continue }
            $result[$name] = ConvertTo-SetupCmSanitizedEvidenceValue -Value $Value[$key] `
                -PreserveLocalPath:(Test-SetupCmApprovedEvidencePathKey -Name $name)
        }
        return $result
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $result = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            if (Test-SetupCmSensitiveEvidenceKey -Name $property.Name) { continue }
            $result[$property.Name] = ConvertTo-SetupCmSanitizedEvidenceValue -Value $property.Value `
                -PreserveLocalPath:(Test-SetupCmApprovedEvidencePathKey -Name $property.Name)
        }
        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            [void]$items.Add((ConvertTo-SetupCmSanitizedEvidenceValue -Value $item `
                -PreserveLocalPath:$PreserveLocalPath))
        }
        Write-Output -NoEnumerate ([object[]]$items.ToArray())
        return
    }

    return $Value
}

function Write-SetupCmEvidenceJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EvidenceRoot,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value
    )

    New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
    $path = Join-Path $EvidenceRoot "$Name.json"
    ConvertTo-SetupCmSanitizedEvidenceValue -Value $Value |
        ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $path -Encoding utf8
    return $path
}
