Describe 'Autopilot Agent entry point' {
    It 'accepts and forwards unattended stage selection' {
        $scriptPath = Join-Path $PSScriptRoot '../../scripts/Invoke-SetupCm.ps1'
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)

        $parseErrors | Should -BeNullOrEmpty
        $parameterNames = @($ast.ParamBlock.Parameters.Name.VariablePath.UserPath)
        $parameterNames | Should -Contain 'ConfigPath'
        $parameterNames | Should -Contain 'Mode'
        $parameterNames | Should -Contain 'Stage'
        $ast.Extent.Text | Should -Match '\$ErrorActionPreference\s*=\s*''Stop'''
        $ast.Extent.Text | Should -Match 'Invoke-SetupCm.*-ConfigPath.*\$ConfigPath.*-Mode.*\$Mode.*-Stage.*\$Stage'
    }
}
