Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Get-SetupCmWebRequestTimeoutParameters' {
    InModuleScope SetupCm {
        It 'uses separate bounded connection and stream-read timeouts on PowerShell 7.4 and later' {
            $parameters = Get-SetupCmWebRequestTimeoutParameters -PowerShellVersion ([version]'7.4')

            $parameters.ConnectionTimeoutSeconds | Should -Be 30
            $parameters.OperationTimeoutSeconds | Should -Be 300
            $parameters.ContainsKey('TimeoutSec') | Should -BeFalse
        }

        It 'uses a bounded legacy request timeout before PowerShell 7.4' {
            $parameters = Get-SetupCmWebRequestTimeoutParameters -PowerShellVersion ([version]'7.3')

            $parameters.TimeoutSec | Should -Be 7200
            $parameters.ContainsKey('ConnectionTimeoutSeconds') | Should -BeFalse
            $parameters.ContainsKey('OperationTimeoutSeconds') | Should -BeFalse
        }
    }
}

Describe 'Get-SetupCmArtifact' {
    InModuleScope SetupCm {
        It 'uses a matching cached artifact without downloading' {
            $cacheFile = Join-Path $TestDrive 'sql.iso'
            Set-Content -LiteralPath $cacheFile -Value 'cached installer' -NoNewline
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $cacheFile).Hash
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{
                    Name = 'sqlServer'; State = 'Compliant'; Reason = 'Verified'
                    CacheFile = 'sql.iso'; SizeBytes = 16; Sha256 = $hash.ToLowerInvariant()
                    Version = '16.0.1000.6'; Architecture = 'x64'
                }
            }

            $result = Get-SetupCmArtifact -Source @{
                name = 'sqlServer'; cacheFile = 'sql.iso'; sha256 = $hash; licenseAccepted = $true
                sizeBytes = 16; version = '16.0.1000.6'; architecture = 'x64'
            } -CacheRoot $TestDrive -EvidenceRoot $TestDrive

            $result.Path | Should -Be $cacheFile
            $result.Sha256 | Should -Be $hash.ToLowerInvariant()
        }

        It 'acquires a cache miss from a keyed documented source without a nested name' {
            $sourceFile = Join-Path $TestDrive 'approved-sql.iso'
            Set-Content -LiteralPath $sourceFile -Value 'approved media' -NoNewline
            $config = Read-SetupCmConfig -Path "$PSScriptRoot/../../config/lab.example.yaml"
            $source = $config.sources.sqlServer
            $source.vaultPath = $sourceFile
            $source.licenseAccepted = $true
            Mock Get-SetupCmArtifactState {
                if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
                    return [pscustomobject]@{
                        Name = $Source.name; State = 'NotCompliant'; Reason = 'Missing'
                    }
                }
                [pscustomobject]@{
                    Name = $Source.name; State = 'Compliant'; Reason = 'Verified'
                    Sha256 = ('a' * 64); SizeBytes = 14
                    Version = '16.0.1000.6'; Architecture = 'x64'
                }
            }

            $result = Get-SetupCmArtifact -Source $source -CacheRoot $TestDrive `
                -EvidenceRoot $TestDrive

            $result.Name | Should -Be 'sqlServer'
            $result.State | Should -Be 'Compliant'
            Test-Path -LiteralPath (Join-Path $TestDrive 'sql-server.iso') |
                Should -BeTrue
        }

        It 'fails safely when an invalid cached artifact has no approved source' {
            Set-Content -LiteralPath (Join-Path $TestDrive 'mecm.iso') -Value 'wrong installer' -NoNewline
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{ Name = 'mecm'; State = 'NotCompliant'; Reason = 'Sha256Mismatch' }
            }

            {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64); licenseAccepted = $true
                    sizeBytes = 15; version = '5.00.9141.1002'; architecture = 'x64'
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*no approved source*'
        }

        It 'rejects acquisition until the required license is accepted' {
            {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64); licenseAccepted = $false
                    sizeBytes = 15; version = '5.00.9141.1002'; architecture = 'x64'
                    publisher = 'Microsoft Corporation'
                    signatureRelativePath = 'SMSSETUP\BIN\X64\setup.exe'
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*licenseAccepted*'
        }

        It 'reports a missing cacheFile through bounded source validation' {
            {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; sha256 = ('0' * 64); licenseAccepted = $true
                    sizeBytes = 15; version = '5.00.9141.1002'; architecture = 'x64'
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*MissingSourceField:cacheFile*'
        }

        It 'reports a missing name through bounded source validation' {
            {
                Get-SetupCmArtifact -Source @{
                    cacheFile = 'mecm.iso'; sha256 = ('0' * 64); licenseAccepted = $true
                    sizeBytes = 15; version = '5.00.9141.1002'; architecture = 'x64'
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*MissingSourceField:name*'
        }

        It 'preserves the existing cache when a replacement fails verification' {
            $cacheFile = Join-Path $TestDrive 'mecm.iso'
            $sourceFile = Join-Path $TestDrive 'source-mecm.iso'
            Set-Content -LiteralPath $cacheFile -Value 'existing cache' -NoNewline
            Set-Content -LiteralPath $sourceFile -Value 'bad replacement' -NoNewline
            Mock Get-SetupCmArtifactState {
                if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
                    return [pscustomobject]@{ Name = 'mecm'; State = 'NotCompliant'; Reason = 'Sha256Mismatch' }
                }
                [pscustomobject]@{ Name = 'mecm'; State = 'NotCompliant'; Reason = 'VersionMismatch' }
            }

            {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64)
                    sizeBytes = 15; version = '5.00.9141.1002'; architecture = 'x64'
                    licenseAccepted = $true; vaultPath = $sourceFile
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*failed verification*VersionMismatch*'

            (Get-Content -LiteralPath $cacheFile -Raw) | Should -Be 'existing cache'
            Test-Path -LiteralPath (Join-Path $TestDrive 'mecm.download.iso') | Should -BeFalse
        }

        It 'retains safe acquisition diagnostics without disclosing the private source URI' {
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{ Name = 'mecm'; State = 'NotCompliant'; Reason = 'Missing' }
            }
            Mock Invoke-WebRequest {
                throw 'TLS certificate validation failed for https://private.example.invalid/download?token=topsecret'
            }
            $message = $null

            try {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64)
                    sizeBytes = 15; version = '5.00.9141.1002'; architecture = 'x64'
                    licenseAccepted = $true
                    uri = 'https://private.example.invalid/download?token=topsecret'
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            }
            catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Acquisition failed for artifact.*mecm'
            $message | Should -Match 'TLS certificate validation failed'
            $message | Should -Match '<redacted-uri>'
            $message | Should -Not -Match 'private\.example\.invalid|topsecret'
            if ($PSVersionTable.PSVersion -ge [version]'7.4') {
                Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                    $ConnectionTimeoutSeconds -eq 30 -and $OperationTimeoutSeconds -eq 300
                }
            }
            else {
                Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                    $TimeoutSec -eq 7200
                }
            }
            Test-Path -LiteralPath (Join-Path $TestDrive 'mecm.download.iso') |
                Should -BeFalse
        }

        It 'redacts a private vault path from retained acquisition diagnostics' {
            $vaultPath = Join-Path $TestDrive 'private-vault/mecm.iso'
            New-Item -ItemType Directory -Path (Split-Path $vaultPath -Parent) -Force | Out-Null
            Set-Content -LiteralPath $vaultPath -Value 'private media' -NoNewline
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{ Name = 'mecm'; State = 'NotCompliant'; Reason = 'Missing' }
            }
            Mock Copy-Item { throw "Access denied to $vaultPath" }
            $message = $null

            try {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64)
                    sizeBytes = 15; version = '5.00.9141.1002'; architecture = 'x64'
                    licenseAccepted = $true; vaultPath = $vaultPath
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            }
            catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'Access denied'
            $message | Should -Match '<redacted-source>'
            $message | Should -Not -Match ([regex]::Escape($vaultPath))
        }

        It 'preserves an MSI extension while verifying newly acquired bytes' {
            $sourceFile = Join-Path $TestDrive 'source-driver.msi'
            Set-Content -LiteralPath $sourceFile -Value 'msi bytes' -NoNewline
            $script:downloadProbePath = ''
            Mock Get-SetupCmArtifactState {
                if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
                    return [pscustomobject]@{
                        Name = 'odbcDriver18'; State = 'NotCompliant'; Reason = 'Missing'
                    }
                }
                $script:downloadProbePath = $ArtifactPath
                [pscustomobject]@{
                    Name = 'odbcDriver18'; State = 'Compliant'; Reason = 'Verified'
                    Sha256 = ('a' * 64); SizeBytes = 9; Version = '18.4.1.1'; Architecture = 'x64'
                }
            }

            Get-SetupCmArtifact -Source @{
                name = 'odbcDriver18'; cacheFile = 'driver.msi'; sha256 = ('a' * 64)
                sizeBytes = 9; version = '18.4.1.1'; architecture = 'x64'
                licenseAccepted = $true; vaultPath = $sourceFile
            } -CacheRoot $TestDrive -EvidenceRoot $TestDrive | Out-Null

            $script:downloadProbePath | Should -Match '\.download\.msi$'
        }
    }
}

Describe 'Get-SetupCmArtifactState' {
    InModuleScope SetupCm {
        BeforeAll {
            $source = @{
                name = 'sqlServer'; cacheFile = 'sql.iso'; sha256 = ('a' * 64)
                sizeBytes = 1024; version = '16.0.1000.6'; architecture = 'x64'
                licenseAccepted = $true; publisher = 'Microsoft Corporation'
                signatureRelativePath = 'setup.exe'
            }
        }

        It 'reports Compliant only when bytes and native identity match' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { param($Path) $true } `
                -LengthProvider { param($Path) 1024 } `
                -HashProvider { param($Path) ('a' * 64) } `
                -IdentityProvider {
                    param($Path, $Source)
                    @{ Version = '16.0.1000.6'; Architecture = 'x64'; PublisherValid = $true }
                }

            $state.State | Should -Be 'Compliant'
            $state.Reason | Should -Be 'Verified'
        }

        It 'fails closed before probing bytes when publisher metadata is missing' {
            $withoutPublisher = $source.Clone()
            $null = $withoutPublisher.Remove('publisher')
            $script:pathProbed = $false
            $script:identityProbed = $false

            $state = Get-SetupCmArtifactState -Source $withoutPublisher -CacheRoot $TestDrive `
                -PathProvider { $script:pathProbed = $true } `
                -IdentityProvider { $script:identityProbed = $true }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'MissingSourceField:publisher'
            $script:pathProbed | Should -BeFalse
            $script:identityProbed | Should -BeFalse
        }

        It 'fails closed before probing bytes when ISO signature metadata is missing' {
            $withoutSignaturePath = $source.Clone()
            $null = $withoutSignaturePath.Remove('signatureRelativePath')
            $script:pathProbed = $false

            $state = Get-SetupCmArtifactState -Source $withoutSignaturePath -CacheRoot $TestDrive `
                -PathProvider { $script:pathProbed = $true }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'MissingSourceField:signatureRelativePath'
            $script:pathProbed | Should -BeFalse
        }

        It 'reports only the byte-length mismatch without probing native identity' {
            $script:identityProbed = $false

            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { param($Path) $true } `
                -LengthProvider { param($Path) 512 } `
                -HashProvider { param($Path) ('a' * 64) } `
                -IdentityProvider { $script:identityProbed = $true }

            $state.State | Should -Be 'NotCompliant'
            $state.Reason | Should -Be 'SizeMismatch'
            $script:identityProbed | Should -BeFalse
        }

        It 'fails closed when artifact existence cannot be probed' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { throw 'path unavailable' }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'PathProbeUnavailable'
        }

        It 'fails closed on an unavailable length probe without running later probes' {
            $script:hashProbed = $false
            $script:identityProbed = $false

            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } `
                -LengthProvider { throw 'length unavailable' } `
                -HashProvider { $script:hashProbed = $true } `
                -IdentityProvider { $script:identityProbed = $true }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'LengthProbeUnavailable'
            $script:hashProbed | Should -BeFalse
            $script:identityProbed | Should -BeFalse
        }

        It 'fails closed on an unavailable hash probe without running native identity' {
            $script:identityProbed = $false

            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } `
                -LengthProvider { 1024 } `
                -HashProvider { throw 'hash unavailable' } `
                -IdentityProvider { $script:identityProbed = $true }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'HashProbeUnavailable'
            $script:identityProbed | Should -BeFalse
        }

        It 'fails closed on a version mismatch after the approved hash matches' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { @{ Version = '15.0.1.0'; Architecture = 'x64'; PublisherValid = $true } }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'VersionMismatch'
        }

        It 'treats omitted trailing version components as equivalent zeros' {
            $versionSource = $source.Clone()
            $versionSource.version = '17.0.0.0'

            $state = Get-SetupCmArtifactState -Source $versionSource -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { @{ Version = '17.0'; Architecture = 'x64'; PublisherValid = $true } }

            $state.State | Should -Be 'Compliant'
            $state.Reason | Should -Be 'Verified'
        }

        It 'treats a bare major version as equivalent to four-component trailing zeros' {
            $versionSource = $source.Clone()
            $versionSource.version = '17.0.0.0'

            $state = Get-SetupCmArtifactState -Source $versionSource -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { @{ Version = '17'; Architecture = 'x64'; PublisherValid = $true } }

            $state.State | Should -Be 'Compliant'
            $state.Reason | Should -Be 'Verified'
        }

        It 'fails closed on an architecture mismatch after the approved hash matches' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { @{ Version = '16.0.1000.6'; Architecture = 'x86'; PublisherValid = $true } }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'ArchitectureMismatch'
        }

        It 'fails closed on a publisher mismatch after the approved hash matches' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { @{ Version = '16.0.1000.6'; Architecture = 'x64'; PublisherValid = $false } }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'PublisherMismatch'
        }

        It 'fails closed when native identity cannot be read' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { throw 'diagnostic unavailable' }

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'IdentityProbeUnavailable'
        }

        It 'reports missing license acknowledgement as Conflict' {
            $unlicensed = $source.Clone()
            $unlicensed.licenseAccepted = $false

            $state = Get-SetupCmArtifactState -Source $unlicensed -CacheRoot $TestDrive

            $state.State | Should -Be 'Conflict'
            $state.Reason | Should -Be 'LicenseNotAccepted'
        }
    }
}

