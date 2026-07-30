function Invoke-SetupCm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [ValidateSet('Guided', 'Unattended')]
        [string]$Mode = 'Guided',

        [string[]]$Stage
    )

    throw 'The SetupCm stage engine is not implemented yet.'
}
