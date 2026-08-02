function Read-SetupCmClientManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Setup-CM client manifest was not found: $Path"
    }

    $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    Assert-SetupCmClientManifest -Manifest $manifest
    $manifest
}

function Assert-SetupCmClientManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Manifest)

    foreach ($name in 'siteCode', 'managementPointFqdn', 'evidenceRoot') {
        if (-not $Manifest.ContainsKey($name)) {
            throw "Setup-CM client manifest is missing $name."
        }
    }
    if ($Manifest.siteCode -notmatch '^[A-Z0-9]{3}$') {
        throw 'siteCode must be exactly three uppercase letters or numbers.'
    }
    if ([string]::IsNullOrWhiteSpace($Manifest.managementPointFqdn) -or
        -not $Manifest.managementPointFqdn.EndsWith('.test.gell.one', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'managementPointFqdn must be within test.gell.one.'
    }
    if ([string]::IsNullOrWhiteSpace($Manifest.evidenceRoot)) {
        throw 'evidenceRoot is required.'
    }
}

function Get-SetupCmClientInstallerPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Manifest)

    Assert-SetupCmClientManifest -Manifest $Manifest
    "\\$($Manifest.managementPointFqdn)\SMS_$($Manifest.siteCode)\Client\ccmsetup.exe"
}

function Test-SetupCmClientInstallation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Manifest,
        [scriptblock]$ServiceStateProvider = { param($Name) Get-Service -Name $Name -ErrorAction SilentlyContinue },
        [scriptblock]$RegistryProvider = { param($Path) Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue }
    )

    Assert-SetupCmClientManifest -Manifest $Manifest
    $service = & $ServiceStateProvider 'CcmExec'
    if ($null -eq $service -or $service.Status -ne 'Running') {
        return 'NotCompliant'
    }

    $clientState = & $RegistryProvider 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client'
    if ($null -eq $clientState -or
        $clientState.AssignedSiteCode -ne $Manifest.siteCode -or
        $clientState.LastValidMP -ne $Manifest.managementPointFqdn) {
        return 'NotCompliant'
    }
    'Compliant'
}

function Install-SetupCmClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Manifest,
        [scriptblock]$FileProvider = { param($Path) Test-Path -LiteralPath $Path -PathType Leaf },
        [scriptblock]$ProcessProvider = {
            param($Path, $ArgumentList)
            Start-Process -FilePath $Path -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow
        }
    )

    $installerPath = Get-SetupCmClientInstallerPath -Manifest $Manifest
    if (-not (& $FileProvider $installerPath)) {
        throw "MECM client installer was not found: $installerPath"
    }
    $arguments = @("/mp:$($Manifest.managementPointFqdn)", "SMSSITECODE=$($Manifest.siteCode)")
    $result = & $ProcessProvider $installerPath $arguments
    if ($null -eq $result -or $result.ExitCode -notin 0, 3010) {
        $output = if ($null -eq $result) { '' } else { [string]$result.Output }
        throw "ccmsetup.exe failed with exit code $($result.ExitCode): $(ConvertTo-SetupCmSanitizedFixtureContent -Content $output)"
    }
    [pscustomobject]@{ installerPath = $installerPath; arguments = $arguments; exitCode = $result.ExitCode }
}

function Get-SetupCmClientEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Manifest,
        [scriptblock]$ContentProvider = { param($Path) Get-Content -LiteralPath $Path -Tail 40 -ErrorAction SilentlyContinue }
    )

    Assert-SetupCmClientManifest -Manifest $Manifest
    $logPaths = @(
        'C:\Windows\CCMSetup\Logs\ccmsetup.log',
        'C:\Windows\CCM\Logs\ClientIDManagerStartup.log'
    )
    $logs = foreach ($path in $logPaths) {
        $content = (& $ContentProvider $path | Out-String).Trim()
        [pscustomobject]@{
            name = Split-Path -Path $path -Leaf
            tail = ConvertTo-SetupCmSanitizedFixtureContent -Content $content
        }
    }
    [pscustomobject]@{
        siteCode = $Manifest.siteCode
        managementPointFqdn = $Manifest.managementPointFqdn
        logs = $logs
    }
}
