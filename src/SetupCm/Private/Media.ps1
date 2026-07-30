function Get-SetupCmMediaRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Container) { return $Path }
    if (-not $IsWindows) { throw 'ISO media mounting can only run on Windows Server.' }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or [IO.Path]::GetExtension($Path) -ne '.iso') { throw "Media path must be an extracted directory or ISO file: $Path" }
    Mount-DiskImage -ImagePath $Path -ErrorAction Stop | Out-Null
    $volume = Get-DiskImage -ImagePath $Path | Get-Volume
    return "$($volume.DriveLetter):\"
}
