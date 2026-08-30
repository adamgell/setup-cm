function Test-SetupCmSql {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstanceName,
        [scriptblock]$ServiceStateProvider = { param($Name) Get-Service -Name $Name -ErrorAction SilentlyContinue }
    )

    $serviceName = if ($InstanceName -ieq 'MSSQLSERVER') { 'MSSQLSERVER' } else { "MSSQL`$$InstanceName" }
    $service = & $ServiceStateProvider $serviceName
    if ($null -ne $service -and $service.Status -eq 'Running') { return 'Compliant' }
    return 'NotCompliant'
}

function Test-SetupCmSqlNetwork {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstanceName,
        [scriptblock]$RegistryProvider = {
            param($Name)
            $instanceId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction Stop).$Name
            if ([string]::IsNullOrWhiteSpace($instanceId)) { return $null }
            $tcpPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp"
            $tcp = Get-ItemProperty -Path $tcpPath -ErrorAction Stop
            $ipAll = Get-ItemProperty -Path "$tcpPath\IPAll" -ErrorAction Stop
            [pscustomobject]@{ Enabled = $tcp.Enabled; TcpPort = $ipAll.TcpPort; TcpDynamicPorts = $ipAll.TcpDynamicPorts }
        },
        [scriptblock]$ListenerProvider = { Get-NetTCPConnection -LocalPort 1433 -State Listen -ErrorAction SilentlyContinue }
    )

    $tcp = & $RegistryProvider $InstanceName
    if ($null -eq $tcp -or $tcp.Enabled -ne 1 -or $tcp.TcpPort -ne '1433' -or -not [string]::IsNullOrEmpty($tcp.TcpDynamicPorts)) {
        return 'NotCompliant'
    }
    if ($null -eq (& $ListenerProvider)) { return 'NotCompliant' }
    return 'Compliant'
}

function Get-SetupCmSqlServiceName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstanceName)

    if ($InstanceName -ieq 'MSSQLSERVER') { return 'MSSQLSERVER' }
    return "MSSQL`$$InstanceName"
}

function Get-SetupCmSqlObjectValue {
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

function ConvertTo-SetupCmSqlComparablePath {
    [CmdletBinding()]
    param([AllowNull()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return $Path.Trim().TrimEnd('\', '/')
}

function Test-SetupCmSqlInstallDirectoryMatch {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Actual,
        [AllowNull()][string]$Expected
    )

    if ([string]::IsNullOrWhiteSpace($Expected)) { return $true }
    $actualPath = ConvertTo-SetupCmSqlComparablePath -Path $Actual
    $expectedPath = ConvertTo-SetupCmSqlComparablePath -Path $Expected
    if ([string]::IsNullOrWhiteSpace($actualPath)) { return $false }
    if ($actualPath -ieq $expectedPath) { return $true }
    return $actualPath.StartsWith("$expectedPath\", [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-SetupCmSqlComparableAccount {
    [CmdletBinding()]
    param([AllowNull()][string]$Account)

    if ([string]::IsNullOrWhiteSpace($Account)) { return '' }
    $normalized = $Account.Trim()
    switch -Regex ($normalized) {
        '^(?i)NT AUTHORITY\\NETWORK\s*SERVICE$' { return 'NT AUTHORITY\NETWORK SERVICE' }
        '^(?i)(?:NT AUTHORITY\\SYSTEM|LOCALSYSTEM)$' { return 'NT AUTHORITY\SYSTEM' }
        default { return $normalized.ToUpperInvariant() }
    }
}

function New-SetupCmSqlComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Compliant', 'NotCompliant', 'Conflict')][string]$State,
        [Parameter(Mandatory)][string]$Reason,
        [hashtable]$Details = @{}
    )

    $component = [ordered]@{ Name = $Name; State = $State; Reason = $Reason }
    foreach ($key in $Details.Keys) { $component[$key] = $Details[$key] }
    return [pscustomobject]$component
}

function New-SetupCmSqlDesiredStateResult {
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

function Get-SetupCmSqlConnectionServer {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config)

    if (-not $Config.ContainsKey('sql') -or $Config.sql -isnot [hashtable] -or
        -not $Config.sql.ContainsKey('instanceName') -or
        [string]::IsNullOrWhiteSpace([string]$Config.sql.instanceName)) {
        throw 'sql.instanceName is required for SQL connectivity.'
    }
    if (-not $Config.ContainsKey('mecm') -or $Config.mecm -isnot [hashtable]) {
        throw 'mecm.sqlServer or mecm.siteServerFqdn is required for SQL connectivity.'
    }
    $server = if ($Config.mecm.ContainsKey('sqlServer') -and
        -not [string]::IsNullOrWhiteSpace([string]$Config.mecm.sqlServer)) {
        [string]$Config.mecm.sqlServer
    }
    elseif ($Config.mecm.ContainsKey('siteServerFqdn') -and
        -not [string]::IsNullOrWhiteSpace([string]$Config.mecm.siteServerFqdn)) {
        [string]$Config.mecm.siteServerFqdn
    }
    else {
        throw 'mecm.sqlServer or mecm.siteServerFqdn is required for SQL connectivity.'
    }
    $server
}

function New-SetupCmSqlConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [string]$Database = 'master'
    )

    $server = Get-SetupCmSqlConnectionServer -Config $Config
    Add-Type -AssemblyName System.Data.Odbc -ErrorAction Stop
    $instanceName = [string]$Config.sql.instanceName
    $dataSource = if ($instanceName -ieq 'MSSQLSERVER') { $server } else { "$server\$instanceName" }

    $builder = [System.Data.Odbc.OdbcConnectionStringBuilder]::new()
    $builder['Driver'] = '{ODBC Driver 18 for SQL Server}'
    $builder['Server'] = $dataSource
    $builder['Database'] = $Database
    $builder['Trusted_Connection'] = 'Yes'
    $builder['Encrypt'] = 'Yes'
    $builder['TrustServerCertificate'] = 'No'
    $builder['Connection Timeout'] = 10
    $builder['Application Name'] = 'setup-cm'
    return [System.Data.Odbc.OdbcConnection]::new($builder.ConnectionString)
}

