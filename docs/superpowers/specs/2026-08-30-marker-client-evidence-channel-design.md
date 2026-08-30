# Authenticated Marker Client Evidence Channel Design

**Status:** Approved, implemented, and accepted live on 2026-08-30. The final
two-run evidence is in
[v1 hands-off acceptance](../../V1-ACCEPTANCE-2026-08-30.md).

## Purpose

Restore fail-closed, direct client proof for the LabZ1 marker acceptance without
opening inbound client firewall rules, weakening PowerShell policy, relying on
VNC, or treating ConfigMgr server projections as proof of the marker bytes on
the client.

The accepted implementation adds one setup-cm-owned, hidden SMB evidence share
on `LABZ1-CM01.test.gell.one`. The existing VBScript detector continues to
recognize only the exact marker SHA-256. When that check succeeds under the
ConfigMgr `System` execution context, the detector also publishes a small,
fixed-schema record outbound to CM01 using the exact client computer account.
The provider validates the record, its server-side receipt metadata, its owner,
and the matching ConfigMgr deployment state before reporting the client
component compliant.

## Why this change is required

The hardened marker provider correctly stopped accepting an expected hash
projected from ConfigMgr server state. Its replacement direct probe reads the
client's marker through `C$`, but the 2026-08-30 live acceptance established
that:

- CM01 cannot initiate TCP 445 to `RING0IVY24-01`;
- the client has its Server service and local SMB listener, but its built-in
  inbound SMB firewall rules are disabled;
- setup-cm owns no client firewall rule and the v1 boundary explicitly excludes
  client-wide security-policy changes; and
- `RING0IVY24-01` can reach CM01 outbound on TCP 445.

The former historical `8/8` result is not acceptance for the hardened
implementation. It predated fail-closed commit `8a38acb` and used
`ExactDetectorAndServerState`, which projected the configured hash instead of
reading evidence created by the client. The pre-implementation live result was
therefore seven passing Windows/provider checks and one correctly failing
marker client probe with reason `ClientProbeUnavailable`. The implemented
source now passes the strict channel, detector-publication, and read-only
pre-migration provider gates; applying the live migration remains a separate
acceptance step.

## Fixed boundary

This design is intentionally specific to the accepted v1 lab:

- site server and provider: `LABZ1-CM01.test.gell.one`;
- site code: `LAB`;
- target client: `RING0IVY24-01.test.gell.one`;
- target ConfigMgr resource ID: `16777219`;
- target computer account: `TEST\RING0IVY24-01$`;
- marker path: `C:\ProgramData\SetupCm\Phase1\marker.json`;
- marker length: `78` bytes;
- marker SHA-256:
  `3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254`;
- application: `Setup-CM Phase 1 Marker`;
- collection: `Setup-CM Phase 1 Marker - RING0IVY24-01 Only`.

Any host, domain, site, resource, application, collection, marker, share, or
security identity outside this fixed boundary is a conflict. This feature does
not become a generic evidence relay in v1.

## Decisions and non-goals

The implementation does:

- retain VBScript as the ConfigMgr detector;
- retain the exact marker SHA-256 as the only installed-state signal;
- authenticate the evidence writer through the target computer account;
- use CM01-owned SMB and NTFS state that setup-cm can probe and reconcile;
- keep evidence publication best-effort from the detector's perspective;
- fail marker acceptance independently when required client evidence is absent,
  stale, malformed, or contradictory;
- preserve the existing direct `C$` file read as an optional first-choice proof
  when it is available; and
- use the outbound evidence record as the normal LabZ1 proof path.

The implementation does not:

- enable Windows file-sharing firewall rules on the client;
- add a firewall rule owned by setup-cm on the client;
- add a scheduled task, service, generic agent job, WinRM requirement, or
  interactive/VNC step;
- weaken signing, execution, authentication, SMB, or trust policy;
- grant access to `Everyone`, `Authenticated Users`, `Domain Computers`, or any
  other broad principal;
- deploy to another client or broaden the marker collection;
- accept a ConfigMgr provider or SQL projection as direct marker-byte proof;
- change or redistribute the three marker content files when their bytes remain
  exact; or
