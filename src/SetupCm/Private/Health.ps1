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
        }
    }
    $results = [ordered]@{}
    foreach ($name in 'Sql', 'ManagementPoint', 'DistributionPoint', 'Client') { $results[$name] = [bool](& $Checks[$name]) }
    Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'health' -Value $results | Out-Null
    if ($results.Values -contains $false) { return 'NotCompliant' }
    'Compliant'
}

function Test-SetupCmManagementPoint { if (-not $IsWindows) { return $false }; (Get-Service SMS_EXECUTIVE -ErrorAction SilentlyContinue).Status -eq 'Running' }
function Test-SetupCmDistributionPoint { if (-not $IsWindows) { return $false }; (Get-Service SMS_SITE_COMPONENT_MANAGER -ErrorAction SilentlyContinue).Status -eq 'Running' }
function Test-SetupCmClient { param([string]$ComputerName); if (-not $IsWindows) { return $false }; Test-Connection -ComputerName $ComputerName -Count 1 -Quiet }

function Export-SetupCmFixture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$FixtureRoot)
    New-Item -ItemType Directory -Path $FixtureRoot -Force | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination (Join-Path $FixtureRoot (Split-Path $SourcePath -Leaf)) -Force
}