function Add-SetupCmSqlNVarCharParameter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Command,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')][string]$Name,
        [Parameter(Mandatory)][ValidateRange(1, 4000)][int]$Size,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    $parameter = $Command.CreateParameter()
    $parameter.ParameterName = $Name
    $parameter.OdbcType = [System.Data.Odbc.OdbcType]::NVarChar
    $parameter.Size = $Size
    $parameter.Value = $Value
    [void]$Command.Parameters.Add($parameter)
    return $parameter
}

function Get-SetupCmSqlDefaultProviders {
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
        WindowsFeatures = {
            param($RequiredFeatures)
            @(Get-WindowsFeature -Name $RequiredFeatures -ErrorAction Stop |
                Where-Object Installed |
                Select-Object -ExpandProperty Name)
        }
        Instance = {
            param($InstanceName)
            $mapping = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction SilentlyContinue
            if ($null -eq $mapping) {
                return @{ Exists = $false; InstanceName = $null; OtherInstances = @() }
            }
            $instanceNames = @($mapping.PSObject.Properties |
                Where-Object { $_.Name -notlike 'PS*' } |
                Select-Object -ExpandProperty Name)
            $match = @($instanceNames | Where-Object { $_ -ieq $InstanceName }) | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace([string]$match)) {
                return @{ Exists = $false; InstanceName = $null; OtherInstances = $instanceNames }
            }
            $instanceId = [string]$mapping.PSObject.Properties[[string]$match].Value
            $setup = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\Setup" -ErrorAction Stop
            $installDirectory = @([string]$setup.SQLPath, [string]$setup.SQLDataRoot) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -First 1
            @{
                Exists = $true
                InstanceName = [string]$match
                InstanceId = $instanceId
                InstallDirectory = $installDirectory
                OtherInstances = @($instanceNames | Where-Object { $_ -ine $InstanceName })
            }
        }
        Service = {
            param($ServiceName)
            $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($ServiceName.Replace("'", "''"))'" -ErrorAction Stop
            if ($null -eq $service) { return $null }
            @{
                Status = [string]$service.State
                StartType = [string]$service.StartMode
                StartName = [string]$service.StartName
            }
        }
        Network = {
            param($InstanceName)
            $instanceId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction Stop).$InstanceName
            if ([string]::IsNullOrWhiteSpace([string]$instanceId)) { return $null }
            $tcpPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp"
            $tcp = Get-ItemProperty -Path $tcpPath -ErrorAction Stop
            $ipAll = Get-ItemProperty -Path "$tcpPath\IPAll" -ErrorAction Stop
            @{
                Enabled = $tcp.Enabled
                TcpPort = [string]$ipAll.TcpPort
                TcpDynamicPorts = [string]$ipAll.TcpDynamicPorts
                Listening = $null -ne (Get-NetTCPConnection -LocalPort 1433 -State Listen -ErrorAction SilentlyContinue |
                    Select-Object -First 1)
            }
        }
        Firewall = {
            $rules = @(Get-NetFirewallRule -DisplayName 'Setup-CM SQL Server TCP 1433' -ErrorAction SilentlyContinue)
            if ($rules.Count -eq 0) { return @{ Exists = $false; Count = 0; Compliant = $false } }
            $filters = @($rules | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue)
            $exactRule = $rules.Count -eq 1 -and
                [string]$rules[0].Enabled -ieq 'True' -and
                [string]$rules[0].Direction -ieq 'Inbound' -and
                [string]$rules[0].Action -ieq 'Allow'
            $exactFilter = $filters.Count -eq 1 -and
                [string]$filters[0].Protocol -in 'TCP', '6' -and
                [string]$filters[0].LocalPort -eq '1433'
            @{ Exists = $true; Count = $rules.Count; Compliant = $exactRule -and $exactFilter }
        }
        Odbc = { (Test-SetupCmOdbcDriver18) -eq 'Compliant' }
        VcRuntime = {
            param($Architecture)
            (Test-SetupCmMecmVcRedistArchitecture -Architecture $Architecture) -eq 'Compliant'
        }
        Site = {
            try {
                @(
                    Get-CimInstance -Namespace 'root\SMS' -ClassName SMS_ProviderLocation -ErrorAction Stop
                ).Count -gt 0
            }
            catch {
                if ($_.Exception.Message -match '(?i)invalid namespace|invalid class|0x8004100e|0x80041010') {
                    return $false
                }
                throw
            }
        }
        Database = {
            param($Config)
            $master = New-SetupCmSqlConnection -Config $Config -Database 'master'
            try {
                $master.Open()

                $instanceCommand = $master.CreateCommand()
                $instanceCommand.CommandText = "SELECT COALESCE(CAST(SERVERPROPERTY('InstanceName') AS nvarchar(128)), N'MSSQLSERVER')"
                $actualInstance = [string]$instanceCommand.ExecuteScalar()

                $databaseName = "CM_$($Config.mecm.siteCode)"
                $databaseCommand = $master.CreateCommand()
                $databaseCommand.CommandText = @'
DECLARE @DatabaseName nvarchar(128) = ?;
SELECT CASE WHEN DB_ID(@DatabaseName) IS NULL THEN 0 ELSE 1 END;
'@
                Add-SetupCmSqlNVarCharParameter -Command $databaseCommand -Name DatabaseName -Size 128 -Value $databaseName | Out-Null
                $databaseExists = [int]$databaseCommand.ExecuteScalar() -eq 1

                $roleCommand = $master.CreateCommand()
                $roleCommand.CommandText = @'
SELECT member_principal.name
FROM sys.server_role_members AS role_membership
JOIN sys.server_principals AS role_principal
    ON role_principal.principal_id = role_membership.role_principal_id
JOIN sys.server_principals AS member_principal
    ON member_principal.principal_id = role_membership.member_principal_id
WHERE role_principal.name = N'sysadmin'
'@
                $sysAdmins = [System.Collections.Generic.List[string]]::new()
                $reader = $roleCommand.ExecuteReader()
                try {
                    while ($reader.Read()) { [void]$sysAdmins.Add($reader.GetString(0)) }
                }
                finally {
                    $reader.Dispose()
                }
            }
            finally {
                $master.Dispose()
            }

            $databaseReachable = $false
            if ($databaseExists) {
                $siteDatabase = New-SetupCmSqlConnection -Config $Config -Database $databaseName
                try {
                    $siteDatabase.Open()
                    $query = $siteDatabase.CreateCommand()
                    $query.CommandText = 'SELECT 1'
                    $databaseReachable = [int]$query.ExecuteScalar() -eq 1
                }
                finally {
                    $siteDatabase.Dispose()
                }
            }

            @{
                MasterReachable = $true
                InstanceName = $actualInstance
                DatabaseReachable = $databaseReachable
                SysAdminAccounts = @($sysAdmins)
            }
        }
    }
}

