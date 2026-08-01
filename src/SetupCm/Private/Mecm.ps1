function New-SetupCmPrimarySiteScript {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Mecm)

    $required = 'siteCode', 'siteName', 'sqlServer', 'smsInstallDir', 'prerequisitePath', 'siteServerFqdn', 'productId'
    foreach ($name in $required) {
        if (-not $Mecm.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($Mecm[$name])) {
            throw "mecm.$name is required."
        }
    }

    @"
[Identification]
Action=InstallPrimarySite

[Options]
ProductID=$($Mecm.productId)
SiteCode=$($Mecm.siteCode)
SiteName=$($Mecm.siteName)
SMSInstallDir=$($Mecm.smsInstallDir)
SDKServer=$($Mecm.siteServerFqdn)
PrerequisiteComp=1
PrerequisitePath=$($Mecm.prerequisitePath)
AdminConsole=1
JoinCEIP=0
ManagementPoint=$($Mecm.siteServerFqdn)
ManagementPointProtocol=HTTP
DistributionPoint=$($Mecm.siteServerFqdn)
DistributionPointProtocol=HTTP
DistributionPointInstallIIS=1
RoleCommunicationProtocol=HTTPorHTTPS
ClientsUsePKICertificate=0
MobileDeviceLanguage=0

[SQLConfigOptions]
SQLServerName=$($Mecm.sqlServer)
SQLServerPort=1433
DatabaseName=CM_$($Mecm.siteCode)
SQLSSBPort=4022

[HierarchyExpansionOption]
CASSetup=0

[CloudConnectorOptions]
CloudConnector=0
UseProxy=0

[SABranchOptions]
SAActive=1
CurrentBranch=1
"@
}

function Get-SetupCmMecmPrerequisites {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MediaPath,
        [Parameter(Mandatory)][string]$PrerequisitePath
    )

    if (-not $IsWindows) { throw 'MECM prerequisite download can only run on Windows Server.' }
    $setupDl = Join-Path (Get-SetupCmMediaRoot -Path $MediaPath) 'SMSSETUP\BIN\X64\Setupdl.exe'
    if (-not (Test-Path -LiteralPath $setupDl)) { throw "MECM Setupdl.exe was not found at $setupDl" }
    New-Item -ItemType Directory -Path $PrerequisitePath -Force | Out-Null
    $process = Start-Process -FilePath $setupDl -ArgumentList @('/NOUI', $PrerequisitePath) -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) { throw "MECM prerequisite download failed with exit code $($process.ExitCode)." }
    return $PrerequisitePath
}

function Install-SetupCmPrimarySite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MediaPath,
        [Parameter(Mandatory)][hashtable]$Mecm,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    if (-not $IsWindows) { throw 'MECM installation can only run on Windows Server.' }
    $setup = Join-Path (Get-SetupCmMediaRoot -Path $MediaPath) 'SMSSETUP\BIN\X64\Setup.exe'
    if (-not (Test-Path -LiteralPath $setup)) { throw "MECM Setup.exe was not found at $setup" }
    $scriptPath = Join-Path $EvidenceRoot 'mecm-unattended.ini'
    New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
    New-SetupCmPrimarySiteScript -Mecm $Mecm | Set-Content -LiteralPath $scriptPath -Encoding ascii
    $process = Start-Process -FilePath $setup -ArgumentList @('/SCRIPT', $scriptPath) -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) { throw "MECM Setup.exe failed with exit code $($process.ExitCode)." }
    return $scriptPath
}
