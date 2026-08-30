Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Invoke-SetupCmStage' {
    InModuleScope SetupCm {
        It 'skips Apply when Test reports Compliant' {
            $script:applied = $false

            $result = Invoke-SetupCmStage -Name 'Sample' -Test { 'Compliant' } -Apply { $script:applied = $true } -Verify { 'Compliant' } -EvidenceRoot $TestDrive

            $script:applied | Should -BeFalse
            $result.state | Should -Be 'Skipped'
        }

        It 'does not run Verify after Apply throws' {
            {
                Invoke-SetupCmStage -Name 'Sample' -Test { 'NotCompliant' } -Apply { throw 'blocked' } -Verify { throw 'must not run' } -EvidenceRoot $TestDrive
            } | Should -Throw '*blocked*'
        }

        It 'fails closed without Apply when Test reports Conflict' {
            $script:applied = $false

            {
                Invoke-SetupCmStage -Name 'Sample' -Test { 'Conflict' } -Apply { $script:applied = $true } -Verify { 'Compliant' } -EvidenceRoot $TestDrive
            } | Should -Throw '*conflict*'

            $script:applied | Should -BeFalse
            (Get-Content -LiteralPath (Join-Path $TestDrive 'stage-Sample.json') -Raw | ConvertFrom-Json).state |
                Should -Be 'Failed'
        }

        It 'fails when independent Verify is not compliant after Apply succeeds' {
            $script:applied = $false
            $script:verified = $false

            {
                Invoke-SetupCmStage -Name 'Sample' -Test { 'NotCompliant' } -Apply { $script:applied = $true } -Verify { $script:verified = $true; 'NotCompliant' } -EvidenceRoot $TestDrive
            } | Should -Throw '*verification failed*'

            $script:applied | Should -BeTrue
            $script:verified | Should -BeTrue
            (Get-Content -LiteralPath (Join-Path $TestDrive 'stage-Sample.json') -Raw | ConvertFrom-Json).state |
                Should -Be 'Failed'
        }

        It 'fails closed on an unknown Test result' {
            $script:applied = $false

            {
                Invoke-SetupCmStage -Name 'Sample' -Test { 'Maybe' } -Apply { $script:applied = $true } -Verify { 'Compliant' } -EvidenceRoot $TestDrive
            } | Should -Throw '*unsupported compliance state*'

            $script:applied | Should -BeFalse
        }
    }
}
