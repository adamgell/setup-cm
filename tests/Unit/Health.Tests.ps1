Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Test-SetupCmLabHealth' {
    InModuleScope SetupCm {
        It 'returns NotCompliant when the Management Point check fails' {
            Test-SetupCmLabHealth -Config @{ sql = @{ instanceName = 'MSSQLSERVER' }; testClient = @{ name = 'CL01' } } -EvidenceRoot $TestDrive -Checks @{
                Sql = { $true }; ManagementPoint = { $false }; DistributionPoint = { $true }; Client = { $true }
            } |
                Should -Be 'NotCompliant'
        }
    }
}

Describe 'Test-SetupCmClientRegistration' {
    InModuleScope SetupCm {
        It 'requires a discovered active client record for the selected site' {
            $script:clientRegistrationQuery = $null
            Test-SetupCmClientRegistration -SiteCode LAB -ComputerName RING0IVY24-01 -SqlQuery {
                param($Query)
                $script:clientRegistrationQuery = $Query
                'RING0IVY24-01|1|1|LAB'
            } | Should -BeTrue
            $script:clientRegistrationQuery | Should -Match 'v_RA_System_SMSAssignedSites'
        }

        It 'rejects a client discovery record that is inactive' {
            Test-SetupCmClientRegistration -SiteCode LAB -ComputerName RING0IVY24-01 -SqlQuery {
                param($Query)
                'RING0IVY24-01|1|0|LAB'
            } | Should -BeFalse
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
