Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Invoke-SetupCmStage' {
    InModuleScope SetupCm {
        It 'skips Apply when Test reports Compliant' {
            $applied = $false

            $result = Invoke-SetupCmStage -Name 'Sample' -Test { 'Compliant' } -Apply { $applied = $true } -Verify { 'Compliant' } -EvidenceRoot $TestDrive

            $applied | Should -BeFalse
            $result.state | Should -Be 'Skipped'
        }

        It 'does not run Verify after Apply throws' {
            {
                Invoke-SetupCmStage -Name 'Sample' -Test { 'NotCompliant' } -Apply { throw 'blocked' } -Verify { throw 'must not run' } -EvidenceRoot $TestDrive
            } | Should -Throw '*blocked*'
        }
    }
}
