# Authenticated Marker Client Evidence Channel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add authenticated, client-published marker evidence so the accepted
LabZ1 workflow can prove exact client bytes, converge once, and make the
immediate second full run a zero-action no-op.

**Architecture:** Keep the existing Marker stage and ConfigMgr object model,
but add a focused private module for strict evidence parsing, Windows share/ACL
state, and client-proof selection. Upgrade the known predecessor VBScript
detector in place so an exact marker publishes a bounded record outbound under
the target computer account; then reconcile the channel and policy without
redistributing unchanged content.

**Tech Stack:** PowerShell 7, Pester 6, VBScript/cscript, Windows SMB and NTFS
ACL APIs, ConfigurationManager PowerShell module, CIM/WMI, GitHub Actions,
mdBook.

**Spec:**
`docs/superpowers/specs/2026-08-30-marker-client-evidence-channel-design.md`

## Global Constraints

- Work only in `.worktrees/hands-off-rerun-v1` on
  `codex/hands-off-rerun-v1`; preserve the primary checkout and its untracked
  handoff byte-for-byte.
- Fix the boundary to site `LAB`, server `LABZ1-CM01.test.gell.one`, target
  `RING0IVY24-01.test.gell.one`, resource ID `16777219`, and computer account
  `TEST\RING0IVY24-01$`.
- Keep the marker path
  `C:\ProgramData\SetupCm\Phase1\marker.json`, length `78`, and SHA-256
  `3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254`.
- Use hidden share `SetupCmMarkerEvidence$`, share path
  `C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01`, and final file
  `marker-evidence.json`.
- Limit the record to 2,048 bytes, freshness to 30 minutes, future tolerance to
  two minutes, polling to 15 seconds, and convergence to 15 minutes.
- Do not change client firewall, trust, signing, execution policy, scheduled
  tasks, services, VM state, Proxmox Agent state, collection scope, or another
  repository.
- Never accept `ExactDetectorAndServerState` or another server projection as
  direct client evidence.
- The detector's installed result depends only on the exact local marker hash;
  evidence publication is best-effort and cannot create a false installed or
  absent result.
- Treat malformed/foreign evidence, broad or unknown ACLs, wrong share path,
  unknown detector hash, and identity drift as conflicts with zero mutation.
- Change the detector policy only from predecessor SHA-256
  `DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC`
  and length `1,310`.
- Every production behavior begins with a failing focused test. Run the focused
  test red, implement the minimum behavior, run it green, and commit each task.
- Use SSH, provider APIs, SQL, and the controller for live work. Do not use VNC
  or visual acceptance.

---

### Task 1: Strict published-evidence record

**Files:**

- Create: `src/SetupCm/Private/MarkerEvidenceChannel.ps1`
- Create: `tests/Unit/MarkerEvidenceChannel.Tests.ps1`
- Modify: `src/SetupCm/Private/MarkerApplication.ps1:6-45`

**Interfaces:**

- Consumes: `Get-SetupCmMarkerFixedContract` and the existing fixed marker
  identity.
- Produces:
  `ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes [byte[]]`, returning a
  six-property `PSCustomObject`, and
  `Get-SetupCmMarkerPublishedEvidenceAssessment -Contract [object]
  -Inventory [object] [-NowUtc [datetime]] [-MinimumReceiptUtc [datetime]]`,
  returning `State`, `Reason`, `MarkerHash`, `MarkerLength`,
  `MarkerHashVerification`, `ReceiptTimeUtc`, and `OwnerSid`.

- [x] **Step 1: Add the fixed evidence contract and write parser tests**

Extend `Get-SetupCmMarkerFixedContract` with this shape:

```powershell
MarkerLength = 78
PreviousDetectorFile = [ordered]@{
    Name = 'Test-SetupCmPhase1Marker.vbs'
    Length = 1310
    Hash = 'DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC'
}
EvidenceChannel = [ordered]@{
    ShareName = 'SetupCmMarkerEvidence$'
    ShareDescription = 'Setup-CM LabZ1 marker evidence for RING0IVY24-01'
    LocalParent = 'C:\ProgramData\SetupCm\MarkerEvidence'
    LocalPath = 'C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01'
    FileName = 'marker-evidence.json'
    UncPath = '\\LABZ1-CM01.test.gell.one\SetupCmMarkerEvidence$\marker-evidence.json'
    ComputerAccount = 'TEST\RING0IVY24-01$'
    SchemaVersion = 1
    VerificationMethod = 'CertUtilSha256Exact'
    MaximumBytes = 2048
    FreshnessMinutes = 30
    FutureToleranceMinutes = 2
    PollSeconds = 15
    ConvergenceSeconds = 900
}
```

