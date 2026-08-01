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
    $serviceName = if ($InstanceName -ieq 'MSSQLSERVER') { 'MSSQLSERVER' } else { "MSSQL`$$InstanceName" }
    Restart-Service -Name $serviceName -Force
    if (-not (Get-NetFirewallRule -DisplayName 'Setup-CM SQL Server TCP 1433' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName 'Setup-CM SQL Server TCP 1433' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433 | Out-Null
    }
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
    $process = Start-Process -FilePath $setup -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) { throw "SQL Server setup failed with exit code $($process.ExitCode)." }
}

function Verify-SetupCmSql {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstanceName)
    Test-SetupCmSql -InstanceName $InstanceName
}