function Get-SetupCmSqlDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [hashtable]$Providers
    )

    $components = [System.Collections.Generic.List[object]]::new()
    if (-not $Config.ContainsKey('topology') -or [string]$Config.topology -cne 'single-box') {
        [void]$components.Add((New-SetupCmSqlComponent -Name TargetHost -State Conflict -Reason UnsupportedTopology))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }
    if (-not $Config.ContainsKey('mecm') -or
        $Config.mecm -isnot [hashtable] -or
        -not $Config.mecm.ContainsKey('siteServerFqdn') -or
        [string]::IsNullOrWhiteSpace([string]$Config.mecm.siteServerFqdn)) {
        [void]$components.Add((New-SetupCmSqlComponent -Name TargetHost -State Conflict -Reason MissingExpectedHost))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }
    if (-not $Config.ContainsKey('sql') -or
        $Config.sql -isnot [hashtable] -or
        -not $Config.sql.ContainsKey('instanceName') -or
        [string]::IsNullOrWhiteSpace([string]$Config.sql.instanceName)) {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Conflict -Reason MissingInstanceName))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }
    $configuredSysAdmins = @(
        if ($Config.sql.ContainsKey('sysAdminAccounts')) {
            $Config.sql.sysAdminAccounts |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        }
    )
    if ($configuredSysAdmins.Count -eq 0) {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlSysAdmins -State Conflict -Reason MissingSysAdminAccounts))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }
    if ($null -eq $Providers) { $Providers = Get-SetupCmSqlDefaultProviders }

    try {
        $hostState = & $Providers.Host
        $actualFqdn = [string](Get-SetupCmSqlObjectValue -InputObject $hostState -Name Fqdn)
        $expectedFqdn = ([string]$Config.mecm.siteServerFqdn).TrimEnd('.')
        if ([string]::IsNullOrWhiteSpace($actualFqdn) -or $actualFqdn.TrimEnd('.') -ine $expectedFqdn) {
            [void]$components.Add((New-SetupCmSqlComponent -Name TargetHost -State Conflict -Reason HostMismatch -Details @{
                Expected = $expectedFqdn
                Actual = $actualFqdn
            }))
            return New-SetupCmSqlDesiredStateResult -Components $components
        }
        [void]$components.Add((New-SetupCmSqlComponent -Name TargetHost -State Compliant -Reason Exact -Details @{ Fqdn = $expectedFqdn }))
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name TargetHost -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }

    $requiredFeatures = @('NET-Framework-Features', 'BITS', 'Web-Server')
    try {
        $installedFeatures = @(& $Providers.WindowsFeatures $requiredFeatures)
        $missingFeatures = @($requiredFeatures | Where-Object { $_ -notin $installedFeatures })
        if ($missingFeatures.Count -gt 0) {
            [void]$components.Add((New-SetupCmSqlComponent -Name WindowsFeatures -State NotCompliant -Reason Missing -Details @{
                Missing = $missingFeatures
            }))
        }
        else {
            [void]$components.Add((New-SetupCmSqlComponent -Name WindowsFeatures -State Compliant -Reason Exact))
        }
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name WindowsFeatures -State Conflict -Reason ProbeUnavailable))
    }

    foreach ($architecture in 'x64', 'x86') {
        $componentName = "VcRuntime$($architecture.ToUpperInvariant())"
        try {
            if ([bool](& $Providers.VcRuntime $architecture)) {
                [void]$components.Add((New-SetupCmSqlComponent -Name $componentName -State Compliant -Reason Exact))
            }
            else {
                [void]$components.Add((New-SetupCmSqlComponent -Name $componentName -State NotCompliant -Reason Missing))
            }
        }
        catch {
            [void]$components.Add((New-SetupCmSqlComponent -Name $componentName -State Conflict -Reason ProbeUnavailable))
        }
    }

    $odbcAvailable = $false
    try {
        if ([bool](& $Providers.Odbc)) {
            $odbcAvailable = $true
            [void]$components.Add((New-SetupCmSqlComponent -Name OdbcDriver18 -State Compliant -Reason Exact))
        }
        else {
            [void]$components.Add((New-SetupCmSqlComponent -Name OdbcDriver18 -State NotCompliant -Reason Missing))
        }
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name OdbcDriver18 -State Conflict -Reason ProbeUnavailable))
    }

    $instanceName = [string]$Config.sql.instanceName
    try {
        $instance = & $Providers.Instance $instanceName
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }
    if ($null -eq $instance) {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Conflict -Reason ProbeUnavailable))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }

    $instanceExists = [bool](Get-SetupCmSqlObjectValue -InputObject $instance -Name Exists -DefaultValue $false)
    if (-not $instanceExists) {
        $otherInstances = @(Get-SetupCmSqlObjectValue -InputObject $instance -Name OtherInstances -DefaultValue @())
        if ($otherInstances.Count -gt 0) {
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Conflict -Reason DifferentInstancePresent -Details @{
                ExistingInstances = $otherInstances
            }))
        }
        else {
            try {
                $siteExistsWithoutInstance = [bool](& $Providers.Site)
                if ($siteExistsWithoutInstance) {
                    [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Conflict -Reason SitePresentWithoutInstance))
                }
                else {
                    [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State NotCompliant -Reason Missing))
                }
            }
            catch {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Conflict -Reason SiteProbeUnavailable))
            }
        }
        return New-SetupCmSqlDesiredStateResult -Components $components
    }

    $actualInstanceName = [string](Get-SetupCmSqlObjectValue -InputObject $instance -Name InstanceName)
    if ($actualInstanceName -ine $instanceName) {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Conflict -Reason InstanceMismatch -Details @{
            Expected = $instanceName
            Actual = $actualInstanceName
        }))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }
    $expectedInstallDirectory = [string](Get-SetupCmSqlObjectValue -InputObject $Config.sql -Name installDirectory)
    $actualInstallDirectory = [string](Get-SetupCmSqlObjectValue -InputObject $instance -Name InstallDirectory)
    if (-not (Test-SetupCmSqlInstallDirectoryMatch -Actual $actualInstallDirectory -Expected $expectedInstallDirectory)) {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Conflict -Reason InstallDirectoryMismatch -Details @{
            ExpectedInstallDirectory = $expectedInstallDirectory
            ActualInstallDirectory = $actualInstallDirectory
        }))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }
    [void]$components.Add((New-SetupCmSqlComponent -Name SqlInstance -State Compliant -Reason Exact -Details @{
        InstanceName = $instanceName
        InstallDirectory = $actualInstallDirectory
    }))

    $serviceName = Get-SetupCmSqlServiceName -InstanceName $instanceName
    try {
        $service = & $Providers.Service $serviceName
        if ($null -eq $service) {
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlService -State Conflict -Reason MissingOnInstalledInstance))
        }
        else {
            $serviceStatus = [string](Get-SetupCmSqlObjectValue -InputObject $service -Name Status)
            $startType = [string](Get-SetupCmSqlObjectValue -InputObject $service -Name StartType)
            $serviceCompliant = $serviceStatus -ieq 'Running' -and $startType -in 'Automatic', 'Auto'
            if ($serviceCompliant) {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlService -State Compliant -Reason Exact))
            }
            else {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlService -State NotCompliant -Reason ServiceState -Details @{
                    Status = $serviceStatus
                    StartType = $startType
                }))
            }

            $expectedAccount = if ($Config.sql.ContainsKey('serviceAccount') -and
                -not [string]::IsNullOrWhiteSpace([string]$Config.sql.serviceAccount)) {
                [string]$Config.sql.serviceAccount
            }
            else {
                'NT AUTHORITY\NETWORK SERVICE'
            }
            $actualAccount = [string](Get-SetupCmSqlObjectValue -InputObject $service -Name StartName)
            if ((ConvertTo-SetupCmSqlComparableAccount -Account $actualAccount) -ne
                (ConvertTo-SetupCmSqlComparableAccount -Account $expectedAccount)) {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlServiceAccount -State Conflict -Reason AccountMismatch -Details @{
                    Expected = $expectedAccount
                    Actual = $actualAccount
                }))
            }
            else {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlServiceAccount -State Compliant -Reason Exact))
            }
        }
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlService -State Conflict -Reason ProbeUnavailable))
    }

    try {
        $network = & $Providers.Network $instanceName
        if ($null -eq $network) {
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlNetwork -State Conflict -Reason ProbeUnavailable))
        }
        else {
            $networkCompliant = [int](Get-SetupCmSqlObjectValue -InputObject $network -Name Enabled -DefaultValue 0) -eq 1 -and
                [string](Get-SetupCmSqlObjectValue -InputObject $network -Name TcpPort) -eq '1433' -and
                [string]::IsNullOrEmpty([string](Get-SetupCmSqlObjectValue -InputObject $network -Name TcpDynamicPorts)) -and
                [bool](Get-SetupCmSqlObjectValue -InputObject $network -Name Listening -DefaultValue $false)
            if ($networkCompliant) {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlNetwork -State Compliant -Reason Exact))
            }
            else {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlNetwork -State NotCompliant -Reason Tcp1433Unavailable))
            }
        }
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlNetwork -State Conflict -Reason ProbeUnavailable))
    }

    try {
        $firewall = & $Providers.Firewall
        if ($firewall -is [bool]) {
            if ($firewall) {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlFirewall -State Compliant -Reason Exact))
            }
            else {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlFirewall -State NotCompliant -Reason Missing))
            }
        }
        else {
            $ruleCount = [int](Get-SetupCmSqlObjectValue -InputObject $firewall -Name Count -DefaultValue 0)
            $ruleExists = [bool](Get-SetupCmSqlObjectValue -InputObject $firewall -Name Exists -DefaultValue $false)
            $ruleCompliant = [bool](Get-SetupCmSqlObjectValue -InputObject $firewall -Name Compliant -DefaultValue $false)
            if ($ruleCount -gt 1) {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlFirewall -State Conflict -Reason DuplicateRules))
            }
            elseif ($ruleCompliant) {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlFirewall -State Compliant -Reason Exact))
            }
            elseif (-not $ruleExists) {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlFirewall -State NotCompliant -Reason Missing))
            }
            else {
                [void]$components.Add((New-SetupCmSqlComponent -Name SqlFirewall -State NotCompliant -Reason RuleDrift))
            }
        }
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlFirewall -State Conflict -Reason ProbeUnavailable))
    }

    try {
        $siteExists = [bool](& $Providers.Site)
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlDatabase -State Conflict -Reason SiteProbeUnavailable))
        return New-SetupCmSqlDesiredStateResult -Components $components
    }

    if (-not $odbcAvailable) {
        return New-SetupCmSqlDesiredStateResult -Components $components
    }

    try {
        $database = & $Providers.Database $Config
        if ($null -eq $database -or
            -not [bool](Get-SetupCmSqlObjectValue -InputObject $database -Name MasterReachable -DefaultValue $false)) {
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlDatabase -State Conflict -Reason ProbeUnavailable))
            return New-SetupCmSqlDesiredStateResult -Components $components
        }
        $databaseInstance = [string](Get-SetupCmSqlObjectValue -InputObject $database -Name InstanceName)
        if ($databaseInstance -ine $instanceName) {
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlDatabase -State Conflict -Reason InstanceMismatch -Details @{
                Expected = $instanceName
                Actual = $databaseInstance
            }))
            return New-SetupCmSqlDesiredStateResult -Components $components
        }
        $databaseReachable = [bool](Get-SetupCmSqlObjectValue -InputObject $database -Name DatabaseReachable -DefaultValue $false)
        if ($siteExists -and -not $databaseReachable) {
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlDatabase -State Conflict -Reason SiteDatabaseUnavailable))
        }
        else {
            $reason = if ($siteExists) { 'SiteDatabaseReachable' } else { 'MasterReachable' }
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlDatabase -State Compliant -Reason $reason))
        }

        $actualSysAdmins = @(Get-SetupCmSqlObjectValue -InputObject $database -Name SysAdminAccounts -DefaultValue @())
        $missingSysAdmins = @($configuredSysAdmins | Where-Object {
            $configured = ConvertTo-SetupCmSqlComparableAccount -Account ([string]$_)
            $configured -notin @($actualSysAdmins | ForEach-Object {
                ConvertTo-SetupCmSqlComparableAccount -Account ([string]$_)
            })
        })
        if ($missingSysAdmins.Count -gt 0) {
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlSysAdmins -State NotCompliant -Reason Missing -Details @{
                Missing = $missingSysAdmins
            }))
        }
        else {
            [void]$components.Add((New-SetupCmSqlComponent -Name SqlSysAdmins -State Compliant -Reason Exact))
        }
    }
    catch {
        [void]$components.Add((New-SetupCmSqlComponent -Name SqlDatabase -State Conflict -Reason ProbeUnavailable))
    }

    return New-SetupCmSqlDesiredStateResult -Components $components
}

