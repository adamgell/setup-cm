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
            $script | Should -Match 'ManagementPoint=CM01.lab.example'
            $script | Should -Match 'DistributionPoint=CM01.lab.example'
        }
    }
}
