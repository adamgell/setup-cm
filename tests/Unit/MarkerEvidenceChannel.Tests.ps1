Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Setup-CM marker evidence fixed contract' {
    InModuleScope SetupCm {
        It 'pins the approved LabZ1 evidence channel and predecessor detector' {
            $contract = Get-SetupCmMarkerFixedContract

            $contract.MarkerLength | Should -Be 78
            $contract.PreviousDetectorFile.Name | Should -BeExactly `
                'Test-SetupCmPhase1Marker.vbs'
            $contract.PreviousDetectorFile.Length | Should -Be 1310
            $contract.PreviousDetectorFile.Hash | Should -BeExactly `
                'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
            $contract.EvidenceChannel.ShareName | Should -BeExactly `
                'SetupCmMarkerEvidence$'
            $contract.EvidenceChannel.ShareDescription | Should -BeExactly `
                'Setup-CM LabZ1 marker evidence for RING0IVY24-01'
            $contract.EvidenceChannel.LocalParent | Should -BeExactly `
                'C:\ProgramData\SetupCm\MarkerEvidence'
            $contract.EvidenceChannel.LocalPath | Should -BeExactly `
                'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01'
            $contract.EvidenceChannel.FileName | Should -BeExactly `
                'marker-evidence.json'
            $contract.EvidenceChannel.UncPath | Should -BeExactly `
                '\\LABZ1-CM01.test.gell.one\SetupCmMarkerEvidence$\marker-evidence.json'
            $contract.EvidenceChannel.ComputerAccount | Should -BeExactly `
                'TEST\RING0IVY24-01$'
            $contract.EvidenceChannel.SchemaVersion | Should -Be 1
            $contract.EvidenceChannel.VerificationMethod | Should -BeExactly `
                'CertUtilSha256Exact'
            $contract.EvidenceChannel.MaximumBytes | Should -Be 2048
            $contract.EvidenceChannel.FreshnessMinutes | Should -Be 30
            $contract.EvidenceChannel.FutureToleranceMinutes | Should -Be 2
            $contract.EvidenceChannel.PollSeconds | Should -Be 15
            $contract.EvidenceChannel.ConvergenceSeconds | Should -Be 900
        }
    }
}

