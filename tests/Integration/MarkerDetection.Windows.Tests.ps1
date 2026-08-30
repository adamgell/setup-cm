Describe 'Setup-CM Phase 1 VBScript marker detection' -Skip:(-not $IsWindows) {
    BeforeAll {
        $detectorPath = if ($env:SETUPCM_MARKER_DETECTOR_PATH) {
            $env:SETUPCM_MARKER_DETECTOR_PATH
        }
        else {
            Join-Path $PSScriptRoot '../../scripts/marker/Test-SetupCmPhase1Marker.vbs'
        }
        $expectedContent = '{"application":"Setup-CM Phase 1 Marker","version":"1.0.0","scope":"lab-only"}'
        $expectedHash = '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
        $productionEvidencePath = `
            '\\LABZ1-CM01.test.gell.one\SetupCmMarkerEvidence$\marker-evidence.json'

        function Invoke-MarkerDetector {
            param(
                [Parameter(Mandatory)][string]$MarkerRoot,
                [string]$EvidencePath,
                [string[]]$AdditionalArguments = @()
            )

            $detectorArguments = @($MarkerRoot)
            if ($PSBoundParameters.ContainsKey('EvidencePath')) {
                $detectorArguments += $EvidencePath
            }
            $detectorArguments += $AdditionalArguments
            $output = & "$env:SystemRoot\System32\cscript.exe" `
                //NoLogo $detectorPath @detectorArguments 2>&1
            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output = ($output -join "`n").Trim()
            }
        }

        function Get-ProductionEvidenceFingerprint {
            if (-not (Test-Path -LiteralPath $productionEvidencePath `
                    -PathType Leaf -ErrorAction SilentlyContinue)) {
                return 'Absent'
            }
            $item = Get-Item -LiteralPath $productionEvidencePath -ErrorAction Stop
            $hash = (Get-FileHash -LiteralPath $productionEvidencePath `
                    -Algorithm SHA256 -ErrorAction Stop).Hash
            '{0}|{1}|{2}' -f $item.Length, $item.LastWriteTimeUtc.ToString('o'), $hash
        }
    }

    BeforeEach {
        $markerRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $markerPath = Join-Path $markerRoot 'marker.json'
    }

    It 'detects only the exact SHA-256 marker bytes' {
        New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
        [System.IO.File]::WriteAllText($markerPath, $expectedContent, [System.Text.UTF8Encoding]::new($false))

        $result = Invoke-MarkerDetector -MarkerRoot $markerRoot

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeExactly 'Installed'
    }

    It 'does not detect a tampered marker as installed' {
        New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
        [System.IO.File]::WriteAllText($markerPath, 'tampered')

        $result = Invoke-MarkerDetector -MarkerRoot $markerRoot

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeNullOrEmpty
    }

    It 'does not treat the expected hash in the marker path as the file hash' {
        $markerRoot = Join-Path $TestDrive "marker-$expectedHash"
        $markerPath = Join-Path $markerRoot 'marker.json'
        New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
        [System.IO.File]::WriteAllText($markerPath, 'tampered')

        $result = Invoke-MarkerDetector -MarkerRoot $markerRoot

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeNullOrEmpty
    }

    It 'does not detect a missing marker as installed' {
        $result = Invoke-MarkerDetector -MarkerRoot $markerRoot

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeNullOrEmpty
    }

    It 'returns no installed output when more than two arguments are supplied' {
        New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
        [System.IO.File]::WriteAllText(
            $markerPath,
            $expectedContent,
            [System.Text.UTF8Encoding]::new($false)
        )
        $evidencePath = Join-Path $TestDrive 'unexpected-evidence.json'

        $result = Invoke-MarkerDetector -MarkerRoot $markerRoot `
            -EvidencePath $evidencePath -AdditionalArguments 'unexpected'

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeNullOrEmpty
        Test-Path -LiteralPath $evidencePath | Should -BeFalse
    }

    Context 'authenticated evidence publication' `
        -Skip:($env:COMPUTERNAME -ine 'RING0IVY24-01') {
        It 'publishes the exact complete six-field record after an exact hash' {
            New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
            [System.IO.File]::WriteAllText(
                $markerPath,
                $expectedContent,
                [System.Text.UTF8Encoding]::new($false)
            )
            $evidenceDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $evidenceDirectory | Out-Null
            $evidencePath = Join-Path $evidenceDirectory 'marker-evidence.json'
            [System.IO.File]::WriteAllText($evidencePath, '{"stale":true}')

            $result = Invoke-MarkerDetector `
                -MarkerRoot $markerRoot -EvidencePath $evidencePath

            $result.ExitCode | Should -Be 0
            $result.Output | Should -BeExactly 'Installed'
            $bytes = [System.IO.File]::ReadAllBytes($evidencePath)
            $bytes.Count | Should -BeLessOrEqual 2048
            @($bytes | Where-Object { $_ -gt 0x7f }).Count | Should -Be 0
            $record = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes) |
                ConvertFrom-Json
            $record.PSObject.Properties.Name | Should -BeExactly @(
                'schemaVersion',
                'computerName',
                'markerPath',
                'markerSha256',
                'markerLength',
                'verificationMethod'
            )
            $record.schemaVersion | Should -Be 1
            $record.computerName | Should -BeExactly 'RING0IVY24-01'
            $record.markerPath | Should -BeExactly `
                'C:\ProgramData\SetupCm\Phase1\marker.json'
            $record.markerSha256 | Should -BeExactly $expectedHash
            $record.markerLength | Should -Be 78
            $record.verificationMethod | Should -BeExactly 'CertUtilSha256Exact'
            @(Get-ChildItem -LiteralPath $evidenceDirectory -File).Name |
                Should -BeExactly 'marker-evidence.json'
        }

        It 'does not publish evidence for a tampered marker' {
            New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
            [System.IO.File]::WriteAllText($markerPath, 'tampered')
            $evidencePath = Join-Path $TestDrive 'tampered-evidence.json'

            $result = Invoke-MarkerDetector `
                -MarkerRoot $markerRoot -EvidencePath $evidencePath

            $result.ExitCode | Should -Be 0
            $result.Output | Should -BeNullOrEmpty
            Test-Path -LiteralPath $evidencePath | Should -BeFalse
        }

        It 'does not publish evidence for a missing marker' {
            $evidencePath = Join-Path $TestDrive 'missing-evidence.json'

            $result = Invoke-MarkerDetector `
                -MarkerRoot $markerRoot -EvidencePath $evidencePath

            $result.ExitCode | Should -Be 0
            $result.Output | Should -BeNullOrEmpty
            Test-Path -LiteralPath $evidencePath | Should -BeFalse
        }

        It 'keeps exact detection installed when the evidence path is unavailable' {
            New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
            [System.IO.File]::WriteAllText(
                $markerPath,
                $expectedContent,
                [System.Text.UTF8Encoding]::new($false)
            )
            $blockedParent = Join-Path $TestDrive 'not-a-directory.txt'
            [System.IO.File]::WriteAllText($blockedParent, 'blocked')
            $evidencePath = Join-Path $blockedParent 'marker-evidence.json'

            $result = Invoke-MarkerDetector `
                -MarkerRoot $markerRoot -EvidencePath $evidencePath

            $result.ExitCode | Should -Be 0
            $result.Output | Should -BeExactly 'Installed'
            Test-Path -LiteralPath $evidencePath | Should -BeFalse
        }

        It 'does not touch the production evidence path in one-argument test mode' {
            New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
            [System.IO.File]::WriteAllText(
                $markerPath,
                $expectedContent,
                [System.Text.UTF8Encoding]::new($false)
            )
            $before = Get-ProductionEvidenceFingerprint

            $result = Invoke-MarkerDetector -MarkerRoot $markerRoot

            $result.Output | Should -BeExactly 'Installed'
            Get-ProductionEvidenceFingerprint | Should -BeExactly $before
        }
    }
}
