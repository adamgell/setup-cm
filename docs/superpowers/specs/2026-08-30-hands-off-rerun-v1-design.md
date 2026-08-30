# Hands-Off Rerun and v1 Release Design

**Status:** Approved execution design derived from the 2026-08-30 hands-off
rerun contract.

## Purpose

Turn the accepted LabZ1 demonstration into a repeatable v1 workflow. An
operator must be able to run the same source twice against the accepted lab,
have exact existing state reported as compliant without installer or
Configuration Manager churn, repair only explicitly owned missing state, and
receive fresh sanitized evidence from both runs.

## Fixed v1 boundary

The v1 acceptance topology is deliberately narrow:

- single-box site server, provider, Management Point, and Distribution Point:
  `LABZ1-CM01.test.gell.one`;
- site code `LAB`, site name `LABZ1 Configuration Manager`, and database
  `CM_LAB`;
- one accepted client: `RING0IVY24-01.test.gell.one`;
- one required marker application targeting that client only;
- no production, co-management, broad collections, extra clients, distributed
  roles, tenant integrations, or client-wide security-policy changes.

Virtual-machine lifecycle remains owned by ProxmoxVEAutopilot. `setup-cm`
owns only Windows-side SQL/MECM state, the bounded marker deployment, health
validation, and sanitized evidence. Unsupported topology or conflicting live
identity fails closed before mutation.

## Stage contract

Every stage keeps the existing four-step model:

1. **Test** performs a read-only desired-state probe.
2. **Apply** runs only when the probe reports a safely repairable difference.
3. **Verify** independently repeats the read-only probe.
4. **Evidence** records the state, bounded component results, timestamps, and
   source revision without source media, credentials, private URLs, raw policy,
   or raw log bodies.

The stage engine continues to represent an exact existing state as `Skipped`
with `Already compliant.` A successful repair is `Succeeded`; a conflict,
unsafe topology, unavailable required probe, or failed verification is
`Failed`. A successful installer exit never substitutes for verification.

Compliance probes return structured component results internally. A stage is
compliant only when every required component is compliant. A conflict is
distinct from an absent component: absence may be repairable, but conflicting
same-name objects, site identity, instance identity, or targeting always stops
the run.

## Acquisition design

`Test-SetupCmAcquire` uses `Get-SetupCmArtifactState` to evaluate every
configured source without downloading:

- required license acknowledgement;
- approved cache filename and presence;
- exact configured byte length and SHA-256;
- declared version and target architecture metadata;
- expected Authenticode publisher, including the configured executable inside
  ISO media.

The cryptographic hash and byte length bind the approved version/architecture
metadata to exact artifact bytes. Native file metadata is cross-checked when
the artifact exposes it; a format that cannot expose comparable native
metadata is not guessed from its filename. The configuration contract requires
`sizeBytes`, `version`, and `architecture` for non-template sources.

Apply calls the existing acquisition policy only for missing or invalid
artifacts. It never includes a source URI or vault path in evidence. A bad
cached blob is not silently trusted; it is reacquired only when an approved
source is available, otherwise the stage fails safely.

## SQL desired state

The SQL probe separates components so repair is minimal:

- required Windows features;
- configured SQL instance identity;
- SQL service running with automatic startup;
- setup-cm-owned service account and explicit sysadmin memberships;
- Microsoft ODBC Driver 18 before any database probe;
- both required VC++ runtime architectures;
- enabled static TCP 1433 and the setup-cm firewall rule;
- a real SQL connection and query against `master`;
- `CM_LAB` reachability when an installed `LAB` site already exists;
- configured SQL installation directory where Windows exposes it.

An absent instance permits setup. A different existing instance, site-owned
database mismatch, or target-host mismatch is a conflict and fails closed.
Stopped owned services, missing Windows features, ODBC Driver 18, missing VC++
runtime, network settings, and explicit sysadmin membership are repaired
independently. The SQL stage installs a missing ODBC provider before querying
the database, then refreshes the deferred database/sysadmin state in the same
Apply pass. No diagnostic tool such as `sqlcmd` is required: PowerShell 7 uses
its built-in `System.Data.Odbc` assembly with integrated authentication,
encrypted transport, and server-certificate validation.

## MECM desired state

The MECM probe uses the local SMS Provider and Windows state to require:

- one standalone primary site with code `LAB`, expected name, server, provider,
  and `CM_LAB` database;