- move this responsibility into ProxmoxVEAutopilot or another repository.

## Evidence channel contract

The channel has fixed identities and paths:

| Item | Exact value |
| --- | --- |
| SMB share name | `SetupCmMarkerEvidence$` |
| SMB description | `Setup-CM LabZ1 marker evidence for RING0IVY24-01` |
| SMB caching mode | `None` |
| Local parent | `C:\ProgramData\SetupCm\MarkerEvidence` |
| Share path | `C:\ProgramData\SetupCm\MarkerEvidence\RING0IVY24-01` |
| Evidence file | `marker-evidence.json` |
| Evidence UNC | `\\LABZ1-CM01.test.gell.one\SetupCmMarkerEvidence$\marker-evidence.json` |
| Maximum final-file size | 2,048 bytes |
| Freshness window | 30 minutes |
| Schema version | `1` |

The share points directly at the one target directory; there is no shared
multi-client drop root. SMB offline caching is disabled. The share ACL contains
only `TEST\RING0IVY24-01$` with `Change` and `BUILTIN\Administrators` with
`Full`. It contains no inherited or default broad trustee.

NTFS inheritance is disabled on both the local parent and target directory so
the effective permissions are independently inspectable. `BUILTIN\Administrators`
and `NT AUTHORITY\SYSTEM` have `FullControl` on the parent, target directory,
and children, and `BUILTIN\Administrators` is the exact owner of both
directories. The target computer receives two allow ACEs and no deny ACE:

- target-directory only: `ListDirectory`, `CreateFiles`, `Traverse`,
  `ReadExtendedAttributes`, `ReadAttributes`, `ReadPermissions`, and
  `Synchronize`; and
- files only, inherited by child files: `Modify` and `Synchronize`.

The files-only ACE uses the .NET numeric `InheritanceFlags` value `2`
(`ObjectInherit`) with `PropagationFlags` value `2` (`InheritOnly`). Value `1`
is `ContainerInherit`; it does not grant the target computer rights on a newly
created file and therefore cannot be accepted as the final channel state.

No other explicit or inherited trustee is accepted. No target ACE grants
`CreateDirectories`, `Delete` on the target directory, `ChangePermissions`, or
`TakeOwnership`. The exact rights permit a new temporary file to be created,
written, read back, deleted, and renamed over the fixed final file while the
coarser share `Change` grant remains constrained by NTFS. The provider also
requires the final file's effective ACL to contain only the expected inherited
administrative, SYSTEM, and target-computer access.

The target ACE must not grant permission changes, ownership changes, writes
outside the fixed target directory, or access to another setup-cm path. The
provider resolves `TEST\RING0IVY24-01$` to a SID and compares SIDs rather than
trusting display-name text. It also rejects a reparse point at the local parent,
share path, or evidence file.

The final evidence file must be owned by the exact target computer SID. The
provider reads it locally on CM01, never by looping through the share, and uses
the CM01 filesystem receipt time as the authoritative freshness timestamp. The
record contains no client-supplied timestamp.

This is authenticated operational evidence, not hardware attestation. It proves
that the exact domain computer identity published the fixed record and that the
current detector/server state agrees with it. It does not defend against a
compromised client `SYSTEM` context or a compromised domain computer account;
those actors already control the marker and its publication identity.

## Evidence record

The detector writes ASCII-compatible JSON with exactly these properties and no
others:

```json
{
  "schemaVersion": 1,
  "computerName": "RING0IVY24-01",
  "markerPath": "C:\\ProgramData\\SetupCm\\Phase1\\marker.json",
  "markerSha256": "3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254",
  "markerLength": 78,
  "verificationMethod": "CertUtilSha256Exact"
}
```

The provider performs a bounded read and a strict parse. It rejects duplicate
properties, unknown properties, wrong types, invalid encoding, trailing
non-whitespace data, and a record larger than 2,048 bytes. Every value must
match the fixed contract exactly. Computer-name comparison is case-insensitive;
the path, hash, verification method, schema version, and length are exact.

Validation also requires:

