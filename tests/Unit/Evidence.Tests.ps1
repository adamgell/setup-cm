Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Write-SetupCmEvidenceJson' {
    InModuleScope SetupCm {
        It 'removes nested sensitive fields and credential-like string values' {
            $value = [ordered]@{
                stage = 'Acquire'
                sourceUri = 'https://private.example.invalid/media.iso'
                nested = [ordered]@{
                    password = 'NotForEvidence'
                    token = 'also-not-for-evidence'
                    status = 'Password=NotForEvidence; completed'
                    client_secret = 'third-secret'
                    apiKey = 'fourth-secret'
                }
            }

            $path = Write-SetupCmEvidenceJson -EvidenceRoot $TestDrive -Name 'sanitized' -Value $value
            $json = Get-Content -LiteralPath $path -Raw
            $parsed = $json | ConvertFrom-Json

            $json | Should -Not -Match 'NotForEvidence|also-not-for-evidence|third-secret|fourth-secret|private\.example'
            $parsed.stage | Should -Be 'Acquire'
            $parsed.PSObject.Properties.Name | Should -Not -Contain 'sourceUri'
            $parsed.nested.PSObject.Properties.Name | Should -Not -Contain 'password'
            $parsed.nested.PSObject.Properties.Name | Should -Not -Contain 'token'
            $parsed.nested.PSObject.Properties.Name | Should -Not -Contain 'client_secret'
            $parsed.nested.PSObject.Properties.Name | Should -Not -Contain 'apiKey'
            $parsed.nested.status | Should -Be 'Password=<redacted>; completed'
        }

        It 'redacts a private URL embedded in a safe message field' {
            $path = Write-SetupCmEvidenceJson -EvidenceRoot $TestDrive -Name 'uri-message' -Value @{
                message = 'Download failed from https://private.example.invalid/path?sig=secret'
            }

            $json = Get-Content -LiteralPath $path -Raw
            $json | Should -Not -Match 'private\.example|sig=secret'
            ($json | ConvertFrom-Json).message | Should -Be 'Download failed from <redacted-uri>'
        }

        It 'fully redacts quoted credential assignments that contain spaces' {
            $path = Write-SetupCmEvidenceJson -EvidenceRoot $TestDrive -Name 'quoted-credentials' -Value @{
                message = 'Password="two words"; Token=''three words''; Pwd=four'
            }

            $json = Get-Content -LiteralPath $path -Raw
            $message = ($json | ConvertFrom-Json).message
            $json | Should -Not -Match 'two words|three words|four'
            $message | Should -Be 'Password=<redacted>; Token=<redacted>; Pwd=<redacted>'
        }

        It 'redacts API key assignments and HTTP header forms in free text' {
            $path = Write-SetupCmEvidenceJson -EvidenceRoot $TestDrive -Name 'api-key-text' -Value @{
                message = 'apiKey="two words"; X-Api-Key: header-secret; API_KEY=third-secret'
            }

            $json = Get-Content -LiteralPath $path -Raw
            $message = ($json | ConvertFrom-Json).message
            $json | Should -Not -Match 'two words|header-secret|third-secret'
            $message | Should -Be 'apiKey=<redacted>; X-Api-Key: <redacted>; API_KEY=<redacted>'
        }

        It 'removes composite sensitive keys while preserving safe path and status fields' {
            $sensitiveValues = 1..6 | ForEach-Object { "sensitive-value-$_" }
            $value = [ordered]@{
                databasePassword = $sensitiveValues[0]
                refreshTokenValue = $sensitiveValues[1]
                thirdPartyApiKey = $sensitiveValues[2]
                sqlConnectionString = $sensitiveValues[3]
                artifactSourceUri = $sensitiveValues[4]
                vaultSourcePath = $sensitiveValues[5]
                artifactPath = 'C:\SetupCm\cache\mecm.iso'
                securityState = 'Compliant'
            }

            $path = Write-SetupCmEvidenceJson -EvidenceRoot $TestDrive -Name 'composite-keys' -Value $value
            $json = Get-Content -LiteralPath $path -Raw
            $parsed = $json | ConvertFrom-Json

            $json | Should -Not -Match 'sensitive-value'
            $parsed.PSObject.Properties.Name | Should -Not -Contain 'databasePassword'
            $parsed.PSObject.Properties.Name | Should -Not -Contain 'refreshTokenValue'
            $parsed.PSObject.Properties.Name | Should -Not -Contain 'thirdPartyApiKey'
            $parsed.PSObject.Properties.Name | Should -Not -Contain 'sqlConnectionString'
            $parsed.PSObject.Properties.Name | Should -Not -Contain 'artifactSourceUri'
            $parsed.PSObject.Properties.Name | Should -Not -Contain 'vaultSourcePath'
            $parsed.artifactPath | Should -Be 'C:\SetupCm\cache\mecm.iso'
            $parsed.securityState | Should -Be 'Compliant'
        }

        It 'preserves safe arrays and component fields' {
            $value = [ordered]@{
                state = 'Compliant'
                components = @(
                    [ordered]@{ name = 'SqlService'; state = 'Compliant' },
                    [ordered]@{ name = 'Tcp1433'; state = 'Compliant' }
                )
            }

            $path = Write-SetupCmEvidenceJson -EvidenceRoot $TestDrive -Name 'components' -Value $value
            $parsed = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json

            $parsed.state | Should -Be 'Compliant'
            $parsed.components | Should -HaveCount 2
            $parsed.components[1].name | Should -Be 'Tcp1433'
        }

        It 'preserves an empty safe array instead of converting it to null' {
            $path = Write-SetupCmEvidenceJson -EvidenceRoot $TestDrive -Name 'empty-array' -Value @{
                components = @()
            }
            $json = Get-Content -LiteralPath $path -Raw

            $json | Should -Match '"components"\s*:\s*\[\]'
        }
    }
}

Describe 'New-SetupCmRunEvidence' {
    InModuleScope SetupCm {
        It 'writes run metadata for an exact source commit' {
            $commit = '0123456789abcdef0123456789abcdef01234567'

            $runRoot = New-SetupCmRunEvidence -Root $TestDrive -SourceCommit $commit
            $metadata = Get-Content -LiteralPath (Join-Path $runRoot 'run.json') -Raw | ConvertFrom-Json

            $metadata.sourceCommit | Should -Be $commit
            $metadata.startedAt | Should -Not -BeNullOrEmpty
        }

        It 'rejects an abbreviated source commit' {
            { New-SetupCmRunEvidence -Root $TestDrive -SourceCommit 'abc1234' } |
                Should -Throw '*40-character*'
        }
    }
}
