function ConvertTo-SetupCmHashtable {
    param([Parameter(Mandatory)]$Value)

    if ($Value -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $Value.Keys) {
            $result[[string]$key] = ConvertTo-SetupCmHashtable -Value $Value[$key]
        }

        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @(foreach ($item in $Value) { ConvertTo-SetupCmHashtable -Value $item })
    }

    if ($Value -is [pscustomobject]) {
        $result = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-SetupCmHashtable -Value $property.Value
        }

        return $result
    }

    return $Value
}

function Read-SetupCmConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Configuration file does not exist: $Path"
    }

    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        throw 'The powershell-yaml module is required to read YAML configuration.'
    }

    $config = ConvertTo-SetupCmHashtable -Value (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Yaml)
    Assert-SetupCmConfig -Config $config
}

function Assert-SetupCmConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    if (-not $Config.ContainsKey('safety')) {
        throw 'safety is required.'
    }

    $safety = $Config.safety
    if (-not $safety.ContainsKey('isolatedLab')) {
        throw 'safety.isolatedLab is required.'
    }

    if (-not $safety.isolatedLab -and -not $safety.allowProductionTarget) {
        throw 'safety.allowProductionTarget must be true when safety.isolatedLab is false.'
    }

    if (-not $Config.ContainsKey('sources')) {
        throw 'sources is required.'
    }

    foreach ($name in 'sqlServer', 'mecm') {
        if (-not $Config.sources.ContainsKey($name)) {
            throw "sources.$name is required."
        }
        foreach ($field in 'uri', 'sha256') {
            $value = [string]$Config.sources[$name][$field]
            $isTemplate = $Config.ContainsKey('template') -and $Config['template']
            if ((-not $isTemplate) -and ([string]::IsNullOrWhiteSpace($value) -or $value -match 'REPLACE|example\.invalid')) {
                throw "sources.$name.$field contains a placeholder."
            }
        }
    }

    if (-not $Config.ContainsKey('sql') -or -not $Config.sql.ContainsKey('sysAdminAccounts') -or @($Config.sql.sysAdminAccounts).Count -eq 0) {
        throw 'sql.sysAdminAccounts must include at least one Windows identity.'
    }

    if ($Config.ContainsKey('markerAcceptance') -and $Config.markerAcceptance.enabled) {
        $marker = $Config.markerAcceptance
        if (-not $Config.safety.isolatedLab -or -not $marker.labOnly) {
            throw 'Enabled marker acceptance requires safety.isolatedLab=true and markerAcceptance.labOnly=true.'
        }
        $fixedValues = [ordered]@{
            siteCode = 'LAB'
            siteServerFqdn = 'LABZ1-CM01.test.gell.one'
            targetFqdn = 'RING0IVY24-01.test.gell.one'
            targetResourceId = 16777219
        }
        foreach ($name in $fixedValues.Keys) {
            if (-not $marker.ContainsKey($name) -or [string]$marker[$name] -cne [string]$fixedValues[$name]) {
                throw "markerAcceptance.$name must be '$($fixedValues[$name])'."
            }
        }
    }

    $isTemplate = $Config.ContainsKey('template') -and $Config['template']
    if (-not $isTemplate) {
        foreach ($sourceName in $Config.sources.Keys) {
            $source = $Config.sources[$sourceName]
            if ($source -isnot [hashtable]) { continue }
            foreach ($field in 'cacheFile', 'sha256', 'sizeBytes', 'version', 'architecture', 'publisher') {
                if (-not $source.ContainsKey($field) -or [string]::IsNullOrWhiteSpace([string]$source[$field])) {
                    throw "sources.$sourceName.$field is required."
                }
            }
            try { $sizeBytes = [long]$source.sizeBytes } catch { $sizeBytes = 0 }
            if ($sizeBytes -le 0) { throw "sources.$sourceName.sizeBytes must be greater than zero." }
            if ([string]$source.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
                throw "sources.$sourceName.sha256 must be a 64-character hexadecimal value."
            }
            if ([string]$source.architecture -notin 'x64', 'x86', 'neutral') {
                throw "sources.$sourceName.architecture must be x64, x86, or neutral."
            }
            if ([string]$sourceName -ieq 'mecm' -and
                [string]$source.version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
                throw 'sources.mecm.version must be the native setup.exe ProductVersion, not a Current Branch label.'
            }
        }
    }

    return $Config
}
