# SetupCm runbook

Use this runbook only after a provisioning layer has created an isolated,
domain-joined Windows Server and a separate test client. Read the
[project overview](../README.md) and [configuration reference](CONFIGURATION.md)
first.

> [!IMPORTANT]
> The accepted LabZ1 baseline is already installed. The five-stage
> release-candidate implementation is idempotent, but its reviewed two-run live
> acceptance is still pending. Until that gate starts, use the read-only
> restart command below and the accepted
> [Phase 0 record](PHASE0-2026-08-29-LAB-INVENTORY.md).

## Required boundary

The v1 workflow supports one topology:

| Role | Required identity |
| --- | --- |
| Server, provider, MP, and DP | `LABZ1-CM01.test.gell.one` |
| Site and database | `LAB` / `CM_LAB` |
| Only marker target | `RING0IVY24-01.test.gell.one`, resource `16777219` |
| Marker application | `Setup-CM Phase 1 Marker` |

Marker acceptance must be explicitly enabled and lab-only. A different host,
site, resource, same-name object, collection rule, member, or assignment is a
conflict and stops before mutation. Production, additional clients, broad
collections, VM lifecycle, trust changes, and client-wide policy changes are
outside this runbook.

## Prepare the server

1. Install PowerShell 7, `powershell-yaml`, and Pester 6:

   ```powershell
   Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser
   Install-Module Pester -RequiredVersion 6.0.0 -Scope CurrentUser
   ```

2. On the review host, create and hash a source archive from one exact commit:

   ```powershell
   $sourceCommit = (git rev-parse HEAD).Trim()
   if ($sourceCommit -notmatch '^[0-9a-f]{40}$') { throw 'Commit is not exact.' }
   $archive = "setup-cm-$sourceCommit.tar"
   git archive --format=tar --output=$archive $sourceCommit
   Get-FileHash -LiteralPath $archive -Algorithm SHA256
   ```

   Stage that archive on CM01 and verify its byte hash before extraction. Do
   not add generated or private files to it.
3. Stage the non-template configuration separately, for example at
   `C:\ProgramData\SetupCm\config\lab.local.yaml`. Never commit or copy it into
   evidence. From the SetupCm operator account in an elevated PowerShell
   session, replace inherited access with read-and-execute access for exactly
   that operator, Local System, and local Administrators, then verify the ACL:

   ```powershell
   $configPath = 'C:\ProgramData\SetupCm\config\lab.local.yaml'
   if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
       throw "Private configuration does not exist: $configPath"
   }
   $operatorSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
   $allowedSids = @(
       [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
       [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
       $operatorSid
   )
   $configAcl = Get-Acl -LiteralPath $configPath
   $configAcl.SetAccessRuleProtection($true, $false)
   foreach ($identity in @($configAcl.Access.IdentityReference | Sort-Object Value -Unique)) {
       $configAcl.PurgeAccessRules($identity)
   }
   foreach ($sid in $allowedSids) {
       $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
           $sid,
           [System.Security.AccessControl.FileSystemRights]::ReadAndExecute,
           [System.Security.AccessControl.AccessControlType]::Allow
       )
       $configAcl.AddAccessRule($rule) | Out-Null
   }
   Set-Acl -LiteralPath $configPath -AclObject $configAcl

   $verifiedAcl = Get-Acl -LiteralPath $configPath
   $verifiedRules = @($verifiedAcl.Access)
   $expectedSids = @($allowedSids | ForEach-Object Value | Sort-Object -Unique)
   $actualSids = @($verifiedRules | ForEach-Object {
       $_.IdentityReference.Translate(
           [System.Security.Principal.SecurityIdentifier]
       ).Value
   } | Sort-Object -Unique)
   $readExecuteMask = [int][System.Security.AccessControl.FileSystemRights]::ReadAndExecute
   $writeMask = [int](
       [System.Security.AccessControl.FileSystemRights]::WriteData -bor
       [System.Security.AccessControl.FileSystemRights]::AppendData -bor
       [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
       [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
       [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
       [System.Security.AccessControl.FileSystemRights]::Delete -bor
       [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
       [System.Security.AccessControl.FileSystemRights]::TakeOwnership
   )
   $invalidRules = @($verifiedRules | Where-Object {
       $rights = [int]$_.FileSystemRights
       $_.IsInherited -or
           $_.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
           ($rights -band $readExecuteMask) -ne $readExecuteMask -or
           ($rights -band $writeMask) -ne 0
   })
   if (-not $verifiedAcl.AreAccessRulesProtected -or
       $verifiedRules.Count -ne $expectedSids.Count -or
       $invalidRules.Count -gt 0 -or
       @(Compare-Object -ReferenceObject $expectedSids -DifferenceObject $actualSids).Count -gt 0) {
       throw 'Private configuration ACL verification failed.'
   }
   ```