In `MarkerEvidenceChannel.Tests.ps1`, construct the exact bytes and assert the
strict six-field result:

```powershell
$json = '{"schemaVersion":1,"computerName":"RING0IVY24-01","markerPath":"C:\\ProgramData\\SetupCm\\Phase1\\marker.json","markerSha256":"3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254","markerLength":78,"verificationMethod":"CertUtilSha256Exact"}'
$bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)
$record = ConvertFrom-SetupCmMarkerEvidenceJsonStrict -Bytes $bytes
$record.PSObject.Properties.Name | Should -BeExactly @(
    'schemaVersion', 'computerName', 'markerPath', 'markerSha256',
    'markerLength', 'verificationMethod'
)
$record.markerSha256 | Should -BeExactly (Get-SetupCmMarkerFixedContract).MarkerHash
```

Add parameterized rejection cases for 2,049 bytes, non-ASCII/invalid UTF-8,
non-object roots, duplicate properties, unknown/missing properties, wrong JSON
types, comments, trailing commas, and trailing non-whitespace bytes.

- [x] **Step 2: Run the parser tests and verify RED**

Run:

```powershell
Invoke-Pester ./tests/Unit/MarkerEvidenceChannel.Tests.ps1 -Output Detailed -CI
```

Expected: fail because `ConvertFrom-SetupCmMarkerEvidenceJsonStrict` does not
exist.

- [x] **Step 3: Implement the strict bounded parser**

Use a throwing UTF-8 decoder and `System.Text.Json.JsonDocument`; enumerate
properties before conversion so duplicate and unknown names cannot be hidden:

```powershell
function ConvertFrom-SetupCmMarkerEvidenceJsonStrict {
    [CmdletBinding()]
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $contract = Get-SetupCmMarkerFixedContract
    if ($Bytes.Count -gt [int]$contract.EvidenceChannel.MaximumBytes) {
        throw 'Marker evidence exceeds the 2,048-byte limit.'
    }
    if (@($Bytes | Where-Object { $_ -gt 0x7f }).Count -gt 0) {
        throw 'Marker evidence must contain only ASCII-compatible JSON.'
    }
    $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    $document = [System.Text.Json.JsonDocument]::Parse($text)
    try {
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw 'Marker evidence root must be an object.'
        }
        $expected = @(
            'schemaVersion', 'computerName', 'markerPath', 'markerSha256',
            'markerLength', 'verificationMethod'
        )
        $properties = @($document.RootElement.EnumerateObject())
        $names = @($properties | ForEach-Object Name)
        if ($names.Count -ne $expected.Count -or
            @($names | Select-Object -Unique).Count -ne $expected.Count -or
            @($names | Where-Object { $_ -cnotin $expected }).Count -gt 0) {
            throw 'Marker evidence properties are not exact.'
        }
        [pscustomobject][ordered]@{
            schemaVersion = $document.RootElement.GetProperty('schemaVersion').GetInt32()
            computerName = $document.RootElement.GetProperty('computerName').GetString()
            markerPath = $document.RootElement.GetProperty('markerPath').GetString()
            markerSha256 = $document.RootElement.GetProperty('markerSha256').GetString()
            markerLength = $document.RootElement.GetProperty('markerLength').GetInt64()
            verificationMethod = $document.RootElement.GetProperty('verificationMethod').GetString()
        }
    }
    finally {
        $document.Dispose()
    }
}
```

Catch `JsonException`, `DecoderFallbackException`, and invalid typed getters at
the assessment boundary and map them to conflict; do not silently coerce.

- [x] **Step 4: Add and implement semantic/receipt assessment tests**

Use normalized inventory rather than touching Windows APIs:

```powershell
$inventory = [pscustomobject]@{
    Evidence = [pscustomobject]@{
        Exists = $true
        IsReparsePoint = $false
        Length = $bytes.Count
        Bytes = $bytes
        OwnerSid = 'S-1-5-21-1-2-3-1001'
        AclExact = $true
        LastWriteTimeUtc = [datetime]'2026-08-30T12:00:00Z'
    }
    TargetComputerSid = 'S-1-5-21-1-2-3-1001'
}
$assessment = Get-SetupCmMarkerPublishedEvidenceAssessment `
    -Contract (Get-SetupCmMarkerFixedContract) -Inventory $inventory `
    -NowUtc ([datetime]'2026-08-30T12:10:00Z')
$assessment.State | Should -BeExactly 'Compliant'
$assessment.MarkerHashVerification | Should -BeExactly 'DirectAuthenticatedClientEvidence'
```

