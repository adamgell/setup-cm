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

    It 'does not close a fence when an inner example uses a different delimiter' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') -Value @'
````markdown
~~~markdown
[Example only](missing.md)
~~~
````
'@

        $result = & $linkScript -RepositoryRoot $TestDrive -Path index.md

        $result.State | Should -BeExactly 'Passed'
        $result.LocalLinksChecked | Should -Be 0
    }

    It 'does not collect headings exposed by a shorter nested fence' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') `
            -Value '[Guide](guide.md#not-a-heading)'
        Set-Content -LiteralPath (Join-Path $TestDrive 'guide.md') -Value @'
````markdown
```markdown
## Not a heading
```
````

# Real heading
'@

        { & $linkScript -RepositoryRoot $TestDrive -Path index.md, guide.md } |
            Should -Throw '*#not-a-heading*'
    }

    It 'does not close a fence when a matching marker has trailing text' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') -Value @'
```markdown
```not-a-closing-fence
[Example only](missing.md)
```
'@

        $result = & $linkScript -RepositoryRoot $TestDrive -Path index.md

        $result.State | Should -BeExactly 'Passed'
        $result.LocalLinksChecked | Should -Be 0
    }

    It 'documents atomic source extraction with cleanup in <Runbook>' -ForEach @(
        @{ Runbook = 'docs/RUNBOOK.md' }
        @{ Runbook = 'docs/gitbook/src/operations/runbook.md' }
    ) {
        $content = Get-Content -LiteralPath (Join-Path $repositoryRoot $Runbook) -Raw

        $content | Should -Match '\$temporarySourceRoot\s*='
        $content | Should -Match 'tar\.exe -xf \$archivePath -C \$temporarySourceRoot'
        $content | Should -Match 'Move-Item -LiteralPath \$temporarySourceRoot -Destination \$sourceRoot'
        $content | Should -Match 'Remove-Item -LiteralPath \$temporarySourceRoot -Recurse -Force'
    }

    It 'resolves reference-style local links whose definitions follow their usage' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') -Value @'
[Guide][guide-reference]

[guide-reference]: guide.md#exact-heading
'@
        Set-Content -LiteralPath (Join-Path $TestDrive 'guide.md') -Value '## Exact heading'

        $result = & $linkScript -RepositoryRoot $TestDrive -Path index.md, guide.md

        $result.State | Should -BeExactly 'Passed'
        $result.LocalLinksChecked | Should -Be 1
    }

    It 'fails when a reference-style definition names a missing local target' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') -Value @'
[Missing][missing-reference]

[missing-reference]: missing.md
'@

        { & $linkScript -RepositoryRoot $TestDrive -Path index.md } |
            Should -Throw '*missing.md*'
    }

    It 'fails when a reference-style usage has no definition' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'index.md') `
            -Value '[Missing][undefined-reference]'

        { & $linkScript -RepositoryRoot $TestDrive -Path index.md } |
            Should -Throw '*undefined-reference*'
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
