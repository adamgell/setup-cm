Describe 'Setup-CM Phase 1 marker payload' {
    BeforeAll {
        $installScript = Join-Path $PSScriptRoot '../../scripts/marker/Install-SetupCmPhase1Marker.ps1'
        $detectScript = Join-Path $PSScriptRoot '../../scripts/marker/Test-SetupCmPhase1Marker.ps1'
        $uninstallScript = Join-Path $PSScriptRoot '../../scripts/marker/Uninstall-SetupCmPhase1Marker.ps1'
        $expectedContent = '{"application":"Setup-CM Phase 1 Marker","version":"1.0.0","scope":"lab-only"}'
        $expectedHash = '3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254'
    }

    BeforeEach {
        $markerRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $markerPath = Join-Path $markerRoot 'marker.json'
    }

    It 'installs the exact no-newline marker bytes used by hash detection' {
        & $installScript -MarkerRoot $markerRoot

        [System.IO.File]::ReadAllText($markerPath) | Should -BeExactly $expectedContent
        (Get-FileHash -LiteralPath $markerPath -Algorithm SHA256).Hash | Should -BeExactly $expectedHash
    }

    It 'repairs a tampered marker and then detects it as installed' {
        New-Item -ItemType Directory -Path $markerRoot -Force | Out-Null
        [System.IO.File]::WriteAllText($markerPath, 'tampered')

        (& $detectScript -MarkerRoot $markerRoot) | Should -BeNullOrEmpty
        & $installScript -MarkerRoot $markerRoot
        (& $detectScript -MarkerRoot $markerRoot) | Should -BeExactly 'Installed'
    }

    It 'does not detect a missing marker as installed' {
        (& $detectScript -MarkerRoot $markerRoot) | Should -BeNullOrEmpty
    }

    It 'uninstalls only marker.json and preserves unrelated files' {
        & $installScript -MarkerRoot $markerRoot
        $unrelatedPath = Join-Path $markerRoot 'keep.txt'
        Set-Content -LiteralPath $unrelatedPath -Value 'keep' -NoNewline

        & $uninstallScript -MarkerRoot $markerRoot

        Test-Path -LiteralPath $markerPath | Should -BeFalse
        Test-Path -LiteralPath $unrelatedPath | Should -BeTrue
        (Get-Content -LiteralPath $unrelatedPath -Raw) | Should -BeExactly 'keep'
    }

    It 'removes the marker directory when it is empty after uninstall' {
        & $installScript -MarkerRoot $markerRoot

        & $uninstallScript -MarkerRoot $markerRoot

        Test-Path -LiteralPath $markerRoot | Should -BeFalse
    }
}
