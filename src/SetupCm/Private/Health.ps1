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
            Client = { Test-SetupCmClient -ComputerName $Config.testClient.name }
            ClientRegistration = {
                Test-SetupCmClientRegistration -SiteCode $Config.mecm.siteCode -ComputerName $Config.testClient.name -SqlServer $Config.mecm.sqlServer
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
function Test-SetupCmClient { param([string]$ComputerName); if (-not $IsWindows) { return $false }; Test-Connection -ComputerName $ComputerName -Count 1 -Quiet }

function Test-SetupCmClientRegistration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[A-Z0-9]{3}$')][string]$SiteCode,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9-]{1,63}$')][string]$ComputerName,
        [string]$SqlServer = 'localhost',
        [scriptblock]$SqlQuery
    )

    $query = @"
SELECT TOP (1)
    sys.Name0 + '|' + CONVERT(varchar(1), sys.Client0) + '|' + CONVERT(varchar(1), sys.Active0) + '|' + ISNULL(assigned.SMS_Assigned_Sites0, '')
FROM dbo.v_R_System AS sys
LEFT JOIN dbo.v_RA_System_SMSAssignedSites AS assigned ON assigned.ResourceID = sys.ResourceID
WHERE sys.Name0 = N'$ComputerName'
ORDER BY sys.Active0 DESC, sys.Client0 DESC;
"@
    if ($null -eq $SqlQuery) {
        $SqlQuery = {
            param($Query)
            & sqlcmd -S $SqlServer -E -d "CM_$SiteCode" -h -1 -W -Q $Query
        }
    }
    $record = @(& $SqlQuery $query | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
    if ($record.Count -ne 1) { return $false }
    $values = ([string]$record[0]).Trim().Split('|')
    $values.Count -eq 4 -and
        $values[0] -eq $ComputerName -and
        $values[1] -eq '1' -and
        $values[2] -eq '1' -and
        $values[3] -eq $SiteCode
}

function ConvertTo-SetupCmSanitizedFixtureContent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Content)

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
