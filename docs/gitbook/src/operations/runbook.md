# Operator Runbook

Use this runbook only after a provisioning layer has created an isolated,
domain-joined Windows Server and a separate test client. Read
[Overview & Quick Start](../getting-started/overview.md) and
[Configuration Reference](../configuration/reference.md) first.

> **Current LabZ1 note:** The accepted baseline is already installed. The
> five-stage release-candidate implementation is idempotent, but its reviewed
> two-run live acceptance is still pending. Until that gate starts, use the
> read-only restart command below and
> [Current LabZ1 Status](./current-status.md).

## Required boundary

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

1. Install PowerShell 7.0 or later for SetupCm operations, plus Git for
   Windows and `powershell-yaml`. Use PowerShell 7.4 or later on any host that
   will run the Pester 6 test suite:

   ```powershell
   Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser
   Install-Module Pester -RequiredVersion 6.0.0 -Scope CurrentUser
   ```

   PowerShell 7.0 is the deliberate minimum. `ProcessStartInfo.ArgumentList`
   is available in .NET Core 3.1, the archive verifier writes bytes directly to
   the child process stream, and acquisition uses the compatible `TimeoutSec`
   on PowerShell 7.0-7.3 before switching to split timeouts on 7.4 and later.
   The pinned Pester 6.0.0 test dependency requires PowerShell 7.4 or later on
   PowerShell Core. Pester also supports Windows PowerShell 5.1, but this
   repository imports the PowerShell 7-only SetupCm module; its manifest value
   does not imply Pester support for Core 7.0-7.3.

2. On the review host, create and hash a source archive from one exact commit:

   ```powershell
   $sourceCommit = (git rev-parse HEAD).Trim()
   if ($sourceCommit -notmatch '\A[0-9a-f]{40}\z') { throw 'Commit is not exact.' }
   $archive = "setup-cm-$sourceCommit.tar"
   git archive --format=tar --output=$archive $sourceCommit
   Get-FileHash -LiteralPath $archive -Algorithm SHA256
   ```

   Stage that archive on CM01 and verify its byte hash before extraction. Do
   not add generated or private files to it.