- the final file owner is the resolved target computer SID;
- the CM01 receipt time is not more than two minutes in the future;
- the receipt time is no more than 30 minutes old;
- after a repair or explicit reevaluation request in the current run, the
  receipt time is at or after that request began; and
- the exact ConfigMgr application, deployment type revision, assignment,
  collection, resource ID, compliance, installed, and enforcement state agree
  with the direct evidence.

Evidence artifacts emitted by setup-cm may include the validated schema fields,
owner SID, receipt time, verification route, and ConfigMgr identities. They do
not include ACL security descriptors, raw policy, credentials, private
configuration, source locations, or client logs.

## Detector behavior

The detector's primary contract does not change:

1. Resolve the fixed marker path, with the existing marker-root override used
   only by the Windows integration test.
2. Return no installed output when the file is missing, unreadable, the hash
   command fails, or the SHA-256 differs.
3. Only after an exact SHA-256 match, attempt to publish the evidence record.
4. Write a bounded temporary file in the same share directory and replace the
   final file by rename so the provider never parses a partially written final
   record.
5. Clean up the detector-owned temporary file on a handled failure.
6. Echo exactly `Installed` for the exact local hash even if evidence
   publication fails.

Step 6 keeps ConfigMgr detection truthful: availability of the acceptance
evidence transport cannot turn an installed marker into an absent marker or a
wrong marker into an installed one. The setup-cm Marker stage applies the
stronger acceptance rule and remains noncompliant until it can validate direct
evidence.

Detector arguments have one fixed contract. With no arguments, the production
invocation uses the fixed marker root and fixed evidence UNC. With one argument,
the existing marker-root test override is used and evidence publication is
disabled. With two arguments, the first is the non-default marker root and the
second is a local evidence-file path used only by Windows tests running on the
exact target computer. Any other argument count fails closed with no installed
output. The production deployment type supplies no arguments. Tests must prove
that a marker-root test cannot accidentally write to the live share and that a
lone evidence-path argument cannot redirect a production invocation.

## Provider proof precedence

The provider distinguishes transport failure from contradictory direct state:

1. If the authenticated `C$` read succeeds, its exact file hash and length are
   authoritative.
2. If `C$` is unavailable, the provider validates the authenticated outbound
   evidence record.
3. If `C$` succeeds and proves a missing or wrong marker, the provider does not
   override that result with an older evidence record.
4. A malformed, foreign-owned, wrong-identity, or future-dated evidence file is
   a conflict even when ConfigMgr server state says compliant.
5. A valid but stale record is repairable pending evidence, not a conflict.

The successful routes are named distinctly in evidence:

- `DirectAuthenticatedFileRead` for the optional CM01-to-client read; and
- `DirectAuthenticatedClientEvidence` for the client-to-CM01 publication.

`ExactDetectorAndServerState` is never a successful verification route.

## Desired-state model

The Marker probe adds an `EvidenceChannel` component and refines the `Client`
component.

### EvidenceChannel states

| Observed state | Result | Reason | Repair |
| --- | --- | --- | --- |
| Exact path, share, owner, ACLs, and no reparse point | Compliant | `Exact` | None |
| Entire fixed channel absent | NotCompliant | `Missing` | Create the protected directory and hidden share |
| Protected setup-cm path exists with only a safe subset of expected ACEs | NotCompliant | `IncompleteOwnedChannel` | Add only the missing fixed ACE/share state |
| Same share name points elsewhere | Conflict | `SharePathConflict` | None |
| Broad, inherited, unknown, or excessive access exists | Conflict | `EvidenceAclConflict` | None |
| Path/share/file is a reparse point or identity cannot be resolved exactly | Conflict | `EvidenceIdentityConflict` | None |

The repair never removes an unknown trustee or retargets an existing share. A
partially created channel is repairable only when every existing element is at
the fixed path, setup-cm-owned, protected from inheritance, and no broader than
the expected access set.

### Client states

