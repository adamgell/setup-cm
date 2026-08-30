Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force

Describe 'Setup-CM marker evidence channel Windows providers' -Skip:(-not $IsWindows) {
    InModuleScope SetupCm {
        It 'constructs only the exact protected parent and target ACL rules' {
            $targetSid = 'S-1-5-21-1-2-3-1001'

            $parent = Get-SetupCmMarkerDirectorySecurity `
                -Role Parent -TargetComputerSid $targetSid
            $target = Get-SetupCmMarkerDirectorySecurity `
                -Role Target -TargetComputerSid $targetSid

            $parent.AreAccessRulesProtected | Should -BeTrue
            $target.AreAccessRulesProtected | Should -BeTrue
            $parent.GetOwner([System.Security.Principal.SecurityIdentifier]).Value |
                Should -BeExactly 'S-1-5-32-544'
            $target.GetOwner([System.Security.Principal.SecurityIdentifier]).Value |
                Should -BeExactly 'S-1-5-32-544'
            $parentRules = @($parent.GetAccessRules(
                    $true,
                    $false,
                    [System.Security.Principal.SecurityIdentifier]
                ) | ForEach-Object { ConvertTo-SetupCmMarkerNtfsAce -AccessRule $_ })
            $targetRules = @($target.GetAccessRules(
                    $true,
                    $false,
                    [System.Security.Principal.SecurityIdentifier]
                ) | ForEach-Object { ConvertTo-SetupCmMarkerNtfsAce -AccessRule $_ })
            $inventory = [pscustomobject]@{
                AdministratorsSid = 'S-1-5-32-544'
                SystemSid = 'S-1-5-18'
                TargetComputerSid = $targetSid
            }
            Test-SetupCmMarkerAclEntriesExact -Actual $parentRules -Kind Ntfs `
                -Expected @(Get-SetupCmMarkerExpectedChannelAces `
                    -Inventory $inventory -Scope Parent) | Should -BeTrue
            Test-SetupCmMarkerAclEntriesExact -Actual $targetRules -Kind Ntfs `
                -Expected @(Get-SetupCmMarkerExpectedChannelAces `
                    -Inventory $inventory -Scope Target) | Should -BeTrue
        }

        It 'normalizes a protected temporary directory by SID and numeric masks' {
            $path = Join-Path $TestDrive 'protected-marker-evidence'
            New-Item -ItemType Directory -Path $path | Out-Null
            $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
            $security = [System.Security.AccessControl.DirectorySecurity]::new()
            $security.SetAccessRuleProtection($true, $false)
            $security.SetOwner($currentSid)
            $security.AddAccessRule(
                [System.Security.AccessControl.FileSystemAccessRule]::new(
                    $currentSid,
                    [System.Security.AccessControl.FileSystemRights]2032127,
                    [System.Security.AccessControl.InheritanceFlags]3,
                    [System.Security.AccessControl.PropagationFlags]0,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
            )
            Set-Acl -LiteralPath $path -AclObject $security

            $inventory = Get-SetupCmMarkerDirectoryInventory -Path $path

            $inventory.Exists | Should -BeTrue
            $inventory.IsDirectory | Should -BeTrue
            $inventory.IsReparsePoint | Should -BeFalse
            $inventory.OwnerSid | Should -BeExactly $currentSid.Value
            $inventory.AclProtected | Should -BeTrue
            $inventory.Aces.Count | Should -Be 1
            $inventory.Aces[0].Sid | Should -BeExactly $currentSid.Value
            $inventory.Aces[0].Rights | Should -Be 2032127
            $inventory.Aces[0].InheritanceFlags | Should -Be 3
            $inventory.Aces[0].PropagationFlags | Should -Be 0
            $inventory.Aces[0].AccessControlType | Should -Be 0
            $inventory.Aces[0].IsInherited | Should -BeFalse
        }

        It 'reads no more than one byte beyond the evidence limit' {
            $path = Join-Path $TestDrive 'oversized-evidence.json'
            [System.IO.File]::WriteAllBytes($path, [byte[]]::new(4096))

            $bytes = Read-SetupCmMarkerBoundedBytes -Path $path -MaximumBytes 2048

            $bytes.Count | Should -Be 2049
        }
    }
}
