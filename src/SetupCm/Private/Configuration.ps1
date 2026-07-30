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
        return @($Value | ForEach-Object { ConvertTo-SetupCmHashtable -Value $_ })
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
    }

    return $Config
}