| Observed state | Result | Reason |
| --- | --- | --- |
| Exact direct proof plus exact ConfigMgr state | Compliant | `Exact` |
| Evidence missing or older than 30 minutes | NotCompliant | `ClientEvidencePending` |
| Evidence predates a repair/reevaluation request in this run | NotCompliant | `ClientEvidencePending` |
| Directly observed marker is missing or wrong | NotCompliant | `ClientNotCompliant` |
| ConfigMgr state has not converged to the exact current revision | NotCompliant | `ClientStatePending` |
| Record is malformed, foreign-owned, future-dated, or identity fields differ | Conflict | Specific evidence conflict |
| Both direct transports fail unexpectedly | Conflict | `ClientProbeUnavailable` |

An absent or stale otherwise valid record permits exactly one bounded policy
and application-evaluation request in a repair pass. Malformed or contradictory
evidence never triggers a mutation.

When `EvidenceChannel` is `Missing` or `IncompleteOwnedChannel` and `C$` is
unavailable, `Client` is `NotCompliant` with `ClientEvidencePending`; that
expected initial state must not block safe channel creation.
`ClientProbeUnavailable` applies only after the channel itself is exact and its
local evidence read fails for a reason other than a missing or stale record.

## Approved detector migration

The detector currently installed in LabZ1 is a known, accepted predecessor:

- filename: `Test-SetupCmPhase1Marker.vbs`;
- length: `1,310` bytes;
- SHA-256:
  `DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC`.

The implementation pins both that predecessor and the new reviewed detector
hash. Deployment-type classification is:

- new detector hash: compliant;
- exact predecessor hash with every other deployment-type identity/property
  exact: `NotCompliant` with reason `ApprovedDetectorUpgrade`;
- any other detector hash: conflict with reason `DetectorHashMismatch`.

Only `ApprovedDetectorUpgrade` permits an in-place detector update. The update
uses the narrowest supported ConfigMgr operation and does not copy marker
content, change content bytes, redistribute the application, recreate the
application/deployment type, change collection membership, or recreate the
assignment. The provider verifies that content and package identities and
distribution state remain exact after the policy-only update.

## Repair sequence and convergence

When the initial read-only probe contains no conflict, the first run performs
only the required actions in this order:

1. Create or complete the exact protected evidence channel if needed.
2. Upgrade the detector only from the exact approved predecessor.
3. Wait read-only for the current application revision to match the assignment
   policy revision and observe that exact revision/scope pair unchanged for 60
   seconds, bounded by five minutes. Then request machine policy once, allow a
   30-second processing interval, and request application deployment evaluation
   once if the
   detector changed, direct evidence is missing/stale, or exact server state is
   pending.
4. Poll read-only provider/client state every 15 seconds for up to 15 minutes.
5. Succeed only when the evidence channel, direct client proof, and current
   ConfigMgr application/deployment revision all agree.

The publication wait covers both application and assignment-only changes and
prevents the client from evaluating the previous detector revision while
ConfigMgr policy generation or management-point visibility is still settling.
Every snapshot executes in a disposable read-only PowerShell process and is
bounded by the lesser of 90 seconds and the milliseconds remaining in the
single five-minute deadline. A hung ConfigMgr/CIM query is terminated, so it
cannot silently extend or bypass the outer publication timeout. The 30-second interval sequences the two
notifications; it is not accepted as proof that the client received policy.
The v1 network boundary exposes no safe direct client policy-receipt probe, so
only a fresh authenticated detector record plus the current ConfigMgr
client/server revision can satisfy convergence. If processing is still delayed,
the run fails closed at timeout without another notification and a later run
may make one new bounded request.
The two notifications remain one bounded
`RequestClientPolicy` adapter action; no second policy request is made. The
UTC timestamp captured immediately after the machine-policy request completes
is returned by the adapter and becomes the minimum accepted CM01 receipt time
whenever step 3 runs. A scope/cardinality change or publication timeout fails before client
notification. A conflict discovered during convergence polling stops
immediately. Timeout leaves the stage failed with the final structured
component states and performs no second mutation attempt.

