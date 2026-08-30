Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Test-SetupCmLabHealth' {
    InModuleScope SetupCm {
        It 'returns NotCompliant when the Management Point check fails' {
            Test-SetupCmLabHealth -Config @{ sql = @{ instanceName = 'MSSQLSERVER' }; testClient = @{ name = 'CL01' } } -EvidenceRoot $TestDrive -Checks @{
                Sql = { $true }; ManagementPoint = { $false }; DistributionPoint = { $true }; Client = { $true }
            } |
                Should -Be 'NotCompliant'
        }

        It 'writes fresh health evidence on every read-only evaluation' {
            Mock Write-SetupCmEvidenceJson {}
            $config = @{ sql = @{ instanceName = 'MSSQLSERVER' }; testClient = @{ name = 'CL01' } }
            $checks = @{ Sql = { $true }; ManagementPoint = { $true }; DistributionPoint = { $true }; Client = { $true } }

            Test-SetupCmLabHealth -Config $config -EvidenceRoot $TestDrive -Checks $checks |
                Should -Be 'Compliant'
            Test-SetupCmLabHealth -Config $config -EvidenceRoot $TestDrive -Checks $checks |
                Should -Be 'Compliant'

            Should -Invoke Write-SetupCmEvidenceJson -Times 2 -Exactly -ParameterFilter {
                $Name -eq 'health' -and $EvidenceRoot -eq $TestDrive
            }
        }

        It 'writes health check keys in deterministic ordinal order' {
            $checks = @{}
            $checks['Zulu'] = { $true }
            $checks['Alpha'] = { $true }

            Test-SetupCmLabHealth -Config @{} -EvidenceRoot $TestDrive -Checks $checks |
                Should -Be 'Compliant'

            $evidence = Get-Content -LiteralPath (Join-Path $TestDrive 'health.json') -Raw |
                ConvertFrom-Json -AsHashtable
            @($evidence.Keys) | Should -Be @('Alpha', 'Zulu')
        }

        It 'uses the structured SQL and MECM desired-state probes in the default health checks' {
            $config = @{
                sql = @{ instanceName = 'MSSQLSERVER' }
                mecm = @{ siteCode = 'LAB' }
                testClient = @{ name = 'RING0IVY24-01' }
            }
            Mock Get-SetupCmSqlDesiredState { [pscustomobject]@{ State = 'Compliant'; Components = @() } }
            Mock Get-SetupCmMecmDesiredState { [pscustomobject]@{ State = 'Compliant'; Components = @() } }
            Mock Test-SetupCmManagementPoint { $true }
            Mock Test-SetupCmDistributionPoint { $true }
            Mock Test-SetupCmClient { $true }
            Mock Test-SetupCmClientRegistration { $true }

            Test-SetupCmLabHealth -Config $config -EvidenceRoot $TestDrive |
                Should -Be 'Compliant'

            Should -Invoke Get-SetupCmSqlDesiredState -Times 1 -Exactly
            Should -Invoke Get-SetupCmMecmDesiredState -Times 1 -Exactly
        }
    }
}

Describe 'Invoke-SetupCm Health read-only orchestration' {
    InModuleScope SetupCm {
        BeforeEach {
            $config = @{
                evidenceRoot = $TestDrive
                sql = @{ instanceName = 'MSSQLSERVER' }
                mecm = @{ siteCode = 'LAB' }
                testClient = @{ name = 'RING0IVY24-01' }
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
        }

        It 'skips an already healthy lab after one read-only Test evaluation' {
            Mock Test-SetupCmLabHealth { 'Compliant' }

            $result = Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Health

            $result.state | Should -Be 'Skipped'
            Should -Invoke Test-SetupCmLabHealth -Times 1 -Exactly
        }

        It 'rechecks a failed health state without invoking a repair action' {
            Mock Test-SetupCmLabHealth { 'NotCompliant' }

            { Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Health } |
                Should -Throw '*verification failed*'
            Should -Invoke Test-SetupCmLabHealth -Times 2 -Exactly
        }
    }
}

Describe 'Test-SetupCmClientRegistration' {
    InModuleScope SetupCm {
        BeforeAll {
            function Get-CimInstance {
                [pscustomobject]@{
                    Name = 'RING0IVY24-01'
                    Active = 1
                    Obsolete = 0
                }
            }
        }

        It 'accepts an active, non-obsolete MECM resource without requiring ICMP or sqlcmd' {
            $computerName = 'RING0IVY24-01'
            Test-SetupCmClientRegistration -SiteCode LAB -ComputerName $computerName |
                Should -BeTrue
        }
    }
}

Describe 'Export-SetupCmFixture' {
    InModuleScope SetupCm {
        It 'redacts password values before writing the fixture' {
            $sourcePath = Join-Path $TestDrive 'LocationServices.log'
            $fixtureRoot = Join-Path $TestDrive 'fixtures'
            Set-Content -LiteralPath $sourcePath -Value 'Connecting with Password=NotForFixtures; to the management point.' -NoNewline

            Export-SetupCmFixture -SourcePath $sourcePath -FixtureRoot $fixtureRoot
            $fixturePath = Join-Path $fixtureRoot 'LocationServices.log'

            (Get-Content -LiteralPath $fixturePath -Raw) | Should -Be 'Connecting with Password=<redacted>; to the management point.'
        }
    }
}
