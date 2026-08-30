Describe 'SetupCm module' {
    It 'requires PowerShell 7 or newer' {
        $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
    }

    It 'exports the public setup and marker acceptance commands' {
        Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force
        Get-Command Invoke-SetupCm, Invoke-SetupCmAcquire, Invoke-SetupCmClient, `
            Invoke-SetupCmMarkerAcceptance, Test-SetupCmPreflight | Should -HaveCount 5
    }
}
