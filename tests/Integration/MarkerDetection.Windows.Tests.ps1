Describe 'Setup-CM Phase 1 VBScript marker detection' -Skip:(-not $IsWindows) {
    BeforeAll {
        $detectorPath = if ($env:SETUPCM_MARKER_DETECTOR_PATH) {
            $env:SETUPCM_MARKER_DETECTOR_PATH
        }
        else {
            Join-Path $PSScriptRoot '../../scripts/marker/Test-SetupCmPhase1Marker.vbs'
        }
        $expectedContent = '{"application":"Setup-CM Phase 1 Marker","version":"1.0.0","scope":"lab-only"}'

        function Invoke-MarkerDetector {
            param([Parameter(Mandatory)][string]$MarkerRoot)

            $output = & "$env:SystemRoot\System32\cscript.exe" //NoLogo $detectorPath $MarkerRoot 2>&1
            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output = ($output -join "`n").Trim()
            }
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

    It 'does not detect a missing marker as installed' {
        $result = Invoke-MarkerDetector -MarkerRoot $markerRoot

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeNullOrEmpty
    }
}