Add focused cases for missing, stale, too-far-future, before-minimum-receipt,
wrong owner SID, non-exact file ACL, reparse point, wrong computer/path/hash/
length/method/schema, and an injected read failure. Map missing/stale to
`NotCompliant/ClientEvidencePending`; map malformed, foreign, future, reparse,
and contradictory content to `Conflict` with a specific reason.

- [x] **Step 5: Run focused tests GREEN and commit**

Run:

```powershell
Invoke-Pester ./tests/Unit/MarkerEvidenceChannel.Tests.ps1 -Output Detailed -CI
git diff --check
```

Commit:

```bash
git add src/SetupCm/Private/MarkerEvidenceChannel.ps1 \
  src/SetupCm/Private/MarkerApplication.ps1 \
  tests/Unit/MarkerEvidenceChannel.Tests.ps1
git commit -m "feat: validate marker client evidence"
```

### Task 2: Exact Windows evidence-channel desired state

**Files:**

- Modify: `src/SetupCm/Private/MarkerEvidenceChannel.ps1`
- Modify: `tests/Unit/MarkerEvidenceChannel.Tests.ps1`
- Add: `tests/Integration/MarkerEvidenceChannel.Windows.Tests.ps1`

**Interfaces:**

- Consumes: Task 1 fixed channel contract.
- Produces:
  `Get-SetupCmMarkerEvidenceChannelInventory -Contract [object]`,
  `Get-SetupCmMarkerEvidenceChannelAssessment -Contract [object]
  -Inventory [object]`, and
  `New-SetupCmMarkerEvidenceChannel -Contract [object]`.

- [x] **Step 1: Write channel-state tests for exact, missing, partial, and conflict**

Represent every trustee by SID and every NTFS ACE by numeric rights,
inheritance, propagation, and access type. Pin these masks:

```powershell
$directoryRights = 1179819 # List/CreateFiles/Traverse/ReadEA/ReadAttr/ReadPerm/Sync
$modifyAndSynchronizeRights = 1245631
$fullControl = 2032127
```

Build an exact inventory and assert `Compliant/Exact`. Add cases proving:

- fully absent parent/target/share is `NotCompliant/Missing`;
- an exact protected administrative subset is
  `NotCompliant/IncompleteOwnedChannel`;
- wrong share path is `Conflict/SharePathConflict`;
- inherited, deny, broad, unknown, duplicate, or excessive ACEs are
  `Conflict/EvidenceAclConflict`;
- wrong directory owner, unresolved target SID, or any reparse point is
  `Conflict/EvidenceIdentityConflict`; and
- the evidence file may be absent while the channel itself is compliant.

- [x] **Step 2: Run channel-state tests RED**

Run the focused file and require failures for the missing assessment and
creation functions.

- [x] **Step 3: Implement normalized inventory and exact comparison**

Normalize Windows identities before comparison:

```powershell
function Resolve-SetupCmMarkerSid {
    param([Parameter(Mandatory)][string]$AccountName)
    ([System.Security.Principal.NTAccount]::new($AccountName)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
}
```

Return only normalized data from the inventory function. Detect reparse points
with `FileAttributes.ReparsePoint`; read at most 2,049 bytes; collect owner SID,
effective file ACL, and `LastWriteTimeUtc`; and use `Get-SmbShare` plus
`Get-SmbShareAccess` for exact share state. Do not place raw security
descriptors in the assessment details that later reach evidence.

- [x] **Step 4: Write creation-provider tests before implementation**

Mock `New-Item`, `Set-Acl`, `New-SmbShare`, and identity translation. Assert the
creation sequence is parent ACL, target ACL, then share; assert no call grants
`Everyone`, `Authenticated Users`, or `Domain Computers`; and assert a failure
before share creation leaves no broad grant or delete call.

- [x] **Step 5: Implement the protected parent, target, and hidden share**

Construct explicit `DirectorySecurity` objects with inheritance disabled:

```powershell
$security.SetAccessRuleProtection($true, $false)
$security.SetOwner($administratorsSid)
$security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
    $administratorsSid, 2032127, 3, 0, 'Allow'
))
$security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
    $systemSid, 2032127, 3, 0, 'Allow'
))
```

On the target directory add exactly one this-folder-only target ACE with mask
`1179819` and one object-inherit/inherit-only target ACE with the Windows
canonical `Modify` plus `Synchronize` mask `1245631`.
Create the share last:

