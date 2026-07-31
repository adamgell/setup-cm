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
