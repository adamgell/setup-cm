function Test-SetupCmLabHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [hashtable]$Checks
    )

    if ($null -eq $Checks) {
        $Checks = @{
            Sql = { (Test-SetupCmSql -InstanceName $Config.sql.instanceName) -eq 'Compliant' }
            ManagementPoint = { Test-SetupCmManagementPoint }
            DistributionPoint = { Test-SetupCmDistributionPoint }
            Client = { Test-SetupCmClient -ComputerName $Config.testClient.name -SiteCode $Config.mecm.siteCode }
            ClientRegistration = {
                Test-SetupCmClientRegistration -SiteCode $Config.mecm.siteCode -ComputerName $Config.testClient.name
            }
        }
    }
    $results = [ordered]@{}
    foreach ($name in $Checks.Keys) { $results[$name] = [bool](& $Checks[$name]) }
    Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'health' -Value $results | Out-Null
    if ($results.Values -contains $false) { return 'NotCompliant' }
    'Compliant'
}

function Test-SetupCmManagementPoint { if (-not $IsWindows) { return $false }; (Get-Service SMS_EXECUTIVE -ErrorAction SilentlyContinue).Status -eq 'Running' }
function Test-SetupCmDistributionPoint { if (-not $IsWindows) { return $false }; (Get-Service SMS_SITE_COMPONENT_MANAGER -ErrorAction SilentlyContinue).Status -eq 'Running' }
function Test-SetupCmClient {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ComputerName,[string]$SiteCode)

    if (-not $IsWindows) { return $false }
    if (-not [string]::IsNullOrWhiteSpace($SiteCode)) {
        return Test-SetupCmClientRegistration -SiteCode $SiteCode -ComputerName $ComputerName
    }
    Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
}

function Test-SetupCmClientRegistration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[A-Z0-9]{3}$')][string]$SiteCode,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9-]{1,63}$')][string]$ComputerName
    )

    $escapedComputerName = $ComputerName.Replace("'", "''")
    try {
        $resources = @(
            Get-CimInstance -Namespace "root\SMS\site_$SiteCode" -ClassName SMS_R_System -Filter "Name = '$escapedComputerName'" -ErrorAction Stop
        )
    }
    catch { return $false }

    @($resources | Where-Object { [int]$_.Active -eq 1 -and [int]$_.Obsolete -eq 0 }).Count -gt 0
}

function ConvertTo-SetupCmSanitizedFixtureContent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)

    [regex]::Replace($Content, '(?im)(\b(?:password|pwd)\s*=\s*)[^;\r\n\s]+', '$1<redacted>')
}

function Export-SetupCmFixture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$FixtureRoot)
    New-Item -ItemType Directory -Path $FixtureRoot -Force | Out-Null
    $destinationPath = Join-Path $FixtureRoot (Split-Path $SourcePath -Leaf)
    $content = Get-Content -LiteralPath $SourcePath -Raw
    Set-Content -LiteralPath $destinationPath -Value (ConvertTo-SetupCmSanitizedFixtureContent -Content $content) -NoNewline
    $destinationPath
}