```powershell
New-SmbShare -Name $Contract.EvidenceChannel.ShareName `
    -Path $Contract.EvidenceChannel.LocalPath `
    -Description $Contract.EvidenceChannel.ShareDescription `
    -CachingMode None `
    -FullAccess 'BUILTIN\Administrators' `
    -ChangeAccess $Contract.EvidenceChannel.ComputerAccount `
    -ErrorAction Stop | Out-Null
```

Verify by reacquiring normalized inventory and requiring `Compliant`; do not
remove or rewrite an existing conflicting share/ACE.

- [x] **Step 6: Add non-mutating Windows integration coverage**

On Windows, test strict SID/ACL normalization against a temporary protected
directory owned by the test. Do not create the fixed live share in this test;
the live first-run gate owns that mutation. Skip only when not Windows.

- [x] **Step 7: Run focused tests GREEN and commit**

Run unit plus Windows integration where available, then commit:

```bash
git add src/SetupCm/Private/MarkerEvidenceChannel.ps1 \
  tests/Unit/MarkerEvidenceChannel.Tests.ps1 \
  tests/Integration/MarkerEvidenceChannel.Windows.Tests.ps1
git commit -m "feat: reconcile marker evidence channel"
```

### Task 3: VBScript evidence publication and detector pin

**Files:**

- Modify: `scripts/marker/Test-SetupCmPhase1Marker.vbs`
- Modify: `tests/Integration/MarkerDetection.Windows.Tests.ps1`
- Modify: `src/SetupCm/Private/MarkerApplication.ps1:24-28`
- Modify: `tests/Unit/MarkerAcceptance.Tests.ps1`

**Interfaces:**

- Consumes: Task 1 six-field schema and Task 2 fixed evidence UNC.
- Produces: a detector with zero-argument production mode, one-argument
  detection-only mode, and two-argument target-only publication test mode; the
  new exact source detector length/hash become `DetectorFile`, while
  `PreviousDetectorFile` remains the accepted predecessor.

- [ ] **Step 1: Add Windows detector publication tests**

Extend the test helper to accept an optional local evidence path. On the exact
target, assert:

```powershell
$result = Invoke-MarkerDetector -MarkerRoot $markerRoot -EvidencePath $evidencePath
$result.Output | Should -BeExactly 'Installed'
$record = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
$record.computerName | Should -BeExactly 'RING0IVY24-01'
$record.markerSha256 | Should -BeExactly $expectedHash
$record.markerLength | Should -Be 78
```

Add tests proving tampered/missing markers publish no file, an unavailable
evidence path still returns `Installed` for exact bytes, one marker-root
argument never touches the production UNC, the final file is complete JSON,
and more than two arguments returns no installed output. Gate publication
tests on exact computer name; keep detection-only tests runnable on CM01.

- [ ] **Step 2: Run the new tests against the predecessor and verify RED**

Stage only the test and predecessor detector on the Windows target through the
existing SSH/controller path. Run Pester and retain the failure showing that
no evidence record is produced. Do not alter the ConfigMgr deployment type.

- [ ] **Step 3: Implement best-effort atomic publication**

Keep `Option Explicit` and the existing certutil exact-hash check. After the
hash matches and only when `WScript.Network.ComputerName` equals
`RING0IVY24-01`, build this exact single-record JSON:

```vbscript
evidenceJson = "{""schemaVersion"":1,""computerName"":""RING0IVY24-01""," & _
    """markerPath"":""C:\\ProgramData\\SetupCm\\Phase1\\marker.json""," & _
    """markerSha256"":""" & ExpectedHash & """," & _
    """markerLength"":78,""verificationMethod"":""CertUtilSha256Exact""}"
```

With zero arguments, use the fixed marker root and evidence UNC. With one
argument, use that marker root and disable publication. With two arguments,
use the marker root and second local evidence path only on the exact target.
Write with `FileSystemObject.GetTempName` in the destination directory, close
the stream, replace the final file by same-directory move, and remove only the
temporary file on handled failure. Wrap publication in local `On Error Resume
Next`; always echo exactly `Installed` after the exact hash even when
publication fails.

- [ ] **Step 4: Run Windows detector tests GREEN**

Run all detector tests on `RING0IVY24-01` and the detection-only subset on
CM01. Verify no test invocation wrote the production evidence UNC.

- [ ] **Step 5: Pin the new reviewed detector bytes**

Compute exact source metadata:

```powershell
$detector = Get-Item ./scripts/marker/Test-SetupCmPhase1Marker.vbs
$detectorHash = (Get-FileHash $detector.FullName -Algorithm SHA256).Hash
"Length=$($detector.Length) Hash=$detectorHash"
```