function Test-SetupCmSqlDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [hashtable]$Providers,
        [switch]$PassThru
    )

    $state = Get-SetupCmSqlDesiredState -Config $Config -Providers $Providers
    Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'sql-state' -Value $state | Out-Null
    if ($PassThru) { return $state }
    return [string]$state.State
}

function Enable-SetupCmSqlNetwork {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstanceName)

    if (-not $IsWindows) { throw 'SQL Server network configuration can only run on Windows Server.' }
    $instanceId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction Stop).$InstanceName
    if ([string]::IsNullOrWhiteSpace($instanceId)) { throw "SQL Server instance '$InstanceName' is not installed." }
    $tcpPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp"
    Set-ItemProperty -Path $tcpPath -Name Enabled -Value 1
    Set-ItemProperty -Path "$tcpPath\IPAll" -Name TcpDynamicPorts -Value ''
    Set-ItemProperty -Path "$tcpPath\IPAll" -Name TcpPort -Value '1433'
    $serviceName = Get-SetupCmSqlServiceName -InstanceName $InstanceName
    Restart-Service -Name $serviceName -Force
}

function Set-SetupCmSqlServiceState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstanceName)

    if (-not $IsWindows) { throw 'SQL Server service configuration can only run on Windows Server.' }
    $serviceName = Get-SetupCmSqlServiceName -InstanceName $InstanceName
    Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    if ($service.Status -ne 'Running') { Start-Service -Name $serviceName -ErrorAction Stop }
}