The immediate second acceptance run occurs within the 30-minute freshness
window. It must classify every stage as already compliant and call no mutation
or side-effect adapter, including no policy/evaluation request. A later routine
run after evidence expires may request one bounded reevaluation to refresh
proof, but it still must not reinstall, recreate, redistribute, broaden
targeting, or alter SQL/MECM state. The v1 two-run no-op claim applies to the
documented immediate second run with fresh first-run evidence.

## Failure and cleanup behavior

Channel creation is ordered from restrictive local state outward: create the
fixed directory with inheritance disabled and protected administrative ACLs,
add only the target computer ACE, and expose the hidden share last. Each step is
independently verified before continuing.

If creation fails midway, setup-cm leaves the local evidence directory
protected. It does not enable inheritance, add a broad fallback principal, or
delete an ambiguous pre-existing path. A later run may complete only a
recognizable safe partial state. Same-name share conflicts, broad ACLs,
unresolvable identities, malformed/foreign evidence, and unknown detector
hashes require operator reconciliation.

The one approved predecessor exception is the otherwise exact target ACL that
used `ContainerInherit` for the target computer's `Modify` ACE. That exact shape
is a bounded `ApprovedTargetFileInheritanceUpgrade`: setup-cm replaces only the
target-directory ACL with the fixed `ObjectInherit` form and verifies the full
channel again. Any additional ACL drift remains a conflict.

Detector publication failure removes only its own bounded temporary file when
possible. The provider never deletes the final record merely because it is
malformed or foreign-owned; preserving that evidence makes the conflict
diagnosable. Release cleanup may remove only temporary source/test artifacts
created by the acceptance workflow, never the required live channel or marker
objects.

## Test-first implementation requirements

Every production behavior starts with a failing Pester test. Required coverage
includes:

### Portable unit tests

- exact evidence-channel state, fully missing state, safe partial state, wrong
  share path, broad/inherited ACL, unknown trustee, excessive target rights,
  reparse points, and SID mismatch;
- strict evidence parsing success plus rejection of over-size, malformed,
  duplicate/extra fields, wrong types, wrong target/path/hash/length/method,
  foreign owner, stale receipt, and future receipt;
- direct-read precedence and the outbound evidence fallback;
- exact predecessor detector classification as the sole bounded upgrade and
  unknown detector hashes as conflicts;
- repair calls for channel creation, detector-only update, one client request,
  bounded polling, immediate conflict stop, and timeout;
- no content synchronization or redistribution for a detector-only update;
- exact compliant state calling zero provider actions; and
- evidence serialization that records only the approved structured fields.

### Windows integration tests

- the detector publishes evidence only after the exact marker hash;
- missing, unreadable, and tampered markers publish nothing;
- evidence transport failure does not suppress `Installed` for an exact marker;
- a temporary file is never accepted as the final record;
- local test-path overrides cannot alter an argument-free production
  invocation; and
- the channel ACL and strict record validator operate through real Windows
  filesystem, SMB, SID, and owner APIs without changing machine policy.

### Live LabZ1 acceptance

- initial probe reproduces the known predecessor/pending-evidence state without
  mutation;
- first run creates the exact channel, updates only the detector policy,
  requests one bounded evaluation, and converges to direct evidence plus exact
  provider state;
- payload hashes, package/content IDs, distribution state, collection ID and
  one-member scope, assignment ID, application identity, and marker bytes
  remain exact;
- final evidence file owner is the target computer SID and its CM01 receipt is
  fresh;
- second identical run invokes no mutation or side-effect adapter and reports
  all five stages skipped/already compliant; and
- no inbound client firewall, trust, scheduled-task, service, VNC, VM, or
  cross-repository change occurred.

## Documentation and release impact

Implementation must update the operator configuration, runbook, evidence
format, recovery guidance, LabZ1 deployment record, implementation plan, and
v1 acceptance record. The final release notes must state that authenticated
client-published evidence is the normal LabZ1 proof route, that the channel is
limited to one computer account, and that evidence freshness can cause a later
run to request evaluation without causing infrastructure or deployment-object
churn.

This document is a required addendum to the
[Hands-Off Rerun and v1 Release Design](2026-08-30-hands-off-rerun-v1-design.md).
If the two documents conflict on marker client proof, this narrower design
controls.
