Describe 'SetupCm module' {
    It 'requires PowerShell 7 or newer' {
        $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
    }

    It 'exports the public client installation command' {
        Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force
        Get-Command Invoke-SetupCm, Invoke-SetupCmAcquire, Invoke-SetupCmClient, Test-SetupCmPreflight | Should -HaveCount 4
    }
}