function Enable-SetupCmSqlFirewall {
    [CmdletBinding()]
    param()

    if (-not $IsWindows) { throw 'SQL Server firewall configuration can only run on Windows Server.' }
    $displayName = 'Setup-CM SQL Server TCP 1433'
    $rules = @(Get-NetFirewallRule -DisplayName $displayName -ErrorAction SilentlyContinue)
    if ($rules.Count -gt 1) {
        throw "Multiple setup-cm SQL firewall rules named '$displayName' exist."
    }
    if ($rules.Count -eq 0) {
        New-NetFirewallRule -DisplayName $displayName -Direction Inbound -Action Allow -Enabled True -Protocol TCP -LocalPort 1433 | Out-Null
        return
    }

    $rule = $rules[0]
    Set-NetFirewallRule -InputObject $rule -Direction Inbound -Action Allow -Enabled True | Out-Null
    $filters = @($rule | Get-NetFirewallPortFilter -ErrorAction Stop)
    if ($filters.Count -ne 1) {
        throw "The setup-cm SQL firewall rule '$displayName' has an unsupported port-filter shape."
    }
    $filters[0] | Set-NetFirewallPortFilter -Protocol TCP -LocalPort 1433 | Out-Null
}

function Install-SetupCmWindowsPrerequisites {
    [CmdletBinding()]
    param([string[]]$FeatureName = @('NET-Framework-Features', 'BITS', 'Web-Server'))
    if (-not $IsWindows) { throw 'Windows prerequisites can only be installed on Windows Server.' }
    foreach ($feature in $FeatureName) { Install-WindowsFeature -Name $feature -IncludeManagementTools | Out-Null }
}

