@{
    RootModule        = 'SetupCm.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '4b7621b6-e62f-4d87-ae98-e158424b2ec6'
    Author            = 'CMTrace Open'
    CompanyName       = 'CMTrace Open'
    Copyright         = '(c) 2026 CMTrace Open'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Invoke-SetupCm', 'Invoke-SetupCmAcquire')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('SCCM', 'MECM', 'PowerShell', 'Lab')
            ProjectUri = 'https://github.com/cmtraceopen/setup-cm'
        }
    }
}
