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
        $parameterNames | Should -Contain 'SourceCommit'
        $stageParameter = $ast.ParamBlock.Parameters | Where-Object Name -Match 'Stage'
        $validateSet = $stageParameter.Attributes | Where-Object TypeName -Match 'ValidateSet'
        @($validateSet.PositionalArguments.Value) | Should -Contain 'Marker'
        $ast.Extent.Text | Should -Match '\$ErrorActionPreference\s*=\s*''Stop'''
        $ast.Extent.Text | Should -Match 'Invoke-SetupCm.*-ConfigPath.*\$ConfigPath.*-Mode.*\$Mode.*-Stage.*\$Stage.*-SourceCommit.*\$SourceCommit'
    }
}
