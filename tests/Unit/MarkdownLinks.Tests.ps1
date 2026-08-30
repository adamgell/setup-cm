Describe 'Test-MarkdownLinks script' {
    BeforeAll {
        $linkScript = Join-Path $PSScriptRoot '../../scripts/Test-MarkdownLinks.ps1'
        $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    }

    It 'resolves local files and heading anchors while ignoring links in fenced code' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') -Value @'
# Start

[Guide](guide.md#exact-heading)
[External](https://example.invalid/docs)

```markdown
[Example only](missing.md)
```
'@
        Set-Content -LiteralPath (Join-Path $TestDrive 'guide.md') -Value @'
# Guide

## Exact heading
'@

        $result = & $linkScript -RepositoryRoot $TestDrive -Path index.md, guide.md

        $result.State | Should -BeExactly 'Passed'
        $result.FilesChecked | Should -Be 2
        $result.LocalLinksChecked | Should -Be 1
    }

    It 'fails with the source location when a local target file is missing' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') -Value '[Missing](missing.md)'

        { & $linkScript -RepositoryRoot $TestDrive -Path index.md } |
            Should -Throw '*index.md:1*missing.md*'
    }

    It 'fails when a Markdown heading anchor does not resolve' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') -Value '[Guide](guide.md#missing-heading)'
        Set-Content -LiteralPath (Join-Path $TestDrive 'guide.md') -Value '# Existing heading'

        { & $linkScript -RepositoryRoot $TestDrive -Path index.md, guide.md } |
            Should -Throw '*missing-heading*'
    }

    It 'requires an exact heading anchor rather than a substring match' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') -Value '[Guide](guide.md#existing)'
        Set-Content -LiteralPath (Join-Path $TestDrive 'guide.md') -Value '# Existing heading'

        { & $linkScript -RepositoryRoot $TestDrive -Path index.md, guide.md } |
            Should -Throw '*#existing*'
    }

    It 'validates every current repository Markdown link' {
        $result = & $linkScript -RepositoryRoot $repositoryRoot

        $result.State | Should -BeExactly 'Passed'
        $result.FilesChecked | Should -BeGreaterThan 1
        $result.LocalLinksChecked | Should -BeGreaterThan 1
    }
}
