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

function Get-SetupCmMecmVcRedistRegistryPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('x64', 'x86')][string]$Architecture)

    if ($Architecture -eq 'x86') {
        return 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
    }

    return 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
}

function Test-SetupCmMecmVcRedistArchitecture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('x64', 'x86')][string]$Architecture,
        [scriptblock]$RegistryProvider = {
            param($Architecture)
            Get-ItemProperty -Path (Get-SetupCmMecmVcRedistRegistryPath -Architecture $Architecture) -ErrorAction SilentlyContinue
        }
    )

    $runtime = & $RegistryProvider $Architecture
    if ($null -eq $runtime) { return 'NotCompliant' }

    try {
        if ([int]$runtime.Installed -ne 1) { return 'NotCompliant' }
        $version = [version](([string]$runtime.Version).TrimStart('v'))
    }
    catch {
        return 'NotCompliant'
    }

    if ($version -lt [version]'14.34') { return 'NotCompliant' }
    return 'Compliant'
}

function Test-SetupCmMecmVcRedist {
    [CmdletBinding()]
    param(
        [scriptblock]$RegistryProvider = {
            param($Architecture)
            Get-ItemProperty -Path (Get-SetupCmMecmVcRedistRegistryPath -Architecture $Architecture) -ErrorAction SilentlyContinue
        }
    )

    foreach ($architecture in 'x64', 'x86') {
        if ((Test-SetupCmMecmVcRedistArchitecture -Architecture $architecture -RegistryProvider $RegistryProvider) -ne 'Compliant') {
            return 'NotCompliant'
        }
    }

    return 'Compliant'
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

function Get-SetupCmMecmObjectValue {
    [CmdletBinding()]
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        $DefaultValue = $null
    )

    if ($null -eq $InputObject) { return $DefaultValue }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $DefaultValue
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function New-SetupCmMecmComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Compliant', 'NotCompliant', 'Conflict')][string]$State,
        [Parameter(Mandatory)][string]$Reason,
        [hashtable]$Details = @{}
    )

    $component = [ordered]@{ Name = $Name; State = $State; Reason = $Reason }
    foreach ($key in $Details.Keys) {
        if ($key -notin 'Name', 'State', 'Reason') { $component[$key] = $Details[$key] }
    }
    return [pscustomobject]$component
}

function New-SetupCmMecmDesiredStateResult {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IEnumerable]$Components)

    $items = @($Components)
    $state = if (@($items | Where-Object State -eq 'Conflict').Count -gt 0) {
        'Conflict'
    }
    elseif (@($items | Where-Object State -eq 'NotCompliant').Count -gt 0) {
        'NotCompliant'
    }
    else {
        'Compliant'
    }
    return [pscustomobject]@{ State = $state; Components = $items }
}

