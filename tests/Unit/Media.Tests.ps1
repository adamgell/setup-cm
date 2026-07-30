Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Get-SetupCmMediaRoot' {
    InModuleScope SetupCm {
        It 'returns an extracted media directory unchanged' {
            Get-SetupCmMediaRoot -Path $TestDrive | Should -Be $TestDrive
        }
    }
}
