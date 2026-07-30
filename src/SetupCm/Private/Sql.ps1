function Test-SetupCmSql {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstanceName,
        [scriptblock]$ServiceStateProvider = { Get-Service -Name "MSSQL`$$InstanceName" -ErrorAction SilentlyContinue }
    )

    $service = & $ServiceStateProvider
    if ($null -ne $service -and $service.Status -eq 'Running') { return 'Compliant' }
    return 'NotCompliant'
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
    $arguments = @('/Q', '/ACTION=Install', '/FEATURES=SQLENGINE', "/INSTANCENAME=$($Sql.instanceName)", "/SQLSVCACCOUNT=$($Sql.serviceAccount)", '/IACCEPTSQLSERVERLICENSETERMS')
    $process = Start-Process -FilePath $setup -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) { throw "SQL Server setup failed with exit code $($process.ExitCode)." }
}

function Verify-SetupCmSql {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$InstanceName)
    Test-SetupCmSql -InstanceName $InstanceName
}