Copy those emitted exact values into `DetectorFile`. Keep the predecessor
length/hash unchanged in `PreviousDetectorFile`. Update unit provider fixtures
so `SourcePayload.Detector` uses the new source hash while live deployment
fixtures continue to use the predecessor hash until migration tests say
otherwise.

- [ ] **Step 6: Run focused portable and Windows tests GREEN and commit**

```bash
git add scripts/marker/Test-SetupCmPhase1Marker.vbs \
  src/SetupCm/Private/MarkerApplication.ps1 \
  tests/Integration/MarkerDetection.Windows.Tests.ps1 \
  tests/Unit/MarkerAcceptance.Tests.ps1
git commit -m "feat: publish authenticated marker evidence"
```

### Task 4: Integrate proof precedence, migration, and bounded convergence

**Files:**

- Modify: `src/SetupCm/Private/MarkerApplication.ps1:218-1175`
- Modify: `src/SetupCm/Private/MarkerEvidenceChannel.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCmMarkerAcceptance.ps1`
- Modify: `tests/Unit/MarkerAcceptance.Tests.ps1`
- Modify: `tests/Unit/MarkerEvidenceChannel.Tests.ps1`

**Interfaces:**

- Consumes: channel assessment, published-evidence assessment, current and
  predecessor detector hashes.
- Produces:
  `Get-SetupCmMarkerDesiredState [-MinimumEvidenceReceiptUtc [datetime]]`,
  default provider keys `EvidenceChannel`, `CreateEvidenceChannel`,
  `UpdateDetectorPolicy`, and `WaitForConvergence`, plus
  `Wait-SetupCmMarkerConvergence`.

- [ ] **Step 1: Write desired-state proof-precedence tests**

Extend `New-CompliantMarkerProviders` with exact `EvidenceChannel` inventory.
Add tests for:

- exact `DirectAuthenticatedFileRead` remains compliant;
- unavailable `C$` plus exact published evidence becomes
  `DirectAuthenticatedClientEvidence` and compliant;
- successful direct read with missing/wrong bytes does not fall back;
- missing/stale published evidence with a missing/incomplete channel is
  `NotCompliant/ClientEvidencePending`, never a blocking probe conflict;
- malformed/foreign/future evidence is conflict;
- both reads unexpectedly failing after an exact channel is
  `Conflict/ClientProbeUnavailable`; and
- `ExactDetectorAndServerState` remains noncompliant.

- [ ] **Step 2: Write detector migration classification tests**

Use the predecessor deployment hash with every other property exact and assert:

```powershell
$component = $state.Components | Where-Object Name -eq DeploymentType
$component.State | Should -BeExactly 'NotCompliant'
$component.Reason | Should -BeExactly 'ApprovedDetectorUpgrade'
```

Assert current detector is compliant, any third hash is conflict, and
predecessor plus another deployment-type drift is conflict.

- [ ] **Step 3: Run desired-state tests RED**

Run `MarkerAcceptance.Tests.ps1`; require focused failures for missing provider
keys, unsupported proof route, and predecessor classification.

- [ ] **Step 4: Integrate one channel probe and proof selection**

Call `Providers.EvidenceChannel` once before ConfigMgr inventory, add a sanitized
`EvidenceChannel` component, and pass the normalized inventory plus optional
minimum receipt to the provider inventory. When direct `C$` returns
`ProbeUnavailable`, call the published-evidence assessment; when direct returns
`Missing` or a real hash, keep it authoritative. Permit exactly these successful
routes:

```powershell
$markerHashVerification -cin @(
    'DirectAuthenticatedFileRead',
    'DirectAuthenticatedClientEvidence'
)
```

Include only share name, channel local path, target SID, receipt time, owner
SID, schema version, route, marker hash, and marker length in component
evidence. Never include ACE arrays or raw descriptors.

- [ ] **Step 5: Write repair-sequence and zero-action tests**

Record action names and assert the first migration sequence is exactly:

```powershell
@(
    'CreateEvidenceChannel',
    'UpdateDetectorPolicy',
    'RequestClientPolicy',
    'WaitForConvergence'
)
```

Assert it excludes `SyncContent`, `UpdateDeploymentType`, `Distribute`, object
creation, membership, and assignment actions. Assert exact fresh state calls
zero actions. Preserve existing tests proving real content drift still follows
`SyncContent`, `UpdateDeploymentType`, and `Distribute`.

- [ ] **Step 6: Implement narrow repair routing**

Create the channel before policy mutation. Route only
`ApprovedDetectorUpgrade` to:

