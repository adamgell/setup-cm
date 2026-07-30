Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'SetupCm requires PowerShell 7 or newer.'
}

foreach ($folder in 'Private', 'Public') {
    $path = Join-Path $PSScriptRoot $folder
    if (Test-Path -LiteralPath $path) {
        Get-ChildItem -LiteralPath $path -Filter '*.ps1' -File |
            Sort-Object Name |
            ForEach-Object { . $_.FullName }
    }
}

Export-ModuleMember -Function Invoke-SetupCm, Invoke-SetupCmAcquire, Test-SetupCmPreflight
