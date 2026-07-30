Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Test-SetupCmSql' {
    InModuleScope SetupCm {
        It 'returns Compliant when the configured SQL service is running' {
            Test-SetupCmSql -InstanceName 'MSSQLSERVER' -ServiceStateProvider {
                [pscustomobject]@{ Status = 'Running' }
            } | Should -Be 'Compliant'
        }

        It 'returns NotCompliant when the configured SQL service is stopped' {
            Test-SetupCmSql -InstanceName 'MSSQLSERVER' -ServiceStateProvider {
                [pscustomobject]@{ Status = 'Stopped' }
            } | Should -Be 'NotCompliant'
        }
    }
}
