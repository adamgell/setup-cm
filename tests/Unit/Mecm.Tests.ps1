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