function Install-SetupCmSql {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$MediaPath, [Parameter(Mandatory)][hashtable]$Sql)
    if (-not $IsWindows) { throw 'SQL Server installation can only run on Windows Server.' }
    $setup = Join-Path (Get-SetupCmMediaRoot -Path $MediaPath) 'setup.exe'
    if (-not (Test-Path -LiteralPath $setup)) { throw "SQL Server setup.exe was not found at $setup" }
    $serviceAccount = 'NT AUTHORITY\NETWORK SERVICE'
    if ($Sql.ContainsKey('serviceAccount') -and -not [string]::IsNullOrWhiteSpace($Sql.serviceAccount)) {
        $serviceAccount = $Sql.serviceAccount
    }
    $sysAdminAccounts = @($Sql.sysAdminAccounts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($sysAdminAccounts.Count -eq 0) {
        throw 'sql.sysAdminAccounts must include at least one Windows identity.'
    }
    $quotedSysAdmins = $sysAdminAccounts | ForEach-Object { '"{0}"' -f $_ }
    $arguments = @(
        '/Q',
        '/ACTION=Install',
        '/FEATURES=SQLENGINE',
        "/INSTANCENAME=$($Sql.instanceName)",
        ('/SQLSVCACCOUNT="{0}"' -f $serviceAccount),
        '/TCPENABLED=1',
        ('/SQLSYSADMINACCOUNTS=' + ($quotedSysAdmins -join ' ')),
        '/IACCEPTSQLSERVERLICENSETERMS'
    )
    if ($Sql.ContainsKey('installDirectory') -and -not [string]::IsNullOrWhiteSpace([string]$Sql.installDirectory)) {
        $arguments += ('/INSTANCEDIR="{0}"' -f ([string]$Sql.installDirectory).TrimEnd('\', '/'))
    }
    $process = Start-Process -FilePath $setup -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) { throw "SQL Server setup failed with exit code $($process.ExitCode)." }
}

function Add-SetupCmSqlSysAdmin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$Account
    )

    if (-not $IsWindows) { throw 'SQL Server sysadmin configuration can only run on Windows Server.' }
    if ([string]::IsNullOrWhiteSpace($Account)) { throw 'A non-empty Windows account is required.' }

    $connection = New-SetupCmSqlConnection -Config $Config -Database 'master'
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = @'
DECLARE @LoginName nvarchar(256) = ?;
DECLARE @statement nvarchar(max);
IF SUSER_ID(@LoginName) IS NULL
BEGIN
    SET @statement = N'CREATE LOGIN ' + QUOTENAME(@LoginName) + N' FROM WINDOWS';
    EXEC sys.sp_executesql @statement;