- local Primary Site, Management Point, and Distribution Point roles;
- required SMS services in running/automatic state;
- ADK Deployment Tools, USMT, Windows PE, ODBC 18, and VC++ x64/x86 (ODBC is
  installed by SQL when absent and independently re-verified here);
- accessible provider and content library;
- active, non-obsolete `RING0IVY24-01` registration with the expected resource
  identity in both provider and SQL views.

An exact site skips all MECM media acquisition, prerequisite download, and
Setup.exe processing. Missing prerequisites can be repaired individually.
An absent site permits the existing bounded primary-site bootstrap. An
existing site/provider/database identity conflict never invokes setup. Role or
site repairs are performed only through supported ConfigMgr interfaces and are
verified independently.

## Health design

Health is always read-only. Its Test step writes a fresh `health.json` and its
stage result is `Skipped` when all checks pass. If any check fails, the no-op
Apply step is followed by an independent Verify, which fails the stage if the
state remains noncompliant. Health never acquires media or invokes an
installer.

## Marker acceptance design

Add `Invoke-SetupCmMarkerAcceptance` and a `Marker` stage. The command consumes
an explicitly enabled `markerAcceptance` configuration and reconciles only:

- the exact marker content source;
- one application and one deployment type with the reviewed VBScript detector;
- distribution to the single LabZ1 DP;
- one dedicated collection with one direct membership rule;
- one required, visible assignment;
- client policy/evaluation and server-side per-device compliance evidence.

Before any mutation it requires the exact site/server/client/resource identity,
one direct member, no assignment to another collection, exact payload and
detector hashes, and `labOnly: true`. Existing exact objects are reused.
Conflicting same-name objects, duplicate assignments, broad membership, or
hash drift fail closed. Unchanged content is not redistributed and exact
compliance is a successful no-op.

The tested VBScript detector remains the live detector because the accepted
lab enforces signed PowerShell scripts. The workflow does not weaken that
policy or add trust. Uninstall remains limited to `marker.json` and removes its
directory only when empty.

The fail-closed client proof transport, one-time detector migration, and
freshness/no-op rules are defined by the required
[Authenticated Marker Client Evidence Channel Design](2026-08-30-marker-client-evidence-channel-design.md).
That narrower design controls if the two documents differ on marker client
evidence.

## Evidence and source identity

Every run writes `run.json` plus stage/component artifacts. The accepted
workflow requires a 40-character source commit supplied through the bounded
entry point and records it in each acceptance artifact. Evidence serialization
recursively excludes sensitive key names and sanitizes credential-like text.

Marker evidence contains only structured identities, revisions, package/content
IDs and hashes, distribution state, exact collection membership, assignment
purpose, policy revisions, selected DP identity, bounded download/execution
results, marker hash, state-message names, per-device compliance, timestamps,
and source commit. It excludes raw logs, source URIs, credentials, generated
policy XML, and private configuration bodies.

## Two-run acceptance

The exact committed source archive and private configuration are staged on
CM01. The same unattended command runs twice:

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -Mode Unattended `
  -Stage Acquire,Sql,Mecm,Marker,Health `
  -SourceCommit $env:SETUPCM_SOURCE_COMMIT
```

The first run may repair bounded drift but may not reinstall an existing SQL
instance or MECM site. The second run must show all five stages skipped/already
compliant, no installer process, no content redistribution, no ConfigMgr object
or assignment creation, no membership change, and a fresh evidence bundle.
Provider, SQL, client, controller, and Proxmox identities are checked again
after both runs.

## Release design

Implementation is reviewed on one branch and one PR. Live acceptance evidence
is committed only in sanitized summary form. After merge, release-critical
tests and live read-only checks run at the exact merge commit. The live-tested
and merged tree IDs must match; otherwise the complete two-run acceptance is
repeated at the merge commit. The first release is the annotated `v1.0.0` tag,
created only after confirming that tag is absent locally and on `origin` and
verifying that it dereferences to the accepted merge commit. GitHub release
notes identify the supported boundary and evidence hashes, and the deployed
mdBook site is proven to represent the tagged source.

## Recovery and stop rules

Stop rather than repair when targeting broadens, identities disagree, an
existing installation conflicts, required media/credentials are unavailable,
or a repair would require VM reset, reinstall, trust/authentication weakening,
or unrelated user-file overwrite. Preserve clean historical branches/worktrees
unless every removal precondition is proven.