Describe 'Setup-CM marker published evidence parser' {
    InModuleScope SetupCm {
        BeforeAll {
            $script:exactEvidenceJson = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
        }

        It 'parses the exact six-field marker evidence record without coercion' {
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($script:exactEvidenceJson)

            $record = ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes

            $record.PSObject.Properties.Name | Should -BeExactly @(
                'schemaVersion',
                'computerName',
                'markerPath',
                'markerSha256',
                'markerLength',
                'verificationMethod'
            )
            $record.schemaVersion | Should -BeOfType ([int])
            $record.schemaVersion | Should -Be 1
            $record.computerName | Should -BeExactly 'RING0IVY24-01'
            $record.markerPath | Should -BeExactly 'C:\ProgramData\SetupCm\Phase1\marker.json'
            $record.markerSha256 | Should -BeExactly `
                '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
            $record.markerLength | Should -BeOfType ([long])
            $record.markerLength | Should -Be 78
            $record.verificationMethod | Should -BeExactly 'CertUtilSha256Exact'
        }

        It 'rejects an unknown property instead of ignoring it' {
            $json = $script:exactEvidenceJson.Substring(0, $script:exactEvidenceJson.Length - 1) +
                ',"extra":"unexpected"}'
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw '*properties are not exact*'
        }

        It 'rejects a duplicate property even when the property count is six' {
            $json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78}'
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw '*properties are not exact*'
        }

        It 'rejects a record larger than 2,048 bytes before parsing it' {
            $encoding = [System.Text.UTF8Encoding]::new($false)
            $exactBytes = $encoding.GetBytes($script:exactEvidenceJson)
            $oversizedJson = $script:exactEvidenceJson + (' ' * (2049 - $exactBytes.Count))
            $bytes = $encoding.GetBytes($oversizedJson)

            $bytes.Count | Should -Be 2049
            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw '*2,048-byte limit*'
        }

        It 'rejects non-ASCII JSON even when its UTF-8 encoding is valid' {
            $json = $script:exactEvidenceJson.Replace('RING0IVY24-01', 'RING0IVY24-01é')
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw '*ASCII-compatible*'
        }

        It 'rejects invalid UTF-8 bytes' {
            $bytes = [byte[]](0x7b, 0x22, 0x78, 0x22, 0x3a, 0xc3, 0x28, 0x7d)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } |
                Should -Throw
        }

        It 'rejects a non-exact JSON envelope: <Name>' -ForEach @(
            @{ Name = 'empty bytes'; Json = '' }
            @{ Name = 'array root'; Json = '[]' }
            @{
                Name = 'missing property'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78}'
            }
            @{
                Name = 'string schema version'
                Json = '{"schemaVersion":"1","computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'fractional marker length'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78.5,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'null computer name'
                Json = '{"schemaVersion":1,"computerName":null,"markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'comment'
                Json = '{/*comment*/"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'trailing comma'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact",}'
            }
            @{
                Name = 'trailing non-whitespace'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}x'
            }
        ) {
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Json)

            { ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes } | Should -Throw
        }
    }
}

Describe 'Setup-CM marker published evidence assessment' {
    InModuleScope SetupCm {
        BeforeAll {
            function New-TestPublishedEvidenceInventory {
                param(
                    [string]$Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}',
                    [string]$TargetComputerSid = 'S-1-5-21-1-2-3-1001',
                    [string]$OwnerSid = 'S-1-5-21-1-2-3-1001',
                    [datetime]$LastWriteTimeUtc = [datetime]'2026-08-30T12:00:00Z',
                    [bool]$Exists = $true,
                    [bool]$IsReparsePoint = $false,
                    [bool]$AclExact = $true,
                    [string]$ReadError = '',
                    [Nullable[long]]$Length
                )

                $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Json)
                [pscustomobject]@{
                    TargetComputerSid = $TargetComputerSid
                    Evidence = [pscustomobject]@{
                        Exists = $Exists
                        IsReparsePoint = $IsReparsePoint
                        Length = if ($null -eq $Length) { [long]$bytes.Count } else { [long]$Length }
                        Bytes = $bytes
                        OwnerSid = $OwnerSid
                        AclExact = $AclExact
                        LastWriteTimeUtc = $LastWriteTimeUtc
                        ReadError = $ReadError
                    }
                }
            }
        }

        It 'accepts exact client-owned evidence received within the freshness window' {
            $inventory = New-TestPublishedEvidenceInventory

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
            $assessment.MarkerHash | Should -BeExactly `
                '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
            $assessment.MarkerLength | Should -Be 78
            $assessment.MarkerHashVerification | Should -BeExactly `
                'DirectAuthenticatedClientEvidence'
            $assessment.ReceiptTimeUtc.ToUniversalTime().ToString('o') | Should -BeExactly `
                '2026-08-30T12:00:00.0000000Z'
            $assessment.OwnerSid | Should -BeExactly 'S-1-5-21-1-2-3-1001'
        }

        It 'classifies a missing final record as pending evidence' {
            $inventory = New-TestPublishedEvidenceInventory -Exists $false

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'ClientEvidencePending'
            $assessment.MarkerHash | Should -BeNullOrEmpty
            $assessment.MarkerHashVerification | Should -BeExactly 'ClientEvidencePending'
        }

        It 'classifies a record older than 30 minutes as pending evidence' {
            $inventory = New-TestPublishedEvidenceInventory

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:30:01Z')

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'ClientEvidencePending'
            $assessment.MarkerHashVerification | Should -BeExactly 'ClientEvidencePending'
        }

        It 'accepts a record at the exact 30-minute freshness boundary' {
            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory (New-TestPublishedEvidenceInventory) `
                -NowUtc ([datetime]'2026-08-30T12:30:00Z')

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
        }

        It 'fails closed when the server receipt is more than two minutes in the future' {
            $inventory = New-TestPublishedEvidenceInventory `
                -LastWriteTimeUtc ([datetime]'2026-08-30T12:12:01Z')

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceReceiptInFuture'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'accepts a server receipt at the exact two-minute future tolerance' {
            $inventory = New-TestPublishedEvidenceInventory `
                -LastWriteTimeUtc ([datetime]'2026-08-30T12:12:00Z')

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
        }

        It 'matches the fixed computer name case-insensitively' {
            $json = $script:exactEvidenceJson.Replace('RING0IVY24-01', 'ring0ivy24-01')
            $inventory = New-TestPublishedEvidenceInventory -Json $json

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Compliant'
            $assessment.Reason | Should -BeExactly 'Exact'
        }

        It 'keeps evidence pending when it predates this run evaluation request' {
            $inventory = New-TestPublishedEvidenceInventory `
                -LastWriteTimeUtc ([datetime]'2026-08-30T12:05:00Z')

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z') `
                -MinimumReceiptUtc ([datetime]'2026-08-30T12:06:00Z')

            $assessment.State | Should -BeExactly 'NotCompliant'
            $assessment.Reason | Should -BeExactly 'ClientEvidencePending'
            $assessment.MarkerHashVerification | Should -BeExactly 'ClientEvidencePending'
        }

        It 'fails closed when the final record owner is not the target computer SID' {
            $inventory = New-TestPublishedEvidenceInventory `
                -OwnerSid 'S-1-5-21-1-2-3-9999'

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceOwnerMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'fails closed when the final record ACL is not the exact inherited set' {
            $inventory = New-TestPublishedEvidenceInventory -AclExact $false

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceAclMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'fails closed when the final record is a reparse point' {
            $inventory = New-TestPublishedEvidenceInventory -IsReparsePoint $true

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceReparsePoint'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'fails closed on a contradictory record field: <Name>' -ForEach @(
            @{
                Name = 'schema version'
                Json = '{"schemaVersion":2,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'computer name'
                Json = '{"schemaVersion":1,"computerName":"OTHER-CLIENT","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'marker path'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\Other\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'marker hash'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"0000000000000000000000000000000000000000000000000000000000000000","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'marker length'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":79,"verificationMethod":"CertUtilSha256Exact"}'
            }
            @{
                Name = 'verification method'
                Json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"ProjectedServerState"}'
            }
        ) {
            $inventory = New-TestPublishedEvidenceInventory -Json $Json

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceRecordMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'returns a bounded conflict for malformed evidence instead of throwing' {
            $inventory = New-TestPublishedEvidenceInventory -Json '{'

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceMalformed'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'returns a bounded unavailable result when the local read fails' {
            $inventory = New-TestPublishedEvidenceInventory -ReadError 'Access denied at a private path'

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceReadUnavailable'
            $assessment.MarkerHashVerification | Should -BeExactly 'ProbeUnavailable'
            $assessment.PSObject.Properties.Name | Should -Not -Contain 'ReadError'
        }

        It 'fails closed when filesystem length and bounded bytes disagree' {
            $inventory = New-TestPublishedEvidenceInventory -Length 999

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceLengthMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'fails closed when the authoritative server receipt time is missing' {
            $inventory = New-TestPublishedEvidenceInventory
            $inventory.Evidence.LastWriteTimeUtc = $null

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceReceiptUnavailable'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }

        It 'never accepts evidence when the target and owner SID are unresolved' {
            $inventory = New-TestPublishedEvidenceInventory `
                -TargetComputerSid '' -OwnerSid ''

            $assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
                -Contract (Get-SetupCmMarkerFixedContract) `
                -Inventory $inventory `
                -NowUtc ([datetime]'2026-08-30T12:10:00Z')

            $assessment.State | Should -BeExactly 'Conflict'
            $assessment.Reason | Should -BeExactly 'EvidenceOwnerMismatch'
            $assessment.MarkerHashVerification | Should -BeExactly 'EvidenceConflict'
        }
    }
}