3. Stage the non-template configuration separately at a protected path such as
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
   $configAcl.SetOwner($operatorSid)
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
   $verifiedOwnerSid = $verifiedAcl.GetOwner(
       [System.Security.Principal.SecurityIdentifier]
   ).Value
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
   if ($verifiedOwnerSid -ne $operatorSid.Value -or
       -not $verifiedAcl.AreAccessRulesProtected -or
       $invalidRules.Count -gt 0 -or
       @(Compare-Object -ReferenceObject $expectedSids -DifferenceObject $actualSids).Count -gt 0) {
       throw 'Private configuration ACL verification failed.'
   }
   ```
4. Confirm the approved SQL, MECM, ADK, Windows PE, ODBC, and x64/x86 VC++
   artifacts are present in the configured cache or available through the
   approved source policy.
5. Set the private path and exact archive commit recorded on the review host:

   ```powershell
   $env:SETUPCM_CONFIG = 'C:\ProgramData\SetupCm\config\lab.local.yaml'
   $env:SETUPCM_SOURCE_COMMIT = '<FULL_40_CHARACTER_GIT_COMMIT>'
   if ($env:SETUPCM_SOURCE_COMMIT -notmatch '\A[0-9a-fA-F]{40}\z') {
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
    $env:SETUPCM_SOURCE_COMMIT -notmatch '\A[0-9a-fA-F]{40}\z') {
    throw 'SETUPCM_SOURCE_COMMIT must identify the exact staged commit.'
}
$archivePath = Join-Path 'C:\ProgramData\SetupCm\staging' `
  "setup-cm-$($env:SETUPCM_SOURCE_COMMIT).tar"
$expectedArchiveHash = '<RECORDED_64_CHARACTER_SHA256>'
if ($expectedArchiveHash -notmatch '\A[0-9a-fA-F]{64}\z') {
    throw 'The recorded archive SHA-256 is missing or invalid.'
}
$actualArchiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
if ($actualArchiveHash -ine $expectedArchiveHash) {
    throw 'The staged source archive hash does not match the reviewed archive.'
}

$git = Get-Command git.exe -ErrorAction Stop
# This writes bytes directly to the child process stream and does not depend on
# the native byte-pipeline behavior added after PowerShell 7.0.
$archiveHeader = [byte[]]::new(1024)
$archiveStream = [IO.File]::OpenRead($archivePath)
try {
    $offset = 0
    while ($offset -lt $archiveHeader.Length) {
        $bytesRead = $archiveStream.Read(
            $archiveHeader,
            $offset,
            $archiveHeader.Length - $offset
        )
        if ($bytesRead -eq 0) { throw 'The staged source archive has no complete tar header.' }
        $offset += $bytesRead
    }
}
finally {
    $archiveStream.Dispose()
}
$gitStartInfo = [Diagnostics.ProcessStartInfo]::new()
$gitStartInfo.FileName = $git.Source
$gitStartInfo.ArgumentList.Add('get-tar-commit-id')
$gitStartInfo.UseShellExecute = $false
$gitStartInfo.RedirectStandardInput = $true
$gitStartInfo.RedirectStandardOutput = $true
$gitStartInfo.RedirectStandardError = $true
$gitProcess = [Diagnostics.Process]::new()
$gitProcess.StartInfo = $gitStartInfo
try {
    if (-not $gitProcess.Start()) { throw 'Git archive identity verifier did not start.' }
    $gitProcess.StandardInput.BaseStream.Write($archiveHeader, 0, $archiveHeader.Length)
    $gitProcess.StandardInput.Close()
    $embeddedArchiveCommit = $gitProcess.StandardOutput.ReadToEnd().Trim()
    $gitError = $gitProcess.StandardError.ReadToEnd().Trim()
    $gitProcess.WaitForExit()
    if ($gitProcess.ExitCode -ne 0) {
        throw "The staged archive has no readable git commit identity: $gitError"
    }
}
finally {
    $gitProcess.Dispose()
}
if ($embeddedArchiveCommit -notmatch '\A[0-9a-fA-F]{40}\z' -or
    $embeddedArchiveCommit -ine $env:SETUPCM_SOURCE_COMMIT) {
    throw 'The commit embedded in the staged archive does not match SETUPCM_SOURCE_COMMIT.'
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

Continue only when `Ready` is `True`.

## Read-only accepted-lab restart

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -Mode Unattended `
  -Stage Health
```

Health reads SQL, MECM, MP, DP, and active-client state, writes a fresh
`health.json`, and has no repair action.

## Run the complete workflow

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -Mode Unattended `
  -Stage Acquire,Sql,Mecm,Marker,Health `
  -SourceCommit $env:SETUPCM_SOURCE_COMMIT
```

When marker acceptance is enabled, lab-only, fixed to the validated LabZ1
identities, and supplied a full source commit, omitting `-Stage` selects the
same five stages in that order. A marker-disabled configuration omits Marker;
an enabled marker configuration without the commit fails before stage
execution. Keep `-Stage` explicit for release acceptance and recovery evidence.

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

## Operate the authenticated marker evidence channel

Run live SQL, SMS provider, and Marker acceptance from CM01 as the authorized
domain operator in an elevated PowerShell session. A successful SSH connection
as CM01's local Administrator is not an equivalent acceptance context because
that identity may not have site-database or secured-provider access.

The Marker channel is fixed in code:

| Item | Exact contract |
| --- | --- |
| Hidden share | `SetupCmMarkerEvidence$` on `LABZ1-CM01.test.gell.one` |
| Local target | `C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01` |
| Final file | `marker-evidence.json`, maximum 2,048 bytes |
| Only client writer | `TEST\RING0IVY24-01$` |
| Schema | Six exact fields, version `1`, ASCII-compatible JSON |
| Freshness | 30 minutes, with at most two minutes of future clock tolerance |

The provider first attempts an authenticated direct `C$` marker read. A
successful read is authoritative. Only when that transport is unavailable does
it accept the locally received, target-computer-owned evidence file through the
`DirectAuthenticatedClientEvidence` route. Missing or stale otherwise valid
evidence is repairable pending state. Malformed, foreign-owned, future-dated,
wrong-identity, wrong-path, wrong-hash, or contradictory evidence is a conflict.

On the accepted pre-migration LabZ1 state, the only permitted first-run actions
are, in order:

