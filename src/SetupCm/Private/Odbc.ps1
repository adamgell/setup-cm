function Test-SetupCmOdbcDriver18 {
    [CmdletBinding()]
    param(
        [scriptblock]$RegistryProvider = {
            Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\MSODBCSQL18' -ErrorAction SilentlyContinue
        }
    )

    if ($null -ne (& $RegistryProvider)) { return 'Compliant' }
    return 'NotCompliant'
}

function Install-SetupCmOdbcDriver18 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Source,
        [Parameter(Mandatory)][string]$CacheRoot,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )

    if (-not $IsWindows) { throw 'Microsoft ODBC Driver installation can only run on Windows Server.' }
    $artifact = Get-SetupCmArtifact -Source $Source -CacheRoot $CacheRoot -EvidenceRoot $EvidenceRoot
    $installerPathArgument = '"{0}"' -f $artifact.Path
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @(
        '/i', $installerPathArgument, '/qn', 'REBOOT=ReallySuppress',
        'IACCEPTMSODBCSQLLICENSETERMS=YES'
    ) -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -notin 0, 3010) {
        throw "Microsoft ODBC Driver installation failed with exit code $($process.ExitCode)."
    }
}
