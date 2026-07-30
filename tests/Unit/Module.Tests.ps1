Describe 'SetupCm module' {
    It 'requires PowerShell 7 or newer' {
        $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
    }

    It 'exports the two public commands' {
        Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force
        Get-Command Invoke-SetupCm, Invoke-SetupCmAcquire | Should -HaveCount 2
    }
}
