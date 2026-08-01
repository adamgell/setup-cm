Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Get-SetupCmArtifact' {
    InModuleScope SetupCm {
        It 'uses a matching cached artifact without downloading' {
            $cacheFile = Join-Path $TestDrive 'sql.iso'
            Set-Content -LiteralPath $cacheFile -Value 'cached installer' -NoNewline
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $cacheFile).Hash

            $result = Get-SetupCmArtifact -Source @{
                name = 'sqlServer'; cacheFile = 'sql.iso'; sha256 = $hash; licenseAccepted = $true
            } -CacheRoot $TestDrive -EvidenceRoot $TestDrive

            $result.Path | Should -Be $cacheFile
            $result.Sha256 | Should -Be $hash.ToLowerInvariant()
        }

        It 'rejects a cached artifact with a mismatched hash' {
            Set-Content -LiteralPath (Join-Path $TestDrive 'mecm.iso') -Value 'wrong installer' -NoNewline

            {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64); licenseAccepted = $true
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*SHA-256 mismatch*'
        }

        It 'rejects acquisition until the required license is accepted' {
            {
                Get-SetupCmArtifact -Source @{
                    name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = ('0' * 64); licenseAccepted = $false
                } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
            } | Should -Throw '*licenseAccepted*'
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
                }
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Name = $Source.name; Path = 'cached'; Sha256 = 'hash' }
            }

            $result = @(Invoke-SetupCmAcquire -ConfigPath 'lab.yaml')

            $result | Should -HaveCount 2
            Should -Invoke Get-SetupCmArtifact -Times 2 -Exactly
        }
    }
}

Describe 'Invoke-SetupCm' {
    InModuleScope SetupCm {
        It 'keeps acquisition evidence in the outer deployment run' {
            $cacheRoot = Join-Path $TestDrive 'cache'
            $outerEvidenceRoot = Join-Path $TestDrive 'evidence-outer'
            $innerEvidenceRoot = Join-Path $TestDrive 'evidence-inner'
            New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $cacheRoot 'sql.iso') -Value 'sql installer' -NoNewline
            Set-Content -LiteralPath (Join-Path $cacheRoot 'mecm.iso') -Value 'mecm installer' -NoNewline

            $config = @{
                cacheRoot = $cacheRoot
                evidenceRoot = $TestDrive
                sources = @{
                    sqlServer = @{ name = 'sqlServer'; cacheFile = 'sql.iso'; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $cacheRoot 'sql.iso')).Hash; licenseAccepted = $true }
                    mecm = @{ name = 'mecm'; cacheFile = 'mecm.iso'; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $cacheRoot 'mecm.iso')).Hash; licenseAccepted = $true }
                }
            }
            $runRoots = [System.Collections.Generic.Queue[string]]::new()
            $runRoots.Enqueue($outerEvidenceRoot)
            $runRoots.Enqueue($innerEvidenceRoot)
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence {
                $path = $runRoots.Dequeue()
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                $path
            }

            Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Acquire | Out-Null

            Test-Path -LiteralPath (Join-Path $outerEvidenceRoot 'acquisition.json') | Should -BeTrue
            Test-Path -LiteralPath $innerEvidenceRoot | Should -BeFalse
        }
    }
}
