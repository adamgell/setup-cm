Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

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

        It 'fails safely when an invalid cached artifact has no approved source' {
            Set-Content -LiteralPath (Join-Path $TestDrive 'mecm.iso') -Value 'wrong installer' -NoNewline
            Mock Get-SetupCmArtifactState {
                [pscustomobject]@{ Name = 'mecm'; State = 'NotCompliant'; Reason = 'Sha256Mismatch' }
            }

            {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64); licenseAccepted = $true
                    sizeBytes = 15; version = '2503'; architecture = 'x64'
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*no approved source*'
        }

        It 'rejects acquisition until the required license is accepted' {
            {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64); licenseAccepted = $false
                    sizeBytes = 15; version = '2503'; architecture = 'x64'
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*licenseAccepted*'
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
                    sizeBytes = 15; version = '2503'; architecture = 'x64'
                    licenseAccepted = $true; vaultPath = $sourceFile
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*failed verification*VersionMismatch*'

            (Get-Content -LiteralPath $cacheFile -Raw) | Should -Be 'existing cache'
            Test-Path -LiteralPath "$cacheFile.download" | Should -BeFalse
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

        It 'reports a version mismatch as NotCompliant' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { @{ Version = '15.0.1.0'; Architecture = 'x64'; PublisherValid = $true } }

            $state.State | Should -Be 'NotCompliant'
            $state.Reason | Should -Be 'VersionMismatch'
        }

        It 'reports an architecture mismatch as NotCompliant' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { @{ Version = '16.0.1000.6'; Architecture = 'x86'; PublisherValid = $true } }

            $state.State | Should -Be 'NotCompliant'
            $state.Reason | Should -Be 'ArchitectureMismatch'
        }

        It 'reports a publisher mismatch from a hashtable identity provider as NotCompliant' {
            $state = Get-SetupCmArtifactState -Source $source -CacheRoot $TestDrive `
                -PathProvider { $true } -LengthProvider { 1024 } -HashProvider { ('a' * 64) } `
                -IdentityProvider { @{ Version = '16.0.1000.6'; Architecture = 'x64'; PublisherValid = $false } }

            $state.State | Should -Be 'NotCompliant'
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
                    Version = '2503'; Architecture = 'x64'; VerifiedAt = '2026-08-30T00:00:00.0000000Z'
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