Describe 'Resolve-SetupCmArtifactSignaturePath' {
    InModuleScope SetupCm {
        It 'resolves a signed setup binary inside ISO media' {
            $setup = Join-Path $TestDrive 'SMSSETUP/BIN/X64/setup.exe'
            New-Item -ItemType Directory -Path (Split-Path -Parent $setup) -Force | Out-Null
            Set-Content -LiteralPath $setup -Value 'signed setup'
            Mock Get-SetupCmMediaRoot { $TestDrive }

            $resolved = Resolve-SetupCmArtifactSignaturePath `
                -Path 'C:\SetupCm\Media\mecm.iso' `
                -SignatureRelativePath 'SMSSETUP\BIN\X64\setup.exe'

            $resolved | Should -Be $setup
            Should -Invoke Get-SetupCmMediaRoot -Times 1 -Exactly
        }
    }
}

Describe 'Get-SetupCmArtifactIdentity architecture proof' {
    InModuleScope SetupCm {
        It 'uses a separately signed payload path for ISO architecture' {
            Mock Resolve-SetupCmArtifactSignaturePath {
                if ($SignatureRelativePath -eq 'setup.exe') { return 'Q:\setup.exe' }
                if ($SignatureRelativePath -eq 'x64\ScenarioEngine.exe') {
                    return 'Q:\x64\ScenarioEngine.exe'
                }
                throw 'unexpected relative path'
            }
            $script:signedPaths = [System.Collections.Generic.List[string]]::new()

            $identity = Get-SetupCmArtifactIdentity -Path 'C:\cache\sql.iso' -Source @{
                publisher = 'Microsoft Corporation'; architecture = 'x64'
                signatureRelativePath = 'setup.exe'
                architectureRelativePath = 'x64\ScenarioEngine.exe'
            } -SignatureProvider {
                param($ArtifactPath, $ExpectedPublisher, $RelativePath)
                $ArtifactPath | Should -BeExactly 'C:\cache\sql.iso'
                $ExpectedPublisher | Should -BeExactly 'Microsoft Corporation'
                [void]$script:signedPaths.Add($RelativePath)
            } -VersionInfoProvider {
                param($IdentityPath)
                $IdentityPath | Should -BeExactly 'Q:\setup.exe'
                [pscustomobject]@{
                    ProductVersion = '16.0.1000.6'; FileVersion = '16.0.1000.6'
                    ProductName = 'Microsoft SQL Server'; FileDescription = 'SQL Setup'
                    OriginalFilename = 'setup.exe'
                }
            } -PeArchitectureProvider {
                param($IdentityPath)
                if ($IdentityPath -eq 'Q:\x64\ScenarioEngine.exe') { 'x64' } else { 'x86' }
            }

            $identity.Version | Should -BeExactly '16.0.1000.6'
            $identity.Architecture | Should -BeExactly 'x64'
            $identity.PublisherValid | Should -BeTrue
            @($script:signedPaths) | Should -BeExactly `
                @('setup.exe', 'x64\ScenarioEngine.exe')
        }

        It 'accepts an explicitly approved signed x64 bootstrapper identity' {
            Mock Resolve-SetupCmArtifactSignaturePath { 'C:\cache\vc_redist.x64.exe' }

            $identity = Get-SetupCmArtifactIdentity -Path 'C:\cache\vc_redist.x64.exe' -Source @{
                publisher = 'Microsoft Corporation'; architecture = 'x64'
                architectureVerification = 'signedVersionResource'
            } -SignatureProvider {} -VersionInfoProvider {
                [pscustomobject]@{
                    ProductVersion = '14.51.36247.0'; FileVersion = '14.51.36247.0'
                    ProductName = 'Microsoft Visual C++ Redistributable (x64)'
                    FileDescription = 'Microsoft Visual C++ Redistributable (x64)'
                    OriginalFilename = 'VC_redist.x64.exe'
                }
            } -PeArchitectureProvider { 'x86' }

            $identity.Version | Should -BeExactly '14.51.36247.0'
            $identity.Architecture | Should -BeExactly 'x64'
            $identity.PublisherValid | Should -BeTrue
        }

        It 'does not relabel an x64 payload as x86 from version-resource text' {
            Mock Resolve-SetupCmArtifactSignaturePath { 'C:\cache\vc_redist.x86.exe' }

            $identity = Get-SetupCmArtifactIdentity -Path 'C:\cache\vc_redist.x86.exe' -Source @{
                publisher = 'Microsoft Corporation'; architecture = 'x86'
                architectureVerification = 'signedVersionResource'
            } -SignatureProvider {} -VersionInfoProvider {
                [pscustomobject]@{
                    ProductVersion = '14.51.36247.0'; FileVersion = '14.51.36247.0'
                    ProductName = 'Microsoft Visual C++ Redistributable (x86)'
                    FileDescription = 'Microsoft Visual C++ Redistributable (x86)'
                    OriginalFilename = 'VC_redist.x86.exe'
                }
            } -PeArchitectureProvider { 'x64' }

            $identity.Architecture | Should -BeExactly 'x64'
        }

        It 'rejects a generic signed x86 bootstrapper as x64 evidence' {
            Test-SetupCmSignedVersionResourceArchitecture -ExpectedArchitecture x64 `
                -ProductName 'Microsoft Setup Bootstrapper' `
                -FileDescription 'Microsoft Setup Bootstrapper' `
                -OriginalFilename 'setup.exe' | Should -BeFalse
        }

        It 'requires both the original filename and product identity to name x64' {
            Test-SetupCmSignedVersionResourceArchitecture -ExpectedArchitecture x64 `
                -ProductName 'Microsoft Visual C++ Redistributable (x86)' `
                -FileDescription 'Microsoft Visual C++ Redistributable (x86)' `
                -OriginalFilename 'VC_redist.x64.exe' | Should -BeFalse
        }
    }
}

Describe 'Invoke-SetupCmAcquire' {
    InModuleScope SetupCm {
        It 'acquires every configured source' {
            $config = @{
                cacheRoot = $TestDrive
                evidenceRoot = $TestDrive
                sources = @{
                    sqlServer = @{ name = 'sqlServer' }
                    mecm = @{ name = 'mecm' }
                    vcRedistX64 = @{ name = 'vcRedistX64' }
                    vcRedistX86 = @{ name = 'vcRedistX86' }
                    prerequisites = @('dotnet48', 'adk')
                }
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{ Name = $Source.name; State = 'NotCompliant'; Reason = 'Missing' }
            }
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Name = $Source.name; Path = 'cached'; Sha256 = 'hash' }
            }

            $result = @(Invoke-SetupCmAcquire -ConfigPath 'lab.yaml')

            $result | Should -HaveCount 4
            $result.Name | Should -Contain 'sqlServer'
            $result.Name | Should -Contain 'mecm'
            $result.Name | Should -Contain 'vcRedistX64'
            $result.Name | Should -Contain 'vcRedistX86'
            Should -Invoke Get-SetupCmArtifact -Times 4 -Exactly
        }

        It 'uses the source key as the name when the source lacks a name field' {
            $config = @{
                cacheRoot = $TestDrive
                evidenceRoot = $TestDrive
                sources = @{
                    sqlServer = @{ cacheFile = 'sql.iso'; sha256 = ('0' * 64); licenseAccepted = $true }
                }
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{ Name = $Source.name; State = 'NotCompliant'; Reason = 'Missing' }
            }
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Name = $Source.name; Path = 'cached'; Sha256 = 'hash' }
            }

            $result = @(Invoke-SetupCmAcquire -ConfigPath 'lab.yaml')

            $result | Should -HaveCount 1
            $result[0].Name | Should -Be 'sqlServer'
        }

        It 'reacquires only the affected artifact' {
            $config = @{
                cacheRoot = Join-Path $TestDrive 'cache'
                evidenceRoot = $TestDrive
                sources = @{
                    sqlServer = @{ name = 'sqlServer'; cacheFile = 'sql.iso' }
                    mecm = @{ name = 'mecm'; cacheFile = 'mecm.iso' }
                    adk = @{ name = 'adk'; cacheFile = 'adk.exe' }
                }
            }
            Mock Read-SetupCmConfig { $config }
            Mock Get-SetupCmArtifactState {
                if ($Source.name -eq 'mecm') {
                    return [pscustomobject]@{ Name = 'mecm'; State = 'NotCompliant'; Reason = 'Sha256Mismatch' }
                }
                [pscustomobject]@{
                    Name = $Source.name; State = 'Compliant'; Reason = 'Verified'
                    Sha256 = ('a' * 64); SizeBytes = 1; Version = '1.0'; Architecture = 'x64'
                }
            }
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Name = $Source.name; Path = 'cached'; Sha256 = 'hash' }
            }

            $result = @(Invoke-SetupCmAcquire -ConfigPath 'lab.yaml' -EvidenceRoot $TestDrive)

            $result | Should -HaveCount 3
            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly -ParameterFilter { $Source.name -eq 'mecm' }
            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
        }

        It 'normalizes reused and acquired artifacts to the same bounded evidence shape' {
            $cacheRoot = Join-Path $TestDrive 'cache'
            $config = @{
                cacheRoot = $cacheRoot
                evidenceRoot = $TestDrive
                sources = @{
                    sqlServer = @{ name = 'sqlServer'; cacheFile = 'sql.iso' }
                    mecm = @{ name = 'mecm'; cacheFile = 'mecm.iso' }
                }
            }
            Mock Read-SetupCmConfig { $config }
            Mock Get-SetupCmArtifactState {
                if ($Source.name -eq 'sqlServer') {
                    return [pscustomobject]@{
                        Name = 'sqlServer'; State = 'Compliant'; Reason = 'Verified'
                        CacheFile = 'sql.iso'; Sha256 = ('a' * 64); SizeBytes = 1024
                        Version = '16.0.1000.6'; Architecture = 'x64'
                    }
                }
                [pscustomobject]@{ Name = 'mecm'; State = 'NotCompliant'; Reason = 'Missing' }
            }
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{
                    Name = 'mecm'; State = 'Compliant'; Reason = 'AcquiredAndVerified'
                    Path = (Join-Path $cacheRoot 'mecm.iso'); Sha256 = ('b' * 64); SizeBytes = 2048
                    Version = '5.00.9141.1002'; Architecture = 'x64'; VerifiedAt = '2026-08-30T00:00:00.0000000Z'
                }
            }

            $result = @(Invoke-SetupCmAcquire -ConfigPath 'lab.yaml' -EvidenceRoot $TestDrive)
            $evidence = @(Get-Content -LiteralPath (Join-Path $TestDrive 'acquisition.json') -Raw |
                ConvertFrom-Json)
            $reused = @($result | Where-Object Name -eq 'sqlServer')[0]
            $reusedEvidence = @($evidence | Where-Object Name -eq 'sqlServer')[0]

            $result | Should -HaveCount 2
            $reused.Path | Should -Be (Join-Path $cacheRoot 'sql.iso')
            $reused.PSObject.Properties.Name | Should -Contain 'Path'
            $reused.PSObject.Properties.Name | Should -Not -Contain 'CacheFile'
            $reusedEvidence.PSObject.Properties.Name | Should -Contain 'Path'
            $reusedEvidence.PSObject.Properties.Name | Should -Not -Contain 'CacheFile'
            @($result | Where-Object { $_.PSObject.Properties.Name -notcontains 'Path' }) |
                Should -HaveCount 0
            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly -ParameterFilter { $Source.name -eq 'mecm' }
            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
        }

        It 'fails closed without acquisition when any artifact state is Conflict' {
            $config = @{
                cacheRoot = 'C:\cache'
                evidenceRoot = $TestDrive
                sources = @{ mecm = @{ name = 'mecm' } }
            }
            Mock Read-SetupCmConfig { $config }
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{ Name = 'mecm'; State = 'Conflict'; Reason = 'LicenseNotAccepted' }
            }
            Mock Get-SetupCmArtifact {}

            { Invoke-SetupCmAcquire -ConfigPath 'lab.yaml' -EvidenceRoot $TestDrive } |
                Should -Throw '*LicenseNotAccepted*'
            Should -Invoke Get-SetupCmArtifact -Times 0 -Exactly
        }

        It 'fails closed when a configured source is not a metadata map' {
            $config = @{
                cacheRoot = 'C:\cache'
                evidenceRoot = $TestDrive
                sources = @{ mecm = 'not-a-source-map' }
            }
            Mock Read-SetupCmConfig { $config }
            Mock Get-SetupCmArtifact {}

            { Invoke-SetupCmAcquire -ConfigPath 'lab.yaml' -EvidenceRoot $TestDrive } |
                Should -Throw '*InvalidSourceType*'
            Should -Invoke Get-SetupCmArtifact -Times 0 -Exactly
        }

        It 'fails closed when no artifact sources are configured' {
            $config = @{
                cacheRoot = 'C:\cache'
                evidenceRoot = $TestDrive
                sources = @{}
            }
            Mock Read-SetupCmConfig { $config }
            Mock Get-SetupCmArtifact {}

            { Invoke-SetupCmAcquire -ConfigPath 'lab.yaml' -EvidenceRoot $TestDrive } |
                Should -Throw '*EmptySourceSet*'
            Should -Invoke Get-SetupCmArtifact -Times 0 -Exactly
        }
    }
}

Describe 'Test-SetupCmAcquire' {
    InModuleScope SetupCm {
        It 'returns Compliant and writes bounded component evidence when every artifact matches' {
            $config = @{
                cacheRoot = 'C:\cache'
                sources = @{
                    sqlServer = @{ name = 'sqlServer' }
                    mecm = @{ name = 'mecm' }
                }
            }
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{
                    Name = $Source.name; State = 'Compliant'; Reason = 'Verified'
                    CacheFile = "$($Source.name).bin"; SizeBytes = 1; Sha256 = ('a' * 64)
                    Version = '1.0'; Architecture = 'x64'
                }
            }

            Test-SetupCmAcquire -Config $config -EvidenceRoot $TestDrive | Should -Be 'Compliant'
            $evidence = Get-Content -LiteralPath (Join-Path $TestDrive 'acquire-state.json') -Raw | ConvertFrom-Json
            $evidence.components | Should -HaveCount 2
            ($evidence | ConvertTo-Json -Depth 5) | Should -Not -Match 'uri|vault'
        }

        It 'returns Conflict evidence for a malformed source entry' {
            $config = @{
                cacheRoot = 'C:\cache'
                sources = @{ mecm = 'not-a-source-map' }
            }

            Test-SetupCmAcquire -Config $config -EvidenceRoot $TestDrive | Should -Be 'Conflict'
            $evidence = Get-Content -LiteralPath (Join-Path $TestDrive 'acquire-state.json') -Raw |
                ConvertFrom-Json
            $evidence.state | Should -Be 'Conflict'
            $evidence.components | Should -HaveCount 1
            $evidence.components[0].Name | Should -Be 'mecm'
            $evidence.components[0].Reason | Should -Be 'InvalidSourceType'
        }

        It 'returns Conflict evidence when the source set is empty' {
            $config = @{ cacheRoot = 'C:\cache'; sources = @{} }

            Test-SetupCmAcquire -Config $config -EvidenceRoot $TestDrive | Should -Be 'Conflict'
            $evidence = Get-Content -LiteralPath (Join-Path $TestDrive 'acquire-state.json') -Raw |
                ConvertFrom-Json
            $evidence.state | Should -Be 'Conflict'
            $evidence.components | Should -HaveCount 1
            $evidence.components[0].Name | Should -Be 'Sources'
            $evidence.components[0].Reason | Should -Be 'EmptySourceSet'
        }
    }
}

Describe 'Invoke-SetupCm' {
    InModuleScope SetupCm {
        It 'keeps acquisition evidence in the outer deployment run' {
            $outerEvidenceRoot = Join-Path $TestDrive 'evidence-outer'
            $config = @{
                cacheRoot = 'C:\cache'
                evidenceRoot = $TestDrive
                sources = @{ sqlServer = @{ name = 'sqlServer' }; mecm = @{ name = 'mecm' } }
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence {
                New-Item -ItemType Directory -Path $outerEvidenceRoot -Force | Out-Null
                $outerEvidenceRoot
            }
            $script:acquireTestCount = 0
            Mock Test-SetupCmAcquire {
                $script:acquireTestCount++
                if ($script:acquireTestCount -eq 1) { 'NotCompliant' } else { 'Compliant' }
            }
            Mock Invoke-SetupCmAcquire {
                Write-SetupCmEvidenceJson -EvidenceRoot $EvidenceRoot -Name 'acquisition' -Value @(
                    @{ name = 'sqlServer' }, @{ name = 'mecm' }
                ) | Out-Null
            }

            Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Acquire | Out-Null

            Test-Path -LiteralPath (Join-Path $outerEvidenceRoot 'acquisition.json') | Should -BeTrue
            Should -Invoke New-SetupCmRunEvidence -Times 1 -Exactly
        }

        It 'does not invoke acquisition when the full cache is already compliant' {
            $config = @{ cacheRoot = 'C:\cache'; evidenceRoot = $TestDrive; sources = @{} }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Test-SetupCmAcquire { 'Compliant' }
            Mock Invoke-SetupCmAcquire {}

            $result = Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Acquire

            $result.state | Should -Be 'Skipped'
            Should -Invoke Invoke-SetupCmAcquire -Times 0 -Exactly
        }
    }
}
