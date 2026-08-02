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

function Test-SetupCmMecmOdbcDriver18 {
    [CmdletBinding()]
    param(
        [scriptblock]$RegistryProvider = {
            Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\MSODBCSQL18' -ErrorAction SilentlyContinue
        }
    )

    if ($null -ne (& $RegistryProvider)) { return 'Compliant' }
    return 'NotCompliant'
}

function Test-SetupCmMecmAdk {
    [CmdletBinding()]
    param(
        [scriptblock]$DirectoryProvider = {
            param($Path)
            Test-Path -LiteralPath $Path -PathType Container
        }
    )

    $requiredDirectories = @(
        'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools',
        'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\User State Migration Tool'
    )

    foreach ($directory in $requiredDirectories) {
        if (-not (& $DirectoryProvider $directory)) { return 'NotCompliant' }
    }

    return 'Compliant'
}

function Test-SetupCmMecmWinPeAddOn {
    [CmdletBinding()]
    param(
        [scriptblock]$DirectoryProvider = {
            param($Path)
            Test-Path -LiteralPath $Path -PathType Container
        }
    )

    if (& $DirectoryProvider 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment') {
        return 'Compliant'
    }
    return 'NotCompliant'
}

function Install-SetupCmMecmOdbcDriver18 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Source,
        [Parameter(Mandatory)][string]$CacheRoot,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    if (-not $IsWindows) { throw 'MECM ODBC Driver installation can only run on Windows Server.' }
    $artifact = Get-SetupCmArtifact -Source $Source -CacheRoot $CacheRoot -EvidenceRoot $EvidenceRoot
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @(
        '/i', $artifact.Path, '/qn', 'IACCEPTMSODBCSQLLICENSETERMS=YES'
    ) -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -notin 0, 3010) {
        throw "MECM ODBC Driver installation failed with exit code $($process.ExitCode)."
    }
}

function Install-SetupCmMecmAdk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Source,
        [Parameter(Mandatory)][string]$CacheRoot,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    if (-not $IsWindows) { throw 'Windows ADK installation can only run on Windows Server.' }
    $artifact = Get-SetupCmArtifact -Source $Source -CacheRoot $CacheRoot -EvidenceRoot $EvidenceRoot
    $process = Start-Process -FilePath $artifact.Path -ArgumentList @(
        '/quiet', '/norestart', '/features', 'OptionId.DeploymentTools', 'OptionId.UserStateMigrationTool'
    ) -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -notin 0, 3010) {
        throw "Windows ADK installation failed with exit code $($process.ExitCode)."
    }
}

function Install-SetupCmMecmWinPeAddOn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Source,
        [Parameter(Mandatory)][string]$CacheRoot,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    if (-not $IsWindows) { throw 'Windows PE add-on installation can only run on Windows Server.' }
    $artifact = Get-SetupCmArtifact -Source $Source -CacheRoot $CacheRoot -EvidenceRoot $EvidenceRoot
    $process = Start-Process -FilePath $artifact.Path -ArgumentList @('/quiet', '/norestart') -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -notin 0, 3010) {
        throw "Windows PE add-on installation failed with exit code $($process.ExitCode)."
    }
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