END;
IF NOT EXISTS (
    SELECT 1
    FROM sys.server_role_members AS role_membership
    JOIN sys.server_principals AS role_principal
        ON role_principal.principal_id = role_membership.role_principal_id
    JOIN sys.server_principals AS member_principal
        ON member_principal.principal_id = role_membership.member_principal_id
    WHERE role_principal.name = N'sysadmin'
      AND member_principal.name = @LoginName
)
BEGIN
    SET @statement = N'ALTER SERVER ROLE [sysadmin] ADD MEMBER ' + QUOTENAME(@LoginName);
    EXEC sys.sp_executesql @statement;
END;
'@
        Add-SetupCmSqlNVarCharParameter -Command $command -Name LoginName -Size 256 -Value $Account | Out-Null
        [void]$command.ExecuteNonQuery()
    }
    finally {
        $connection.Dispose()
    }
}

function Repair-SetupCmSqlDesiredState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    $aggregateState = if ($State -is [string]) { [string]$State } else { [string]$State.State }
    if ($aggregateState -eq 'Conflict') {
        throw 'SQL desired state contains a conflict and cannot be repaired automatically.'
    }
    if ($aggregateState -eq 'Compliant') { return }
    if ($State -is [string]) {
        throw 'A structured SQL desired state is required for minimal repair.'
    }

    $repairable = @($State.Components | Where-Object State -eq 'NotCompliant')
    if (@($repairable | Where-Object Name -eq 'SqlSysAdmins').Count -gt 0) {
        [void](Get-SetupCmSqlConnectionServer -Config $Config)
    }
    $instanceInstalled = $false
    $sourceByComponent = @{
        VcRuntimeX64 = 'vcRedistX64'
        VcRuntimeX86 = 'vcRedistX86'
        OdbcDriver18 = 'odbcDriver18'
        SqlInstance = 'sqlServer'
    }
    foreach ($component in $repairable) {
        $componentName = [string]$component.Name
        if (-not $sourceByComponent.ContainsKey($componentName)) { continue }
        $sourceName = $sourceByComponent[$componentName]
        if (-not $Config.ContainsKey('sources') -or -not $Config.sources.ContainsKey($sourceName)) {
            throw "sources.$sourceName is required to repair $componentName."
        }
    }

    $windowsFeatures = @($repairable | Where-Object Name -eq 'WindowsFeatures')
    if ($windowsFeatures.Count -gt 0) {
        $missingFeatures = @($windowsFeatures[0].Missing)
        if ($missingFeatures.Count -eq 0) { throw 'WindowsFeatures repair state did not identify missing features.' }
        Install-SetupCmWindowsPrerequisites -FeatureName $missingFeatures
    }

    foreach ($componentName in 'VcRuntimeX64', 'VcRuntimeX86') {
        if (@($repairable | Where-Object Name -eq $componentName).Count -eq 0) { continue }
        $sourceName = $sourceByComponent[$componentName]
        Install-SetupCmMecmVcRedist -Source $Config.sources[$sourceName] -CacheRoot $Config.cacheRoot -EvidenceRoot $EvidenceRoot
    }

    $odbcInstalled = @($repairable | Where-Object Name -eq 'OdbcDriver18').Count -gt 0
    if ($odbcInstalled) {
        Install-SetupCmOdbcDriver18 -Source $Config.sources.odbcDriver18 -CacheRoot $Config.cacheRoot -EvidenceRoot $EvidenceRoot
    }

    if (@($repairable | Where-Object Name -eq 'SqlInstance').Count -gt 0) {
        $media = Get-SetupCmArtifact -Source $Config.sources.sqlServer -CacheRoot $Config.cacheRoot -EvidenceRoot $EvidenceRoot
        Install-SetupCmSql -MediaPath $media.Path -Sql $Config.sql
        $instanceInstalled = $true
    }

    if ($instanceInstalled -or @($repairable | Where-Object Name -eq 'SqlService').Count -gt 0) {
        Set-SetupCmSqlServiceState -InstanceName $Config.sql.instanceName
    }
    if ($instanceInstalled -or @($repairable | Where-Object Name -eq 'SqlNetwork').Count -gt 0) {
        Enable-SetupCmSqlNetwork -InstanceName $Config.sql.instanceName
    }
    if ($instanceInstalled -or @($repairable | Where-Object Name -eq 'SqlFirewall').Count -gt 0) {
        Enable-SetupCmSqlFirewall
    }

    $repairedSysAdmins = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($sysAdminState in @($repairable | Where-Object Name -eq 'SqlSysAdmins')) {
        foreach ($account in @($sysAdminState.Missing)) {
            Add-SetupCmSqlSysAdmin -Config $Config -Account $account
            [void]$repairedSysAdmins.Add((ConvertTo-SetupCmSqlComparableAccount -Account ([string]$account)))
        }
    }

    if ($odbcInstalled) {
        $postBootstrapState = Get-SetupCmSqlDesiredState -Config $Config
        if ([string]$postBootstrapState.State -eq 'Conflict') {
            throw 'SQL desired state contains a conflict after ODBC bootstrap.'
        }
        foreach ($sysAdminState in @($postBootstrapState.Components | Where-Object {
            $_.Name -eq 'SqlSysAdmins' -and $_.State -eq 'NotCompliant'
        })) {
            foreach ($account in @($sysAdminState.Missing)) {
                $normalizedAccount = ConvertTo-SetupCmSqlComparableAccount -Account ([string]$account)
                if ($repairedSysAdmins.Contains($normalizedAccount)) { continue }
                Add-SetupCmSqlSysAdmin -Config $Config -Account $account
                [void]$repairedSysAdmins.Add($normalizedAccount)
            }
        }
    }
}

function Verify-SetupCmSql {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstanceName)
    Test-SetupCmSql -InstanceName $InstanceName
}