4. Confirm the approved SQL, MECM, ADK, Windows PE, ODBC, and x64/x86 VC++
   artifacts are present in the configured cache or available through the
   approved source policy.
5. Set the private path and the exact archive commit recorded on the review
   host:

   ```powershell
   $env:SETUPCM_CONFIG = 'C:\ProgramData\SetupCm\config\lab.local.yaml'
   $env:SETUPCM_SOURCE_COMMIT = '<FULL_40_CHARACTER_GIT_COMMIT>'
   if ($env:SETUPCM_SOURCE_COMMIT -notmatch '^[0-9a-fA-F]{40}$') {
       throw 'SETUPCM_SOURCE_COMMIT must identify the exact staged commit.'
   }
   ```

Any run containing `Marker` rejects a missing or abbreviated source commit.

## Extract and enter the reviewed source

On CM01, bind the staged archive to the exact commit and SHA-256 recorded on
the review host, extract it into a new commit-specific directory, and verify
the expected source layout before using any relative command:

```powershell
if ([string]::IsNullOrWhiteSpace($env:SETUPCM_SOURCE_COMMIT) -or
    $env:SETUPCM_SOURCE_COMMIT -notmatch '^[0-9a-fA-F]{40}$') {
    throw 'SETUPCM_SOURCE_COMMIT must identify the exact staged commit.'
}
$archivePath = Join-Path 'C:\ProgramData\SetupCm\staging' `
  "setup-cm-$($env:SETUPCM_SOURCE_COMMIT).tar"
$expectedArchiveHash = '<RECORDED_64_CHARACTER_SHA256>'
if ($expectedArchiveHash -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'The recorded archive SHA-256 is missing or invalid.'
}
$actualArchiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
if ($actualArchiveHash -ine $expectedArchiveHash) {
    throw 'The staged source archive hash does not match the reviewed archive.'
}

$sourceRoot = Join-Path 'C:\ProgramData\SetupCm\source' $env:SETUPCM_SOURCE_COMMIT
if (Test-Path -LiteralPath $sourceRoot) {
    throw "The commit-specific source directory already exists: $sourceRoot"
}
$sourceParent = Split-Path -Parent $sourceRoot
$temporarySourceRoot = "$sourceRoot.partial-$PID"
if (Test-Path -LiteralPath $temporarySourceRoot) {
    throw "The temporary source directory already exists: $temporarySourceRoot"
}
New-Item -ItemType Directory -Path $sourceParent -Force | Out-Null
New-Item -ItemType Directory -Path $temporarySourceRoot | Out-Null
$requiredSourcePaths = @(
    './src/SetupCm/SetupCm.psd1'
    './scripts/Invoke-SetupCm.ps1'
    './tests/Unit'
    './docs/gitbook/book.toml'
)
try {
    tar.exe -xf $archivePath -C $temporarySourceRoot
    if ($LASTEXITCODE -ne 0) { throw 'Source archive extraction failed.' }
    $missingSourcePaths = @($requiredSourcePaths | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $temporarySourceRoot $_))
    })
    if ($missingSourcePaths.Count -gt 0) {
        throw "The extracted source root is incomplete: $($missingSourcePaths -join ', ')"
    }
    Move-Item -LiteralPath $temporarySourceRoot -Destination $sourceRoot
}
catch {
    Remove-Item -LiteralPath $temporarySourceRoot -Recurse -Force -ErrorAction SilentlyContinue
    throw
}
Set-Location -LiteralPath $sourceRoot
```

## Run preflight

```powershell
Import-Module ./src/SetupCm/SetupCm.psd1 -Force
Test-SetupCmPreflight -ConfigPath $env:SETUPCM_CONFIG
```

Continue only when `Ready` is `True`. Resolve each item in `Missing` by
correcting the private configuration or approved artifact source.

## Read-only accepted-lab restart

Use this command to refresh current Health evidence without invoking an
installer or marker reconciliation:

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -Mode Unattended `
  -Stage Health
