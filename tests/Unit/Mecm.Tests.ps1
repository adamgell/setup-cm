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