```powershell
Set-CMScriptDeploymentType -ApplicationName $Contract.ApplicationName `
    -DeploymentTypeName $Contract.DeploymentTypeName `
    -ScriptLanguage VBScript -ScriptText $detector -Force | Out-Null
```

Do not supply `ContentLocation`, install/uninstall commands, or runtime
properties on this policy-only action. Split `detectorPolicyChanged` from
`contentChanged`; only content or package drift permits `Distribute`.
The supported detector-only parameters are documented by
[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/configurationmanager/set-cmscriptdeploymenttype?view=sccm-ps).

Capture `MinimumEvidenceReceiptUtc` immediately before the single provider call
that requests both machine policy and application deployment evaluation, then
invoke `WaitForConvergence` once. Extend
`Invoke-SetupCmMarkerProviderAction` with `-Arguments [object[]]`; the default
wait provider accepts `($Config, $Contract, $MinimumEvidenceReceiptUtc,
$AllProviders)` so polling reuses the same read-only provider set.

- [ ] **Step 7: Write and implement convergence tests**

Inject state, clock, and delay providers into
`Wait-SetupCmMarkerConvergence`. Test pending-to-compliant, immediate conflict,
and timeout without real sleep:

```powershell
$states = [System.Collections.Generic.Queue[object]]::new()
$states.Enqueue([pscustomobject]@{ State = 'NotCompliant'; Components = @() })
$states.Enqueue([pscustomobject]@{ State = 'Compliant'; Components = @() })
$result = Wait-SetupCmMarkerConvergence -Config $config -Contract $contract `
    -MinimumEvidenceReceiptUtc $minimum `
    -StateProvider { $states.Dequeue() } `
    -UtcNowProvider { [datetime]'2026-08-30T12:00:00Z' } `
    -DelayProvider { param($Seconds) }
$result.State | Should -BeExactly 'Compliant'
```

The default loop probes immediately, sleeps 15 seconds only while pending,
stops at 900 seconds, throws immediately on conflict, and never invokes a
second mutation.

- [ ] **Step 8: Run focused tests GREEN and commit**

```powershell
Invoke-Pester ./tests/Unit/MarkerEvidenceChannel.Tests.ps1,./tests/Unit/MarkerAcceptance.Tests.ps1 -Output Detailed -CI
```

```bash
git add src/SetupCm/Private/MarkerApplication.ps1 \
  src/SetupCm/Private/MarkerEvidenceChannel.ps1 \
  src/SetupCm/Public/Invoke-SetupCmMarkerAcceptance.ps1 \
  tests/Unit/MarkerAcceptance.Tests.ps1 \
  tests/Unit/MarkerEvidenceChannel.Tests.ps1
git commit -m "feat: converge marker client evidence"
```

### Task 5: Windows/provider acceptance, documentation, and portable gates

**Files:**

- Modify: `tests/Integration/MarkerAcceptance.Provider.Tests.ps1`
- Modify: `tests/Integration/MarkerEvidenceChannel.Windows.Tests.ps1`
- Modify: `README.md`
- Modify: `docs/CONFIGURATION.md`
- Modify: `docs/RUNBOOK.md`
- Modify: `docs/LABZ1_DEPLOYMENT.md`
- Modify: `docs/PHASE1-2026-08-29-MARKER-DEPLOYMENT.md`
- Modify: `docs/gitbook/src/configuration/reference.md`
- Modify: `docs/gitbook/src/operations/runbook.md`
- Modify: `docs/gitbook/src/operations/stages-and-evidence.md`
- Modify: `docs/gitbook/src/operations/recovery.md`
- Modify: `docs/gitbook/src/operations/current-status.md`
- Modify: `docs/gitbook/src/development/implementation-plans.md`
- Modify: `docs/gitbook/src/development/testing.md`
- Modify: `docs/superpowers/specs/2026-08-30-marker-client-evidence-channel-design.md`
- Modify: `docs/superpowers/plans/2026-08-30-hands-off-rerun-v1.md`

**Interfaces:**

- Consumes: complete local implementation.
- Produces: executable operator/recovery contract, read-only pre-mutation live
  probe, and a fail-on-mutation exact-state provider test.

- [ ] **Step 1: Extend provider integration assertions before live mutation**

Require `EvidenceChannel`, `Client`, and `ServerCompliance` components. In
pre-migration mode assert the only noncompliant components are
`EvidenceChannel`, `DeploymentType/ApprovedDetectorUpgrade`, and
`Client/ClientEvidencePending`; all boundary, content, collection, assignment,
and distribution components remain exact. In post-migration mode require every
component compliant and install mutation adapters that throw for:

```powershell
@(
    'CreateEvidenceChannel', 'UpdateDetectorPolicy', 'SyncContent',
    'CreateApplication', 'CreateDeploymentType', 'UpdateDeploymentType',
    'Distribute', 'CreateCollection', 'AddDirectMembership',
    'RefreshCollection', 'CreateDeployment', 'UpdateDeployment',
    'RequestClientPolicy', 'WaitForConvergence'
)
```

- [ ] **Step 2: Run all portable gates**

```powershell
Invoke-Pester ./tests/Unit -Output Detailed -CI
./scripts/Test-MarkdownLinks.ps1
mdbook build ./docs/gitbook
```

Also run all PowerShell parse checks, PSScriptAnalyzer error-only gate,
`actionlint`, `git diff --check`, and the repository secret/private-path scan
used for the existing PR.

- [ ] **Step 3: Run Windows tests from an exact Git archive**

Create a `git archive` of `git rev-parse HEAD`, verify its SHA-256 and embedded
commit on CM01, and run:

```powershell
Invoke-Pester ./tests/Integration/CoreStages.Windows.Tests.ps1,`
  ./tests/Integration/MarkerDetection.Windows.Tests.ps1,`
  ./tests/Integration/MarkerEvidenceChannel.Windows.Tests.ps1 -Output Detailed -CI
```

Run the detector publication subset on `RING0IVY24-01`. Run the provider suite
on CM01 first in pre-migration/read-only mode. No provider mutation is allowed
in this step.

- [ ] **Step 4: Document exact channel, freshness, recovery, and second-run semantics**

Document the fixed share/ACL, strict schema, successful proof routes,
30-minute freshness, policy-only predecessor migration, 15-minute convergence,
safe partial-channel recovery, conflict stop conditions, and the distinction
between the immediate zero-action second acceptance run and a later bounded
evidence refresh. Mark the design status `Approved and implemented` only after
tests pass.

- [ ] **Step 5: Rerun documentation/full gates and commit**

```bash
git add README.md docs/CONFIGURATION.md docs/RUNBOOK.md \
  docs/LABZ1_DEPLOYMENT.md docs/PHASE1-2026-08-29-MARKER-DEPLOYMENT.md \
  docs/gitbook/src/configuration/reference.md \
  docs/gitbook/src/operations/runbook.md \
  docs/gitbook/src/operations/stages-and-evidence.md \
  docs/gitbook/src/operations/recovery.md \
  docs/gitbook/src/operations/current-status.md \
  docs/gitbook/src/development/implementation-plans.md \
  docs/gitbook/src/development/testing.md \
  docs/superpowers/specs/2026-08-30-marker-client-evidence-channel-design.md \
  docs/superpowers/plans/2026-08-30-hands-off-rerun-v1.md \
  tests/Integration/MarkerAcceptance.Provider.Tests.ps1 \
  tests/Integration/MarkerEvidenceChannel.Windows.Tests.ps1
git commit -m "docs: define marker evidence operations"
```

- [ ] **Step 6: Push and clear review gates**

Push the existing branch only. Wait for Pester and mdBook checks, run a complete
review at the exact PR head, reproduce every actionable finding, fix test-first,
and require local/remote/PR heads to match before live mutation.

### Task 6: Live first run and immediate zero-action second run

**Files:**

- Add after acceptance: `docs/V1-ACCEPTANCE-2026-08-30.md`
- Modify after acceptance:
  `docs/superpowers/plans/2026-08-30-hands-off-rerun-v1.md`
- Modify after acceptance: `docs/gitbook/src/operations/current-status.md`

**Interfaces:**

- Consumes: frozen reviewed PR head and ignored private CM01 configuration.
- Produces: two sanitized evidence bundles, independent provider/SQL/client/
  controller/Proxmox proof, and a committed acceptance record tied to one exact
  source commit.

- [ ] **Step 1: Reconfirm live safety boundary read-only**

Verify pve2 owns running VM 107/111/115/135 and CT 500, quorum is healthy,
controller/agents are current, CM01 is the exact provider/site/database, and
resource `16777219` is the sole direct member of `LAB00016`. Verify application,
deployment type, package/content IDs, distribution, assignment, and marker hash
before mutation. Stop on identity or scope conflict.

- [ ] **Step 2: Freeze and stage the exact reviewed commit**

```powershell
$acceptedCommit = (git rev-parse HEAD).Trim()
git archive --format=tar --output="setup-cm-$acceptedCommit.tar" $acceptedCommit
git get-tar-commit-id < "setup-cm-$acceptedCommit.tar"
Get-FileHash "setup-cm-$acceptedCommit.tar" -Algorithm SHA256
```