```

Health reads SQL, MECM, MP, DP, and active-client state, writes a fresh
`health.json`, and has no repair action.

## Run the complete workflow

From the staged source root, run:

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -Mode Unattended `
  -Stage Acquire,Sql,Mecm,Marker,Health `
  -SourceCommit $env:SETUPCM_SOURCE_COMMIT
```

When `markerAcceptance.enabled: true`, omitting `-Stage` selects the same
five stages in that order. Keep `-Stage` explicit for release acceptance and
recovery evidence.

The first accepted run may repair only proven missing state. Run the identical
command from the identical commit a second time. The second run must report all
five stages `Skipped`, execute no installer, redistribute no content, and
create no ConfigMgr object, assignment, or membership rule.

To evaluate only the bounded marker feature:

```powershell
pwsh ./scripts/Invoke-SetupCmMarkerAcceptance.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -SourceCommit $env:SETUPCM_SOURCE_COMMIT
```

## Understand stage behavior

Each stage follows the same contract:

| Probe result | Behavior |
| --- | --- |
| `Compliant` | Write a `Skipped` stage result. Do not call Apply. |
| `NotCompliant` | Repair only owned missing state, verify independently, then write `Succeeded`. |
| `Conflict` | Write `Failed` and stop before mutation. |
| Verification not `Compliant` | Write `Failed` even when Apply returned successfully. |

`Acquire` reacquires only invalid artifacts. `Sql` and `Mecm` repair only
owned missing components and do not reinstall an exact instance or site.
`Marker` reuses exact objects and changes only its fixed deployment chain.
`Health` is always read-only.

## Inspect evidence

Each invocation creates a unique directory under `evidenceRoot`. Preserve the
whole directory. A complete run contains:

- `run.json` with run ID, start time, and exact source commit;
- `stage-Acquire.json`, `stage-Sql.json`, `stage-Mecm.json`,
  `stage-Marker.json`, and `stage-Health.json`;
- `acquire-state.json`, `sql-state.json`, `mecm-state.json`,
  `marker-state.json`, and `health.json`;
- `acquisition.json` only when Acquire Apply ran; it includes every evaluated
  artifact, distinguishing reused `Verified` entries from newly acquired
  `AcquiredAndVerified` entries.

Evidence omits source URIs, vault paths, credentials, tokens, private keys, raw
policies, and raw log bodies. Before accepting a run, independently compare
the marker collection and assignment with the exact client marker hash and
installed application state.

## Resume a failed run

1. Preserve the failed evidence directory.
2. Read `stage-<name>.json` and the corresponding component-state artifact.
3. Correct only the proven prerequisite, source, or owned component.
4. Rerun the failed stage and only its later dependent stages from the same
   commit, preserving canonical relative order:

   | Failed stage | Rerun stages |
   | --- | --- |
   | `Acquire` | `Acquire,Sql,Mecm,Marker,Health` |
   | `Sql` | `Sql,Mecm,Marker,Health` |
   | `Mecm` | `Mecm,Marker,Health` |
   | `Marker` | `Marker,Health` |
   | `Health` | `Health` |

   The first four rows include `Marker` and therefore require the same exact
   `SourceCommit`; a `Health`-only recovery does not. For example, after a
   `Sql` failure:

   ```powershell
   pwsh ./scripts/Invoke-SetupCm.ps1 `
     -ConfigPath $env:SETUPCM_CONFIG `
     -Mode Unattended `
     -Stage Sql,Mecm,Marker,Health `
     -SourceCommit $env:SETUPCM_SOURCE_COMMIT
   ```

Stop instead of resuming when identity is inconsistent, state is ambiguous, or
repair would require reset, reinstall, authentication weakening, trust
changes, broader targeting, historical-object deletion, or media/credentials
that are not available.

## Validate the source

Before review or live acceptance:

```powershell
Invoke-Pester ./tests/Unit -Output Detailed -CI
./scripts/Test-MarkdownLinks.ps1
mdbook build ./docs/gitbook
```

Run the Windows-only detector, core-stage, and provider integration suites on
the accepted CM01 host. They are intentionally excluded from portable CI.
Optional capabilities are tracked as separate work in
[Future projects](FUTURE-PROJECTS.md).