function ConvertTo-SetupCmMecmComparablePath {
    [CmdletBinding()]
    param([AllowNull()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    return $Path.Trim().TrimEnd('\', '/')
}

function Test-SetupCmMecmServerIdentity {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Actual,
        [AllowNull()][string]$Expected,
        [switch]$AllowShortName
    )

    if ([string]::IsNullOrWhiteSpace($Actual) -or [string]::IsNullOrWhiteSpace($Expected)) { return $false }
    $actualHost = $Actual.Trim().TrimStart('\').TrimEnd('.').Split('\')[0]
    $expectedHost = $Expected.Trim().TrimStart('\').TrimEnd('.').Split('\')[0]
    if ($actualHost -ieq $expectedHost) { return $true }
    if ($AllowShortName) {
        return $actualHost.Split('.')[0] -ieq $expectedHost.Split('.')[0]
    }
    return $false
}

function Get-SetupCmMecmExpectedClientResourceId {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config)

    if ($Config.ContainsKey('markerAcceptance') -and
        $Config.markerAcceptance.ContainsKey('targetResourceId') -and
        [int]$Config.markerAcceptance.targetResourceId -gt 0) {
        return [int]$Config.markerAcceptance.targetResourceId
    }
    if ($Config.ContainsKey('testClient') -and
        $Config.testClient.ContainsKey('resourceId') -and
        [int]$Config.testClient.resourceId -gt 0) {
        return [int]$Config.testClient.resourceId
    }
    return $null
}

function ConvertFrom-SetupCmMecmClientSqlRow {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Reader)

    @{
        Name = if ($Reader.IsDBNull(0)) { '' } else { [string]$Reader.GetValue(0) }
        ResourceId = if ($Reader.IsDBNull(1)) { 0 } else { [int]$Reader.GetValue(1) }
        Active = if ($Reader.IsDBNull(2)) { 0 } else { [int]$Reader.GetValue(2) }
        Obsolete = if ($Reader.IsDBNull(3)) { 1 } else { [int]$Reader.GetValue(3) }
        Client = if ($Reader.IsDBNull(4)) { 0 } else { [int]$Reader.GetValue(4) }
        ClientVersion = if ($Reader.IsDBNull(5)) { '' } else { [string]$Reader.GetValue(5) }
    }
}

function Get-SetupCmMecmDefaultProviders {
    [CmdletBinding()]
    param()

    return @{
        Host = {
            $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            $fqdn = if ([string]::IsNullOrWhiteSpace([string]$computer.Domain) -or
                [string]$computer.Domain -ieq 'WORKGROUP') {
                [System.Net.Dns]::GetHostEntry([string]$computer.Name).HostName
            }
            else {
                '{0}.{1}' -f $computer.Name, $computer.Domain
            }
            @{ Fqdn = $fqdn }
        }
        Adk = { (Test-SetupCmMecmAdk) -eq 'Compliant' }
        WinPe = { (Test-SetupCmMecmWinPeAddOn) -eq 'Compliant' }
        Odbc = { (Test-SetupCmMecmOdbcDriver18) -eq 'Compliant' }
        VcRuntime = {
            param($Architecture)
            (Test-SetupCmMecmVcRedistArchitecture -Architecture $Architecture) -eq 'Compliant'
        }
        Site = {
            param($Config)
            $identificationPath = 'HKLM:\SOFTWARE\Microsoft\SMS\Identification'
            $identification = Get-ItemProperty -Path $identificationPath -ErrorAction SilentlyContinue
            if ($null -eq $identification) {
                try {
                    $residualProviders = @(
                        Get-CimInstance -Namespace 'root\SMS' -ClassName SMS_ProviderLocation -ErrorAction Stop
                    )
                    return @{
                        Exists = $false
                        ResidualState = $residualProviders.Count -gt 0
                        ProviderCount = $residualProviders.Count
                    }
                }
                catch {
                    if ($_.Exception.Message -match '(?i)invalid namespace|0x8004100e') {
                        return @{ Exists = $false; ResidualState = $false }
                    }
                    if ($_.Exception.Message -match '(?i)invalid class|0x80041010') {
                        return @{ Exists = $false; ResidualState = $true }
                    }
                    throw
                }
            }

            $registrySiteCode = [string]$identification.'Site Code'
            $installDirectory = [string]$identification.'Installation Directory'
            if ([string]::IsNullOrWhiteSpace($registrySiteCode)) {
                return @{ Exists = $false; ResidualState = $true; InstallDirectory = $installDirectory }
            }

            $namespace = "root\SMS\site_$registrySiteCode"
            $sites = @(Get-CimInstance -Namespace $namespace -ClassName SMS_Site -ErrorAction Stop)
            $providerLocations = @(Get-CimInstance -Namespace 'root\SMS' -ClassName SMS_ProviderLocation -ErrorAction Stop |
                Where-Object { [string]$_.SiteCode -ieq $registrySiteCode -or [bool]$_.ProviderForLocalSite })
            $site = $sites | Select-Object -First 1
            $provider = $providerLocations | Select-Object -First 1
            @{
                Exists = $true
                ResidualState = $false
                RegistrySiteCode = $registrySiteCode
                SiteCount = $sites.Count
                SiteCode = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name SiteCode)
                SiteName = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name SiteName)
                ServerName = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name ServerName)
                Type = [int](Get-SetupCmMecmObjectValue -InputObject $site -Name Type -DefaultValue 0)
                ParentSiteCode = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name ParentSiteCode)
                InstallDirectory = $installDirectory
                ProviderCount = $providerLocations.Count
                ProviderSiteCode = [string](Get-SetupCmMecmObjectValue -InputObject $provider -Name SiteCode)
                ProviderMachine = [string](Get-SetupCmMecmObjectValue -InputObject $provider -Name Machine)
                ProviderForLocalSite = [bool](Get-SetupCmMecmObjectValue -InputObject $provider -Name ProviderForLocalSite -DefaultValue $false)
            }
        }
        Roles = {
            param($Config)
            @(Get-CimInstance -Namespace "root\SMS\site_$($Config.mecm.siteCode)" -ClassName SMS_SystemResourceList -ErrorAction Stop |
                ForEach-Object {
                    @{
                        RoleName = [string]$_.RoleName
                        ServerName = [string]$_.ServerName
                        SiteCode = [string]$_.SiteCode
                    }
                })
        }
        Services = {
            @('SMS_EXECUTIVE', 'SMS_SITE_COMPONENT_MANAGER') | ForEach-Object {
                $name = $_
                $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'" -ErrorAction Stop
                if ($null -ne $service) {
                    @{
                        Name = $name
                        Status = [string]$service.State
                        StartType = [string]$service.StartMode
                    }
                }
            }
        }
        ContentLibrary = {
            $dp = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\SMS\DP' -ErrorAction SilentlyContinue
            if ($null -eq $dp) { return @{ Path = ''; Accessible = $false; SiteCode = '' } }
            $path = [string]$dp.ContentLibraryPath
            @{
                Path = $path
                Accessible = -not [string]::IsNullOrWhiteSpace($path) -and
                    (Test-Path -LiteralPath $path -PathType Container)
                SiteCode = [string]$dp.SiteCode
            }
        }
        ClientProvider = {
            param($Config)
            $name = [string]$Config.testClient.name
            $escapedName = $name.Replace('\', '\\').Replace("'", "\'")
            @(Get-CimInstance -Namespace "root\SMS\site_$($Config.mecm.siteCode)" -ClassName SMS_R_System `
                -Filter "Name = '$escapedName'" -ErrorAction Stop |
                ForEach-Object {
                    @{
                        Name = [string]$_.Name
                        ResourceId = [int]$_.ResourceId
                        Active = [int]$_.Active
                        Obsolete = [int]$_.Obsolete
                        Client = [int]$_.Client
                        ClientVersion = [string]$_.ClientVersion
                    }
                })
        }
        ClientDatabase = {
            param($Config)
            $databaseName = "CM_$($Config.mecm.siteCode)"
            $connection = New-SetupCmSqlConnection -Config $Config -Database $databaseName
            try {
                $connection.Open()
                $identity = $connection.CreateCommand()
                $identity.CommandText = "SELECT DB_NAME() AS DatabaseName, CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) AS ServerName"
                $reader = $identity.ExecuteReader()
                try {
                    if (-not $reader.Read()) { throw 'The MECM database identity query returned no row.' }
                    $actualDatabase = $reader.GetString(0)
                    $actualServer = $reader.GetString(1)
                }
                finally {
                    $reader.Dispose()
                }

                $client = $connection.CreateCommand()
                $client.CommandText = @'
SELECT Name0, ResourceID, Active0, Obsolete0, Client0, Client_Version0
FROM dbo.v_R_System
WHERE Name0 = @Name
'@
                [void]$client.Parameters.Add('@Name', [System.Data.SqlDbType]::NVarChar, 256)
                $client.Parameters['@Name'].Value = [string]$Config.testClient.name
                $rows = [System.Collections.Generic.List[object]]::new()
                $reader = $client.ExecuteReader()
                try {
                    while ($reader.Read()) {
                        [void]$rows.Add((ConvertFrom-SetupCmMecmClientSqlRow -Reader $reader))
                    }
                }
                finally {
                    $reader.Dispose()
                }
                @{
                    DatabaseName = $actualDatabase
                    ServerName = $actualServer
                    Rows = @($rows)
                }
            }
            finally {
                $connection.Dispose()
            }
        }
    }
}

function Get-SetupCmMecmDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [hashtable]$Providers
    )

    $components = [System.Collections.Generic.List[object]]::new()
    if (-not $Config.ContainsKey('topology') -or [string]$Config.topology -cne 'single-box') {
        [void]$components.Add((New-SetupCmMecmComponent -Name TargetHost -State Conflict -Reason UnsupportedTopology))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    if (-not $Config.ContainsKey('mecm') -or
        -not $Config.mecm.ContainsKey('siteServerFqdn') -or
        [string]::IsNullOrWhiteSpace([string]$Config.mecm.siteServerFqdn)) {
        [void]$components.Add((New-SetupCmMecmComponent -Name TargetHost -State Conflict -Reason MissingExpectedHost))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    if ($null -eq $Providers) { $Providers = Get-SetupCmMecmDefaultProviders }

    $expectedServer = ([string]$Config.mecm.siteServerFqdn).TrimEnd('.')
    try {
        $hostState = & $Providers.Host
        $actualFqdn = [string](Get-SetupCmMecmObjectValue -InputObject $hostState -Name Fqdn)
        if (-not (Test-SetupCmMecmServerIdentity -Actual $actualFqdn -Expected $expectedServer)) {
            [void]$components.Add((New-SetupCmMecmComponent -Name TargetHost -State Conflict -Reason HostMismatch -Details @{
                Expected = $expectedServer; Actual = $actualFqdn
            }))
            return New-SetupCmMecmDesiredStateResult -Components $components
        }
        [void]$components.Add((New-SetupCmMecmComponent -Name TargetHost -State Compliant -Reason Exact -Details @{ Fqdn = $expectedServer }))
    }
    catch {
        [void]$components.Add((New-SetupCmMecmComponent -Name TargetHost -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }

    $prerequisiteProviders = [ordered]@{
        Adk = 'Adk'
        WinPe = 'WinPe'
        OdbcDriver18 = 'Odbc'
    }
    foreach ($componentName in $prerequisiteProviders.Keys) {
        $providerName = $prerequisiteProviders[$componentName]
        try {
            if ([bool](& $Providers[$providerName])) {
                [void]$components.Add((New-SetupCmMecmComponent -Name $componentName -State Compliant -Reason Exact))
            }
            else {
                [void]$components.Add((New-SetupCmMecmComponent -Name $componentName -State NotCompliant -Reason Missing))
            }
        }
        catch {
            [void]$components.Add((New-SetupCmMecmComponent -Name $componentName -State Conflict -Reason ProbeUnavailable))
        }
    }
    foreach ($architecture in 'x64', 'x86') {
        $componentName = "VcRuntime$($architecture.ToUpperInvariant())"
        try {
            if ([bool](& $Providers.VcRuntime $architecture)) {
                [void]$components.Add((New-SetupCmMecmComponent -Name $componentName -State Compliant -Reason Exact))
            }
            else {
                [void]$components.Add((New-SetupCmMecmComponent -Name $componentName -State NotCompliant -Reason Missing))
            }
        }
        catch {
            [void]$components.Add((New-SetupCmMecmComponent -Name $componentName -State Conflict -Reason ProbeUnavailable))
        }
    }

    try {
        $site = & $Providers.Site $Config
    }
    catch {
        [void]$components.Add((New-SetupCmMecmComponent -Name MecmSite -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    if ($null -eq $site) {
        [void]$components.Add((New-SetupCmMecmComponent -Name MecmSite -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    if (-not [bool](Get-SetupCmMecmObjectValue -InputObject $site -Name Exists -DefaultValue $false)) {
        if ([bool](Get-SetupCmMecmObjectValue -InputObject $site -Name ResidualState -DefaultValue $false)) {
            [void]$components.Add((New-SetupCmMecmComponent -Name MecmSite -State Conflict -Reason ResidualInstallationState))
        }
        else {
            [void]$components.Add((New-SetupCmMecmComponent -Name MecmSite -State NotCompliant -Reason Missing))
        }
        return New-SetupCmMecmDesiredStateResult -Components $components
    }

    $siteCount = [int](Get-SetupCmMecmObjectValue -InputObject $site -Name SiteCount -DefaultValue 1)
    $siteCode = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name SiteCode)
    $registrySiteCode = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name RegistrySiteCode -DefaultValue $siteCode)
    $siteName = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name SiteName)
    $siteServer = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name ServerName)
    $siteType = [int](Get-SetupCmMecmObjectValue -InputObject $site -Name Type -DefaultValue 0)
    $parentSiteCode = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name ParentSiteCode)
    $installDirectory = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name InstallDirectory)
    $expectedInstallDirectory = [string](Get-SetupCmMecmObjectValue -InputObject $Config.mecm -Name smsInstallDir)
    $siteIdentityExact = $siteCount -eq 1 -and
        $siteCode -ieq [string]$Config.mecm.siteCode -and
        $registrySiteCode -ieq [string]$Config.mecm.siteCode -and
        $siteName -ceq [string]$Config.mecm.siteName -and
        (Test-SetupCmMecmServerIdentity -Actual $siteServer -Expected $expectedServer -AllowShortName) -and
        $siteType -eq 2 -and
        [string]::IsNullOrWhiteSpace($parentSiteCode) -and
        (([string]::IsNullOrWhiteSpace($expectedInstallDirectory)) -or
            (ConvertTo-SetupCmMecmComparablePath -Path $installDirectory) -ieq
                (ConvertTo-SetupCmMecmComparablePath -Path $expectedInstallDirectory))
    if (-not $siteIdentityExact) {
        [void]$components.Add((New-SetupCmMecmComponent -Name MecmSite -State Conflict -Reason SiteIdentityMismatch -Details @{
            SiteCode = $siteCode; SiteName = $siteName; ServerName = $siteServer
            Type = $siteType; ParentSiteCode = $parentSiteCode; InstallDirectory = $installDirectory
        }))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }

    $providerCount = [int](Get-SetupCmMecmObjectValue -InputObject $site -Name ProviderCount -DefaultValue 0)
    $providerSiteCode = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name ProviderSiteCode)
    $providerMachine = [string](Get-SetupCmMecmObjectValue -InputObject $site -Name ProviderMachine)
    $providerLocal = [bool](Get-SetupCmMecmObjectValue -InputObject $site -Name ProviderForLocalSite -DefaultValue $false)
    if ($providerCount -ne 1 -or $providerSiteCode -ine [string]$Config.mecm.siteCode -or
        -not (Test-SetupCmMecmServerIdentity -Actual $providerMachine -Expected $expectedServer -AllowShortName) -or
        -not $providerLocal) {
        [void]$components.Add((New-SetupCmMecmComponent -Name MecmSite -State Conflict -Reason ProviderIdentityMismatch -Details @{
            ProviderCount = $providerCount; ProviderSiteCode = $providerSiteCode; ProviderMachine = $providerMachine
        }))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    [void]$components.Add((New-SetupCmMecmComponent -Name MecmSite -State Compliant -Reason Exact -Details @{
        SiteCode = $siteCode; SiteName = $siteName; ServerName = $siteServer; ProviderMachine = $providerMachine
    }))

    $requiredRoles = @('SMS Site Server', 'SMS Provider', 'SMS Management Point', 'SMS Distribution Point', 'SMS SQL Server')
    try {
        $roles = @(& $Providers.Roles $Config)
        $distributedRoles = @($roles | Where-Object {
            [string](Get-SetupCmMecmObjectValue -InputObject $_ -Name RoleName) -in $requiredRoles -and
            -not (Test-SetupCmMecmServerIdentity -Actual ([string](Get-SetupCmMecmObjectValue -InputObject $_ -Name ServerName)) -Expected $expectedServer -AllowShortName)
        })
        $missingRoles = @($requiredRoles | Where-Object {
            $requiredRole = $_
            @($roles | Where-Object {
                [string](Get-SetupCmMecmObjectValue -InputObject $_ -Name RoleName) -ceq $requiredRole -and
                [string](Get-SetupCmMecmObjectValue -InputObject $_ -Name SiteCode) -ieq [string]$Config.mecm.siteCode -and
                (Test-SetupCmMecmServerIdentity -Actual ([string](Get-SetupCmMecmObjectValue -InputObject $_ -Name ServerName)) -Expected $expectedServer -AllowShortName)
            }).Count -eq 0
        })
        if ($distributedRoles.Count -gt 0) {
            [void]$components.Add((New-SetupCmMecmComponent -Name MecmRoles -State Conflict -Reason DistributedRoleDetected))
        }
        elseif ($missingRoles.Count -gt 0) {
            [void]$components.Add((New-SetupCmMecmComponent -Name MecmRoles -State Conflict -Reason MissingRequiredRoles -Details @{ Missing = $missingRoles }))
        }
        else {
            [void]$components.Add((New-SetupCmMecmComponent -Name MecmRoles -State Compliant -Reason Exact -Details @{ Required = $requiredRoles }))
        }
    }
    catch {
        [void]$components.Add((New-SetupCmMecmComponent -Name MecmRoles -State Conflict -Reason ProbeUnavailable))
    }

    $requiredServices = @('SMS_EXECUTIVE', 'SMS_SITE_COMPONENT_MANAGER')
    try {
        $services = @(& $Providers.Services)
        $missingServices = @($requiredServices | Where-Object {
            $requiredService = $_
            @($services | Where-Object {
                [string](Get-SetupCmMecmObjectValue -InputObject $_ -Name Name) -ieq $requiredService
            }).Count -eq 0
        })
        if ($missingServices.Count -gt 0) {
            [void]$components.Add((New-SetupCmMecmComponent -Name MecmServices -State Conflict -Reason MissingOnInstalledSite -Details @{
                Missing = $missingServices
            }))
        }
        else {
            $repairServices = @($requiredServices | Where-Object {
                $requiredService = $_
                $service = $services | Where-Object {
                    [string](Get-SetupCmMecmObjectValue -InputObject $_ -Name Name) -ieq $requiredService
                } | Select-Object -First 1
                $status = [string](Get-SetupCmMecmObjectValue -InputObject $service -Name Status)
                $startType = [string](Get-SetupCmMecmObjectValue -InputObject $service -Name StartType)
                $status -ine 'Running' -or $startType -notin 'Automatic', 'Auto'
            })
            if ($repairServices.Count -gt 0) {
                [void]$components.Add((New-SetupCmMecmComponent -Name MecmServices -State NotCompliant -Reason ServiceState -Details @{
                    Repair = $repairServices
                }))
            }
            else {
                [void]$components.Add((New-SetupCmMecmComponent -Name MecmServices -State Compliant -Reason Exact))
            }
        }
    }
    catch {
        [void]$components.Add((New-SetupCmMecmComponent -Name MecmServices -State Conflict -Reason ProbeUnavailable))
    }

    try {
        $content = & $Providers.ContentLibrary
        $contentPath = [string](Get-SetupCmMecmObjectValue -InputObject $content -Name Path)
        $contentAccessible = [bool](Get-SetupCmMecmObjectValue -InputObject $content -Name Accessible -DefaultValue $false)
        $contentSiteCode = [string](Get-SetupCmMecmObjectValue -InputObject $content -Name SiteCode)
        if (-not $contentAccessible) {
            [void]$components.Add((New-SetupCmMecmComponent -Name ContentLibrary -State Conflict -Reason Unavailable -Details @{ Path = $contentPath }))
        }
        elseif ($contentSiteCode -ine [string]$Config.mecm.siteCode) {
            [void]$components.Add((New-SetupCmMecmComponent -Name ContentLibrary -State Conflict -Reason SiteIdentityMismatch -Details @{ SiteCode = $contentSiteCode }))
        }
        else {
            [void]$components.Add((New-SetupCmMecmComponent -Name ContentLibrary -State Compliant -Reason Exact -Details @{ Path = $contentPath }))
        }
    }
    catch {
        [void]$components.Add((New-SetupCmMecmComponent -Name ContentLibrary -State Conflict -Reason ProbeUnavailable))
    }

    if (-not $Config.ContainsKey('testClient') -or [string]::IsNullOrWhiteSpace([string]$Config.testClient.name)) {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClient -State Conflict -Reason MissingConfiguration))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    $expectedClientName = [string]$Config.testClient.name
    $expectedResourceId = Get-SetupCmMecmExpectedClientResourceId -Config $Config
    try {
        $providerClients = @(& $Providers.ClientProvider $Config)
    }
    catch {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClient -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    if ($providerClients.Count -ne 1) {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClient -State Conflict -Reason ResourceCardinality -Details @{
            Count = $providerClients.Count
        }))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    $providerClient = $providerClients[0]
    $providerResourceId = [int](Get-SetupCmMecmObjectValue -InputObject $providerClient -Name ResourceId)
    $providerClientExact = [string](Get-SetupCmMecmObjectValue -InputObject $providerClient -Name Name) -ieq $expectedClientName -and
        [int](Get-SetupCmMecmObjectValue -InputObject $providerClient -Name Active) -eq 1 -and
        [int](Get-SetupCmMecmObjectValue -InputObject $providerClient -Name Obsolete) -eq 0 -and
        [int](Get-SetupCmMecmObjectValue -InputObject $providerClient -Name Client) -eq 1
    if (($null -ne $expectedResourceId -and $providerResourceId -ne $expectedResourceId) -or -not $providerClientExact) {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClient -State Conflict -Reason ResourceIdentityMismatch -Details @{
            ClientName = [string](Get-SetupCmMecmObjectValue -InputObject $providerClient -Name Name)
            ResourceId = $providerResourceId
        }))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClient -State Compliant -Reason Exact -Details @{
        ClientName = $expectedClientName; ResourceId = $providerResourceId
        ClientVersion = [string](Get-SetupCmMecmObjectValue -InputObject $providerClient -Name ClientVersion)
    }))

    try {
        $databaseClientState = & $Providers.ClientDatabase $Config
    }
    catch {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClientSql -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    $databaseName = [string](Get-SetupCmMecmObjectValue -InputObject $databaseClientState -Name DatabaseName)
    $databaseServer = [string](Get-SetupCmMecmObjectValue -InputObject $databaseClientState -Name ServerName)
    $expectedDatabase = "CM_$($Config.mecm.siteCode)"
    if ($databaseName -ine $expectedDatabase -or
        -not (Test-SetupCmMecmServerIdentity -Actual $databaseServer -Expected ([string]$Config.mecm.sqlServer) -AllowShortName)) {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClientSql -State Conflict -Reason DatabaseIdentityMismatch -Details @{
            DatabaseName = $databaseName; ServerName = $databaseServer
        }))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    $databaseClients = @(Get-SetupCmMecmObjectValue -InputObject $databaseClientState -Name Rows -DefaultValue @())
    if ($databaseClients.Count -ne 1) {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClientSql -State Conflict -Reason ResourceCardinality -Details @{
            Count = $databaseClients.Count
        }))
        return New-SetupCmMecmDesiredStateResult -Components $components
    }
    $databaseClient = $databaseClients[0]
    $providerVersion = [string](Get-SetupCmMecmObjectValue -InputObject $providerClient -Name ClientVersion)
    $databaseVersion = [string](Get-SetupCmMecmObjectValue -InputObject $databaseClient -Name ClientVersion)
    $sqlExact = [string](Get-SetupCmMecmObjectValue -InputObject $databaseClient -Name Name) -ieq $expectedClientName -and
        [int](Get-SetupCmMecmObjectValue -InputObject $databaseClient -Name ResourceId) -eq $providerResourceId -and
        [int](Get-SetupCmMecmObjectValue -InputObject $databaseClient -Name Active) -eq 1 -and
        [int](Get-SetupCmMecmObjectValue -InputObject $databaseClient -Name Obsolete) -eq 0 -and
        [int](Get-SetupCmMecmObjectValue -InputObject $databaseClient -Name Client) -eq 1 -and
        $databaseVersion -ceq $providerVersion
    if (-not $sqlExact) {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClientSql -State Conflict -Reason ProviderSqlMismatch -Details @{
            ProviderResourceId = $providerResourceId
            SqlResourceId = [int](Get-SetupCmMecmObjectValue -InputObject $databaseClient -Name ResourceId)
        }))
    }
    else {
        [void]$components.Add((New-SetupCmMecmComponent -Name AcceptedClientSql -State Compliant -Reason Exact -Details @{
            DatabaseName = $databaseName; ResourceId = $providerResourceId; ClientVersion = $databaseVersion
        }))
    }

    return New-SetupCmMecmDesiredStateResult -Components $components
}

function Test-SetupCmMecmDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [hashtable]$Providers,
        [switch]$PassThru
    )

    $state = Get-SetupCmMecmDesiredState -Config $Config -Providers $Providers
    Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'mecm-state' -Value $state | Out-Null
    if ($PassThru) { return $state }
    return [string]$state.State
}

function Set-SetupCmMecmServiceState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('SMS_EXECUTIVE', 'SMS_SITE_COMPONENT_MANAGER')][string]$Name)

    if (-not $IsWindows) { throw 'MECM service configuration can only run on Windows Server.' }
    Set-Service -Name $Name -StartupType Automatic -ErrorAction Stop
    $service = Get-Service -Name $Name -ErrorAction Stop
    if ($service.Status -ne 'Running') { Start-Service -Name $Name -ErrorAction Stop }
}

function Repair-SetupCmMecmDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    $aggregateState = if ($State -is [string]) { [string]$State } else { [string]$State.State }
    if ($aggregateState -eq 'Conflict') {
        throw 'MECM desired state contains a conflict and cannot be repaired automatically.'
    }
    if ($aggregateState -eq 'Compliant') { return }
    if ($State -is [string]) { throw 'A structured MECM desired state is required for minimal repair.' }

    $repairable = @($State.Components | Where-Object State -eq 'NotCompliant')
    $sourceByComponent = @{
        Adk = 'adk'
        WinPe = 'adkWinPe'
        OdbcDriver18 = 'odbcDriver18'
        VcRuntimeX64 = 'vcRedistX64'
        VcRuntimeX86 = 'vcRedistX86'
        MecmSite = 'mecm'
    }
    $requiredSources = [System.Collections.Generic.List[string]]::new()
    foreach ($component in $repairable) {
        if ($sourceByComponent.ContainsKey([string]$component.Name)) {
            $sourceName = $sourceByComponent[[string]$component.Name]
            if ($sourceName -notin $requiredSources) { [void]$requiredSources.Add($sourceName) }
        }
    }
    foreach ($sourceName in $requiredSources) {
        if (-not $Config.ContainsKey('sources') -or -not $Config.sources.ContainsKey($sourceName)) {
            throw "sources.$sourceName is required before MECM repair."
        }
    }

    foreach ($componentName in 'VcRuntimeX64', 'VcRuntimeX86') {
        if (@($repairable | Where-Object Name -eq $componentName).Count -eq 0) { continue }
        $sourceName = $sourceByComponent[$componentName]
        Install-SetupCmMecmVcRedist -Source $Config.sources[$sourceName] -CacheRoot $Config.cacheRoot -EvidenceRoot $EvidenceRoot
    }
    if (@($repairable | Where-Object Name -eq 'Adk').Count -gt 0) {
        Install-SetupCmMecmAdk -Source $Config.sources.adk -CacheRoot $Config.cacheRoot -EvidenceRoot $EvidenceRoot
    }
    if (@($repairable | Where-Object Name -eq 'WinPe').Count -gt 0) {
        Install-SetupCmMecmWinPeAddOn -Source $Config.sources.adkWinPe -CacheRoot $Config.cacheRoot -EvidenceRoot $EvidenceRoot
    }
    if (@($repairable | Where-Object Name -eq 'OdbcDriver18').Count -gt 0) {
        Install-SetupCmMecmOdbcDriver18 -Source $Config.sources.odbcDriver18 -CacheRoot $Config.cacheRoot -EvidenceRoot $EvidenceRoot
    }
    foreach ($serviceState in @($repairable | Where-Object Name -eq 'MecmServices')) {
        foreach ($serviceName in @($serviceState.Repair)) {
            Set-SetupCmMecmServiceState -Name $serviceName
        }
    }
    if (@($repairable | Where-Object Name -eq 'MecmSite').Count -gt 0) {
        $media = Get-SetupCmArtifact -Source $Config.sources.mecm -CacheRoot $Config.cacheRoot -EvidenceRoot $EvidenceRoot
        Get-SetupCmMecmPrerequisites -MediaPath $media.Path -PrerequisitePath $Config.mecm.prerequisitePath | Out-Null
        Install-SetupCmPrimarySite -MediaPath $media.Path -Mecm $Config.mecm -EvidenceRoot $EvidenceRoot | Out-Null
    }
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

function Install-SetupCmMecmVcRedist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Source,
        [Parameter(Mandatory)][string]$CacheRoot,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    if (-not $IsWindows) { throw 'Microsoft Visual C++ Redistributable installation can only run on Windows Server.' }
    $artifact = Get-SetupCmArtifact -Source $Source -CacheRoot $CacheRoot -EvidenceRoot $EvidenceRoot
    $process = Start-Process -FilePath $artifact.Path -ArgumentList @('/install', '/quiet', '/norestart') -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -eq 3010) {
        throw 'Microsoft Visual C++ Redistributable installation requires a restart before MECM setup can continue (exit code 3010).'
    }
    if ($process.ExitCode -ne 0) {
        throw "Microsoft Visual C++ Redistributable installation failed with exit code $($process.ExitCode)."
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
