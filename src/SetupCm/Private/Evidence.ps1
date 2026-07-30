function New-SetupCmRunEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $runId = '{0:yyyyMMdd-HHmmss}-{1}' -f (Get-Date).ToUniversalTime(), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $path = Join-Path $Root $runId
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
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
    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
    return $path
}
