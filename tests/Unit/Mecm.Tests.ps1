Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'New-SetupCmPrimarySiteScript' {
    InModuleScope SetupCm {
        It 'generates a current-branch standalone-primary answer file' {
            $script = New-SetupCmPrimarySiteScript -Mecm @{
                siteCode = 'LAB'; siteName = 'Lab Primary'; sqlServer = 'CM01.lab.example'
                smsInstallDir = 'D:\ConfigMgr'; prerequisitePath = 'D:\Sources\Redist';
                siteServerFqdn = 'CM01.lab.example'; productId = 'Eval'
            }

            $script | Should -Match '\[Identification\]'
            $script | Should -Match 'Action=InstallPrimarySite'
            $script | Should -Match 'SiteCode=LAB'
            $script | Should -Match 'SQLServerName=CM01.lab.example'
            $script | Should -Match 'PrerequisiteComp=1'
            $script | Should -Match 'ManagementPoint=CM01.lab.example'
            $script | Should -Match 'DistributionPoint=CM01.lab.example'
        }
    }
}

Describe 'Get-SetupCmMecmPrerequisites' {
    InModuleScope SetupCm {
        It 'runs the media Setup Downloader without a UI into the configured prerequisite folder' {
            $script:IsWindows = $true
            Mock Get-SetupCmMediaRoot { $TestDrive }
            Mock Test-Path { $true }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
            $destination = Join-Path $TestDrive 'Prereqs'

            Get-SetupCmMecmPrerequisites -MediaPath 'C:\SetupCm\cache\mecm.iso' -PrerequisitePath $destination | Should -Be $destination

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq (Join-Path $TestDrive 'SMSSETUP\BIN\X64\Setupdl.exe') -and
                $ArgumentList -contains '/NOUI' -and
                $ArgumentList -contains $destination
            }
        }
    }
}

Describe 'Install-SetupCmMecmOdbcDriver18' {
    InModuleScope SetupCm {
        It 'installs a verified, license-accepted ODBC artifact silently' {
            $script:IsWindows = $true
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Path = 'C:\SetupCm\cache\msodbcsql18-x64.msi' }
            }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmMecmOdbcDriver18 -Source @{ name = 'odbcDriver18'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive

            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'msiexec.exe' -and
                $ArgumentList -contains '/qn' -and
                $ArgumentList -contains 'IACCEPTMSODBCSQLLICENSETERMS=YES' -and
                $ArgumentList -contains 'C:\SetupCm\cache\msodbcsql18-x64.msi'
            }
        }
    }
}

Describe 'Install-SetupCmMecmAdk' {
    InModuleScope SetupCm {
        It 'reports compliant when the matching Windows PE add-on is installed' {
            Test-SetupCmMecmWinPeAddOn -DirectoryProvider {
                param($Path)
                $Path -eq 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment'
            } | Should -Be 'Compliant'
        }

        It 'installs the verified Windows PE add-on silently' {
            $script:IsWindows = $true
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Path = 'C:\SetupCm\cache\adkwinpesetup.exe' }
            }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmMecmWinPeAddOn -Source @{ name = 'adkWinPe'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'C:\SetupCm\cache\adkwinpesetup.exe' -and
                $ArgumentList -contains '/quiet' -and
                $ArgumentList -contains '/norestart'
            }
        }

        It 'reports compliant only when both Deployment Tools and USMT are installed' {
            Test-SetupCmMecmAdk -DirectoryProvider {
                param($Path)
                $Path -in @(
                    'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools',
                    'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\User State Migration Tool'
                )
            } | Should -Be 'Compliant'
        }

        It 'installs only the MECM-required ADK Deployment Tools and USMT features' {
            $script:IsWindows = $true
            Mock Get-SetupCmArtifact {
                [pscustomobject]@{ Path = 'C:\SetupCm\cache\adksetup.exe' }
            }
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

            Install-SetupCmMecmAdk -Source @{ name = 'adk'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive

            Should -Invoke Get-SetupCmArtifact -Times 1 -Exactly
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'C:\SetupCm\cache\adksetup.exe' -and
                $ArgumentList -contains '/quiet' -and
                $ArgumentList -contains '/norestart' -and
                $ArgumentList -contains 'OptionId.DeploymentTools' -and
                $ArgumentList -contains 'OptionId.UserStateMigrationTool'
            }
        }
    }
}

Describe 'MECM stage prerequisites' {
    InModuleScope SetupCm {
        It 'installs the approved ADK before downloading MECM prerequisites' {
            $config = @{
                cacheRoot = 'C:\SetupCm\cache'
                evidenceRoot = $TestDrive
                mecm = @{ prerequisitePath = 'C:\SetupCm\prereqs' }
                sources = @{
                    mecm = @{ name = 'mecm' }
                    adk = @{ name = 'adk'; licenseAccepted = $true }
                    adkWinPe = @{ name = 'adkWinPe'; licenseAccepted = $true }
                    odbcDriver18 = @{ name = 'odbcDriver18'; licenseAccepted = $true }
                }
            }
            Mock Read-SetupCmConfig { $config }
            Mock New-SetupCmRunEvidence { $TestDrive }
            Mock Invoke-SetupCmStage {
                param($Name, $Test, $Apply, $Verify, $EvidenceRoot)
                & $Apply
                & $Verify
                [pscustomobject]@{ name = $Name; state = 'Succeeded' }
            }
            Mock Get-SetupCmArtifact { [pscustomobject]@{ Path = 'C:\SetupCm\cache\mecm.iso' } }
            Mock Test-SetupCmMecmAdk { 'NotCompliant' }
            Mock Install-SetupCmMecmAdk {}
            Mock Test-SetupCmMecmWinPeAddOn { 'NotCompliant' }
            Mock Install-SetupCmMecmWinPeAddOn {}
            Mock Test-SetupCmMecmOdbcDriver18 { 'Compliant' }
            Mock Get-SetupCmMecmPrerequisites {}
            Mock Install-SetupCmPrimarySite {}

            Invoke-SetupCm -ConfigPath 'lab.yaml' -Mode Unattended -Stage Mecm | Out-Null

            Should -Invoke Install-SetupCmMecmAdk -Times 1 -Exactly -ParameterFilter {
                $Source.name -eq 'adk' -and $CacheRoot -eq 'C:\SetupCm\cache'
            }
            Should -Invoke Install-SetupCmMecmWinPeAddOn -Times 1 -Exactly -ParameterFilter {
                $Source.name -eq 'adkWinPe' -and $CacheRoot -eq 'C:\SetupCm\cache'
            }
            Should -Invoke Get-SetupCmMecmPrerequisites -Times 1 -Exactly
        }
    }
}
