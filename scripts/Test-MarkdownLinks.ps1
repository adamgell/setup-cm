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

function ConvertTo-MarkdownReferenceLabel {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Label)

    [regex]::Replace($Label.Trim(), '\s+', ' ').ToLowerInvariant()
}

function Remove-MarkdownInlineCode {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

    if (-not $Line.Contains('`')) { return $Line }

    [regex]::Replace(
        $Line,
        '(?<!`)(?<delimiter>`+)(?!`).*?(?<!`)\k<delimiter>(?!`)',
        { param($match) ' ' * $match.Length }
    )
}

function Test-MarkdownCharacterEscaped {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
        [Parameter(Mandatory)][int]$Index
    )

    $backslashCount = 0
    for ($position = $Index - 1; $position -ge 0 -and $Line[$position] -eq '\'; $position--) {
        $backslashCount++
    }
    ($backslashCount % 2) -eq 1
}

function Test-MarkdownLinkMatchEscaped {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
        [Parameter(Mandatory)][System.Text.RegularExpressions.Match]$Match
    )

    $imageMarker = $Match.Groups['image']
    $bracketIndex = $Match.Index
    if ($imageMarker.Success) {
        $bracketIndex += $imageMarker.Length
    }

    if (Test-MarkdownCharacterEscaped -Line $Line -Index $bracketIndex) { return $true }
    if ($imageMarker.Success -and
        (Test-MarkdownCharacterEscaped -Line $Line -Index $Match.Index)) {
        return $true
    }
    return $false
}

function Get-MarkdownContentLine {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$MarkdownPath)

    $lineNumber = 0
    $inFence = $false
    $inIndentedCode = $false
    $fenceCharacter = $null
    $fenceLength = 0
    foreach ($line in @(Get-Content -LiteralPath $MarkdownPath)) {
        $lineNumber++
        if ($line -match '^ {0,3}(?<fence>`{3,}|~{3,})(?<suffix>.*)$') {
            $candidate = [string]$Matches.fence
            $candidateSuffix = [string]$Matches.suffix
            $candidateCharacter = $candidate.Substring(0, 1)
            if (-not $inFence) {
                $inFence = $true
                $fenceCharacter = $candidateCharacter
                $fenceLength = $candidate.Length
            }
            elseif ($candidateCharacter -ceq $fenceCharacter -and
                $candidate.Length -ge $fenceLength -and
                [string]::IsNullOrWhiteSpace($candidateSuffix)) {
                $inFence = $false
                $fenceCharacter = $null
                $fenceLength = 0
            }
            continue
        }
        if ($inFence) { continue }

        if ($line -match '^(?: {4}|\t)') {
            $inIndentedCode = $true
            continue
        }
        if ($inIndentedCode) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $inIndentedCode = $false
        }

        [pscustomobject]@{ Number = $lineNumber; Text = $line }
    }
}

function Get-MarkdownAnchors {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$MarkdownPath)

    $anchors = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $slugCounts = @{}
    foreach ($contentLine in @(Get-MarkdownContentLine -MarkdownPath $MarkdownPath)) {
        $line = $contentLine.Text

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
    $contentLines = @(Get-MarkdownContentLine -MarkdownPath $markdownFile)
    $referenceDefinitions = @{}
    foreach ($contentLine in $contentLines) {
        $definitionLine = Remove-MarkdownInlineCode -Line $contentLine.Text
        if ($definitionLine -match '^\s{0,3}\[(?<label>[^\]]+)\]:\s*(?<destination><[^>]+>|\S+)') {
            $label = ConvertTo-MarkdownReferenceLabel -Label $Matches.label
            if (-not $referenceDefinitions.ContainsKey($label)) {
                $referenceDefinitions[$label] = $Matches.destination.Trim().Trim('<', '>')
            }
        }
    }

    foreach ($contentLine in $contentLines) {
        $line = Remove-MarkdownInlineCode -Line $contentLine.Text
        $lineNumber = $contentLine.Number
        if ($line -match '^\s{0,3}\[[^\]]+\]:\s*(?:<[^>]+>|\S+)') { continue }

        $destinations = [System.Collections.Generic.List[string]]::new()
        foreach ($match in [regex]::Matches($line, '(?<image>!)?\[[^\]]*\]\((?<destination><[^>]+>|[^)\s]+)')) {
            if (Test-MarkdownLinkMatchEscaped -Line $line -Match $match) { continue }
            [void]$destinations.Add($match.Groups['destination'].Value.Trim().Trim('<', '>'))
        }
        foreach ($match in [regex]::Matches(
            $line,
            '(?<image>!)?\[(?<text>[^\]]+)\]\[(?<label>[^\]]*)\]'
        )) {
            if (Test-MarkdownLinkMatchEscaped -Line $line -Match $match) { continue }
            $labelText = if ([string]::IsNullOrWhiteSpace($match.Groups['label'].Value)) {
                $match.Groups['text'].Value
            }
            else {
                $match.Groups['label'].Value
            }
            $label = ConvertTo-MarkdownReferenceLabel -Label $labelText
            if (-not $referenceDefinitions.ContainsKey($label)) {
                [void]$errors.Add("$relativeSource`:$lineNumber undefined reference label '$labelText'")
                continue
            }
            [void]$destinations.Add([string]$referenceDefinitions[$label])
        }
        foreach ($match in [regex]::Matches(
            $line,
            '(?<![!\\\]])\[(?<label>[^\]\[]+)\](?!\s*(?:\(|\[))'
        )) {
            $labelText = $match.Groups['label'].Value
            $label = ConvertTo-MarkdownReferenceLabel -Label $labelText
            if ($referenceDefinitions.ContainsKey($label)) {
                [void]$destinations.Add([string]$referenceDefinitions[$label])
            }
        }

        foreach ($destination in $destinations) {
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
