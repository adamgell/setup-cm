Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Read-SetupCmClientManifest' {
    InModuleScope SetupCm {
        BeforeAll {
            $manifestPath = Join-Path $TestDrive 'client-manifest.json'
            $outsideDomainManifest = Join-Path $TestDrive 'outside-domain-manifest.json'
            @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' } |
                ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
            @{ siteCode = 'LAB'; managementPointFqdn = 'CM01.example.invalid'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' } |
                ConvertTo-Json | Set-Content -LiteralPath $outsideDomainManifest -Encoding utf8
        }

        It 'accepts LABZ1 client settings' {
            $manifest = Read-SetupCmClientManifest -Path $manifestPath

            $manifest.siteCode | Should -Be 'LAB'
            $manifest.managementPointFqdn | Should -Be 'LABZ1-CM01.test.gell.one'
        }

        It 'rejects a non-LABZ1 management point' {
            { Read-SetupCmClientManifest -Path $outsideDomainManifest } |
                Should -Throw '*test.gell.one*'
        }
    }
}

Describe 'Test-SetupCmClientInstallation' {
    InModuleScope SetupCm {
        It 'reports compliant when the client service, site, and location-services management point match case-insensitively' {
            $matchingManifest = @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' }
            Test-SetupCmClientInstallation -Manifest $matchingManifest -ServiceStateProvider {
                param($Name)
                @{ Status = 'Running' }
            } -RegistryProvider {
                param($Path)
                if ($Path -eq 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client') {
                    return @{ AssignedSiteCode = 'LAB' }
                }
                @{ EventLastUsedMP = 'labz1-cm01.test.gell.one' }
            } | Should -Be 'Compliant'
        }

        It 'reports not compliant when the last valid management point differs' {
            $wrongMpManifest = @{ siteCode = 'LAB'; managementPointFqdn = 'OTHER-CM01.test.gell.one'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' }
            Test-SetupCmClientInstallation -Manifest $wrongMpManifest -ServiceStateProvider {
                param($Name)
                @{ Status = 'Running' }
            } -RegistryProvider {
                param($Path)
                if ($Path -eq 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client') {
                    return @{ AssignedSiteCode = 'LAB' }
                }
                @{ EventLastUsedMP = 'LABZ1-CM01.test.gell.one' }
            } | Should -Be 'NotCompliant'
        }

        It 'waits for client location readiness before declaring the install failed' {
            $manifest = @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' }
            $script:attempt = 0

            Wait-SetupCmClientInstallation -Manifest $manifest -RetryCount 2 -RetryDelaySeconds 0 -InstallationTestProvider {
                param($clientManifest)
                $script:attempt++
                if ($script:attempt -eq 3) { return 'Compliant' }
                'NotCompliant'
            } | Should -Be 'Compliant'

            $script:attempt | Should -Be 3
        }
    }
}

Describe 'Install-SetupCmClient' {
    InModuleScope SetupCm {
        It 'launches the only permitted client installer with the exact site arguments' {
            $manifest = @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' }
            $script:installerPath = $null
            $script:installerArguments = $null

            Install-SetupCmClient -Manifest $manifest -FileProvider { param($Path) $true } -ProcessProvider {
                param($Path, $ArgumentList)
                $script:installerPath = $Path
                $script:installerArguments = $ArgumentList
                @{ ExitCode = 0 }
            } | Out-Null

            $script:installerPath | Should -Be '\\LABZ1-CM01.test.gell.one\SMS_LAB\Client\ccmsetup.exe'
            $script:installerArguments | Should -Be @('/mp:LABZ1-CM01.test.gell.one', 'SMSSITECODE=LAB')
        }

        It 'rejects a failed installer result without disclosing password values' {
            $manifest = @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' }

            {
                Install-SetupCmClient -Manifest $manifest -FileProvider { param($Path) $true } -ProcessProvider {
                    param($Path, $ArgumentList)
                    @{ ExitCode = 1603; Output = 'Password=NotForEvidence; client install failed' }
                }
            } | Should -Throw '*Password=<redacted>*'
        }
    }
}

Describe 'Get-SetupCmClientEvidence' {
    InModuleScope SetupCm {
        It 'records an empty log tail without failing evidence collection' {
            $manifest = @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' }

            $evidence = Get-SetupCmClientEvidence -Manifest $manifest -ContentProvider {
                param($Path)
                ''
            }

            $evidence.logs | ForEach-Object { $_.tail | Should -Be '' }
        }

        It 'redacts credential-like values from client log tails' {
            $manifest = @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = 'C:\ProgramData\SetupCm\artifacts' }

            $evidence = Get-SetupCmClientEvidence -Manifest $manifest -ContentProvider {
                param($Path)
                'Connected with Password=NotForEvidence; to LABZ1-CM01.test.gell.one'
            }

            ($evidence.logs | ConvertTo-Json -Depth 5) | Should -Match 'Password=<redacted>'
            ($evidence.logs | ConvertTo-Json -Depth 5) | Should -Not -Match 'NotForEvidence'
        }
    }
}

Describe 'Invoke-SetupCmClient' {
    InModuleScope SetupCm {
        It 'does not launch the installer when the target is already compliant' {
            $manifestPath = Join-Path $TestDrive 'compliant-manifest.json'
            @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = $TestDrive } |
                ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Test-SetupCmClientInstallation { 'Compliant' }
            Mock Install-SetupCmClient {}
            Mock Get-SetupCmClientEvidence {
                [pscustomobject]@{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; logs = @() }
            }

            Invoke-SetupCmClient -ManifestPath $manifestPath | Out-Null

            Should -Invoke Install-SetupCmClient -Times 0 -Exactly
        }

        It 'writes client-install evidence even when the target is already compliant' {
            $manifestPath = Join-Path $TestDrive 'compliant-manifest.json'
            @{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; evidenceRoot = $TestDrive } |
                ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Test-SetupCmClientInstallation { 'Compliant' }
            Mock Install-SetupCmClient {}
            Mock Get-SetupCmClientEvidence {
                [pscustomobject]@{ siteCode = 'LAB'; managementPointFqdn = 'LABZ1-CM01.test.gell.one'; logs = @() }
            }
            Mock Write-SetupCmEvidenceJson {}

            Invoke-SetupCmClient -ManifestPath $manifestPath | Out-Null

            Should -Invoke Write-SetupCmEvidenceJson -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'client-install'
            }
        }
    }
}