1. Create or safely complete the exact protected directory and hidden share.
2. Replace only the exact approved predecessor detector through
   `Set-CMScriptDeploymentType`; do not alter content or runtime properties.
3. Wait up to five minutes for the current application and assignment policy
   revisions/scope to agree and remain observed unchanged for 60 seconds.
   Request machine policy once, wait a 30-second processing interval, then request
   application evaluation once.
4. Poll read-only state every 15 seconds for up to 15 minutes.

Each publication snapshot runs in a disposable read-only PowerShell process
bounded by the lesser of 90 seconds and the time remaining in that one
five-minute deadline; a hung ConfigMgr/CIM query is terminated and fails the
run before notification. The publication wait also fails before notification
if assignment scope or object cardinality changes. The UTC timestamp captured
immediately after the one machine-policy request completes becomes the minimum
acceptable CM01 receipt time. The 30-second interval is sequencing margin, not evidence of
client policy receipt; only authenticated detector evidence and matching
current client/server revision can complete convergence. Conflict stops
immediately. Timeout fails with the final component state and does not make a
second mutation attempt. Detector-only migration must not copy
content, redistribute the application, recreate objects, change membership, or
replace the assignment.

Run the identical five-stage command immediately afterward, while the first
record is still fresh. That release-acceptance second run must call no mutation
or side-effect adapter, including no policy/evaluation request, and all five
stages must be `Skipped`. A later routine run after the 30-minute freshness
window may make one bounded policy/evaluation request and wait for refreshed
evidence; that later refresh is not the v1 zero-action second-run proof and must
still cause no infrastructure or ConfigMgr object churn.

For a read-only provider gate, use a fresh PowerShell process and select the
state expected at that point:

```powershell
$env:SETUPCM_LAB_PROVIDER_INTEGRATION = '1'
$env:SETUPCM_MARKER_PROVIDER_MODE = 'PreMigration' # or PostMigration
Invoke-Pester ./tests/Integration/MarkerAcceptance.Provider.Tests.ps1 `
  -Output Detailed -CI
```

`PreMigration` requires exactly the three repairable states listed above.
`PostMigration` requires every component compliant and installs throwing
adapters for every mutation and side effect, so any attempted action fails the
test.

## Understand stage behavior

| Probe result | Behavior |
| --- | --- |
| `Compliant` | Write a `Skipped` stage result. Do not call Apply. |
| `NotCompliant` | Repair only owned missing state, verify independently, then write `Succeeded`. |
| `Conflict` | Write `Failed` and stop before mutation. |
| Verification not `Compliant` | Write `Failed` even when Apply returned successfully. |

`Acquire` reacquires only invalid artifacts. `Sql` and `Mecm` repair only
owned missing components and do not reinstall an exact instance or site.
`Marker` reuses exact objects and changes only its fixed deployment chain.
`Health` is always read-only. See [Stages & Evidence](./stages-and-evidence.md)
for component detail.

## Inspect evidence

A complete run directory contains `run.json`, one `stage-<name>.json` per
stage, and the component artifacts `acquire-state.json`, `sql-state.json`,
`mecm-state.json`, `marker-state.json`, and `health.json`.
`acquisition.json` appears only when Acquire Apply ran; it includes every
evaluated artifact, distinguishing reused `Verified` entries from newly
acquired `AcquiredAndVerified` entries.

Evidence omits source URIs, vault paths, credentials, tokens, private keys, raw
policies, and raw log bodies. Before accepting a run, independently compare
the marker collection and assignment with the exact client marker hash and
installed application state. See [Evidence Format](../reference/evidence-format.md).

## Resume or stop

1. Preserve the failed run directory.
2. Read `stage-<name>.json` and its component-state artifact.
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

Stop when identity is inconsistent, state is ambiguous, or repair would
require reset, reinstall, authentication weakening, trust changes, broader
targeting, historical-object deletion, or unavailable media/credentials. See
[Recovery & Resume](./recovery.md).

## Validate the source

```powershell
Invoke-Pester ./tests/Unit -Output Detailed -CI
./scripts/Test-MarkdownLinks.ps1
mdbook build ./docs/gitbook
```

Run Windows detector, core-stage, and provider integration suites on the
accepted CM01 host. They are intentionally excluded from portable CI.