Stage atomically under
`C:\ProgramData\SetupCm\source\$acceptedCommit`; verify the archive hash and
embedded commit, preserve the ignored private config/ACL, and set
`SETUPCM_SOURCE_COMMIT` to that exact commit without printing secrets or source
URLs.

- [ ] **Step 3: Run the first full workflow**

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -Mode Unattended `
  -Stage Acquire,Sql,Mecm,Marker,Health `
  -SourceCommit $env:SETUPCM_SOURCE_COMMIT
```

Permit only channel creation, detector policy update, one paired client
policy/application evaluation request, and bounded convergence. Independently
verify the share and NTFS ACLs, target SID/file owner, strict record and receipt
time, current detector hash/revision, server compliance, unchanged payload/
package/distribution/object identities, no installer process, and no client
firewall/trust/task/service change.

- [ ] **Step 4: Run the identical command immediately a second time**

Instrument every mutation and side-effect adapter and require zero calls.
Require all five stage results to be `Skipped/Already compliant`, fresh run and
health evidence, the same source commit, and no acquisition, installer,
redistribution, object update/create, membership, assignment, policy request,
or wait action.

- [ ] **Step 5: Sanitize, hash, and record acceptance**

Scan both bundles recursively for credentials, URLs, source/vault paths, raw
policy, and raw logs. Hash every accepted artifact. Write
`docs/V1-ACCEPTANCE-2026-08-30.md` with exact source commit, run IDs, artifact
hashes, allowed first-run actions, zero second-run actions, live identities,
limitations, and restart command. Do not commit private bundles.

- [ ] **Step 6: Commit and push the acceptance record**

```bash
git add docs/V1-ACCEPTANCE-2026-08-30.md \
  docs/superpowers/plans/2026-08-30-hands-off-rerun-v1.md \
  docs/gitbook/src/operations/current-status.md
git commit -m "docs: record v1 live acceptance"
git push origin codex/hands-off-rerun-v1
```

Rerun full local gates and require PR checks/review clean at the new exact head.

### Task 7: Merge, tag, publish, and independently verify v1

**Files:**

- Modify only if acceptance source must be repeated:
  `docs/V1-ACCEPTANCE-2026-08-30.md`

**Interfaces:**

- Consumes: clean PR with committed live evidence summary.
- Produces: merged exact source, annotated `v1.0.0`, GitHub release, deployed
  matching mdBook, and a preserved/recoverable cleanup result.

- [ ] **Step 1: Merge only the clean existing PR**

Require Pester, mdBook, review, package/link/security gates green and all review
threads resolved. Merge PR #5, fetch without rewriting the primary checkout,
and prove merge ancestry plus local/remote/PR commit identities.

- [ ] **Step 2: Compare accepted and merged tree identities**

```bash
accepted_commit=$(git rev-parse refs/remotes/origin/codex/hands-off-rerun-v1)
merge_commit=$(gh pr view 5 --json mergeCommit --jq '.mergeCommit.oid')
git rev-parse "${accepted_commit}^{tree}"
git rev-parse "${merge_commit}^{tree}"
```

Derive both commit values from Git/PR state rather than typing them. If tree IDs
differ, restage the merge commit and repeat both live runs before tagging; the
new merge-commit evidence supersedes the PR-head evidence.

- [ ] **Step 3: Run release-critical proof at the merge commit**

Run the full portable suite, links, mdBook, parsing/static analysis, read-only
live Health, and the fail-on-mutation provider test. Require zero marker
mutation adapters.

- [ ] **Step 4: Create and verify the first annotated tag**

Confirm `refs/tags/v1.0.0` is absent locally and on origin. Create the annotated
tag at the accepted merge commit, dereference it, compare its tree, push it, and
verify origin resolves the same object. Stop rather than replace an existing
tag.

- [ ] **Step 5: Publish and verify GitHub release and Pages**

Publish release notes with supported topology, exact source commit/tree,
portable/Windows/live gates, evidence hashes, proof route, security boundary,
freshness behavior, and limitations. Verify the release/tag assets and Pages
deployment from authoritative GitHub state, then compare a version/source
marker in the published mdBook with the tagged source.

- [ ] **Step 6: Preserve user work and clean only proven-safe artifacts**

Recheck the primary untracked handoff byte count and SHA-256. Remove only
temporary source/test artifacts created by this workflow. Remove the branch or
worktree only when merged reachability, cleanliness, untracked-data, active
reference, and no-running-process checks all pass; otherwise leave them and
record why.
