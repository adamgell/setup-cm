[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent),
    [string[]]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-MarkdownHeadingSlug {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Heading)

    $value = [regex]::Replace($Heading, '<[^>]+>', '')
    $value = [regex]::Replace($value, '[`*_~]', '')
    $value = [regex]::Replace($value.ToLowerInvariant(), '[^\p{L}\p{Nd}\p{Mn}\p{Mc}\s_-]', '')
    [regex]::Replace($value.Trim(), '\s+', '-')
}

function Get-MarkdownAnchors {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$MarkdownPath)

    $anchors = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $slugCounts = @{}
    $inFence = $false
    foreach ($line in @(Get-Content -LiteralPath $MarkdownPath)) {
        if ($line -match '^\s*(?:`{3,}|~{3,})') {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) { continue }

        if ($line -match '^\s{0,3}#{1,6}\s+(?<heading>.+?)\s*#*\s*$') {
            $baseSlug = ConvertTo-MarkdownHeadingSlug -Heading $Matches.heading
            if (-not [string]::IsNullOrWhiteSpace($baseSlug)) {
                $slug = $baseSlug
                if ($slugCounts.ContainsKey($baseSlug)) {
                    $slugCounts[$baseSlug]++
                    $slug = '{0}-{1}' -f $baseSlug, $slugCounts[$baseSlug]
                }
                else {
                    $slugCounts[$baseSlug] = 0
                }
                [void]$anchors.Add($slug)
            }
        }

        foreach ($match in [regex]::Matches(
            $line,
            '<a\s+(?:id|name)=["''](?<anchor>[^"'']+)["'']',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )) {
            [void]$anchors.Add($match.Groups['anchor'].Value)
        }
    }
    Write-Output -NoEnumerate $anchors
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$candidatePaths = if ($Path -and $Path.Count -gt 0) {
    @($Path)
}
else {
    @('README.md', 'docs')
}

$files = [System.Collections.Generic.List[string]]::new()
foreach ($candidate in $candidatePaths) {
    $candidatePath = if ([System.IO.Path]::IsPathRooted($candidate)) {
        [System.IO.Path]::GetFullPath($candidate)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $candidate))
    }
    if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
        if ([System.IO.Path]::GetExtension($candidatePath) -ieq '.md') {
            [void]$files.Add($candidatePath)
        }
        continue
    }
    if (Test-Path -LiteralPath $candidatePath -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $candidatePath -Filter '*.md' -File -Recurse) {
            [void]$files.Add($file.FullName)
        }
        continue
    }
    throw "Markdown path does not exist: $candidate"
}

$markdownFiles = @($files | Sort-Object -Unique)
$errors = [System.Collections.Generic.List[string]]::new()
$anchorCache = @{}
$localLinkCount = 0
$pathComparison = if ($IsWindows) {
    [System.StringComparison]::OrdinalIgnoreCase
}
else {
    [System.StringComparison]::Ordinal
}
$rootPrefix = $resolvedRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar

foreach ($markdownFile in $markdownFiles) {
    $relativeSource = [System.IO.Path]::GetRelativePath($resolvedRoot, $markdownFile).Replace('\', '/')
    $lineNumber = 0
    $inFence = $false
    foreach ($line in @(Get-Content -LiteralPath $markdownFile)) {
        $lineNumber++
        if ($line -match '^\s*(?:`{3,}|~{3,})') {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) { continue }

        foreach ($match in [regex]::Matches($line, '!?\[[^\]]*\]\((?<destination><[^>]+>|[^)\s]+)')) {
            $destination = $match.Groups['destination'].Value.Trim().Trim('<', '>')
            if ([string]::IsNullOrWhiteSpace($destination) -or
                $destination -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
                $destination.StartsWith('//')) {
                continue
            }

            $localLinkCount++
            $parts = $destination -split '#', 2
            $filePart = $parts[0]
            $fragment = if ($parts.Count -eq 2) { $parts[1] } else { '' }
            try {
                $filePart = [System.Uri]::UnescapeDataString($filePart)
                $fragment = [System.Uri]::UnescapeDataString($fragment)
            }
            catch {
                [void]$errors.Add("$relativeSource`:$lineNumber invalid escaped link '$destination'")
                continue
            }

            if ([string]::IsNullOrWhiteSpace($filePart)) {
                $targetPath = $markdownFile
            }
            elseif ([System.IO.Path]::IsPathRooted($filePart)) {
                [void]$errors.Add("$relativeSource`:$lineNumber root-relative link is not portable: '$destination'")
                continue
            }
            else {
                $filePartWithoutQuery = ($filePart -split '\?', 2)[0]
                $targetPath = [System.IO.Path]::GetFullPath(
                    (Join-Path (Split-Path $markdownFile -Parent) $filePartWithoutQuery)
                )
            }

            if (-not $targetPath.StartsWith($rootPrefix, $pathComparison) -and
                -not $targetPath.Equals($resolvedRoot, $pathComparison)) {
                [void]$errors.Add("$relativeSource`:$lineNumber link leaves repository: '$destination'")
                continue
            }
            if (-not (Test-Path -LiteralPath $targetPath)) {
                [void]$errors.Add("$relativeSource`:$lineNumber missing local target '$destination'")
                continue
            }

            if (-not [string]::IsNullOrWhiteSpace($fragment) -and
                [System.IO.Path]::GetExtension($targetPath) -ieq '.md') {
                if (-not $anchorCache.ContainsKey($targetPath)) {
                    $anchorCache[$targetPath] = Get-MarkdownAnchors -MarkdownPath $targetPath
                }
                if (-not $anchorCache[$targetPath].Contains($fragment)) {
                    [void]$errors.Add("$relativeSource`:$lineNumber missing anchor '#$fragment' in '$destination'")
                }
            }
        }
    }
}

if ($errors.Count -gt 0) {
    throw "Broken local Markdown links:`n$($errors -join "`n")"
}

[pscustomobject]@{
    State = 'Passed'
    FilesChecked = $markdownFiles.Count
    LocalLinksChecked = $localLinkCount
}
