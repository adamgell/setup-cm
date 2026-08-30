# Phase 1 — Required marker application acceptance

**Operator date:** 2026-08-29

**Final evidence time:** 2026-08-30 04:02 UTC

**Status:** Accepted — the required lab-only marker application is installed
and compliant exclusively on `RING0IVY24-01`.

This record extends the accepted Phase 0 LabZ1 baseline. It contains no
credentials, tokens, private URLs, raw log bodies, or generated client policy.
All live checks were performed over SSH and bounded Configuration Manager
provider queries; no VNC or visual acceptance was used.

## Accepted scope and safety boundary

- Application: `Setup-CM Phase 1 Marker`
- Deployment purpose: Required install, visible in Software Center
- Only target: `RING0IVY24-01` (resource ID `16777219`)
- Marker: `C:\ProgramData\SetupCm\Phase1\marker.json`
- Expected marker SHA-256:
  `3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254`
- Uninstall removes only `marker.json` and removes its directory only when the
  directory is otherwise empty.
- No client-setting, execution-policy, certificate-trust, co-management,
  authentication, VM-lifecycle, or other-device change was made.

## Tested payload contract

The repository now carries the install, uninstall, PowerShell detector oracle,
and live VBScript detector under `scripts/marker/`.

The marker contains exactly these UTF-8 bytes, with no byte-order mark or final
newline:

```json
{"application":"Setup-CM Phase 1 Marker","version":"1.0.0","scope":"lab-only"}
```

Test-first evidence:

| Suite | Accepted result |
| --- | --- |
| Marker payload unit tests | PASS — 5 passed, 0 failed |
| Windows VBScript detector integration | PASS — 3 passed, 0 failed |

The Windows integration suite proves that the live detector emits `Installed`
only for the exact expected hash and emits nothing for tampered or missing
markers.

## Configuration Manager objects

| Object | Accepted identity |
| --- | --- |
| Application | `Setup-CM Phase 1 Marker`; CI `16777524`; revision 3 |
| Application model | `ScopeId_DA24E410-B098-424D-B335-AF69DBB32CD9/Application_fb49968f-4669-436c-9739-d4835689be6d` |
| Deployment type | `Install Setup-CM Phase 1 Marker`; CI `16777525`; revision 2 |
| Content | `Content_8b2f7ca4-c603-4079-a7f4-58206c7d4064`; package `LAB00008` |
| Device collection | `Setup-CM Phase 1 Marker - RING0IVY24-01 Only`; `LAB00016` |
| Assignment | `16777217` |

The application content source is
`C:\ProgramData\SetupCm\Phase1MarkerContent` on CM01. The three distributed
payload files were byte-hash compared with their repository copies before the
application was created.

The single LabZ1 DP reported one successful distribution, zero errors, zero in
progress, and zero unknown for package `LAB00008` before the assignment was
created.

## Exclusive-target proof

The safety gate was evaluated before application creation, before assignment,
after assignment, after the detector revision, and during final acceptance.

| Gate | Accepted result |
| --- | --- |
| Collection member count | 1 |
| Member | `RING0IVY24-01` |
| Member resource ID | `16777219` |
| Direct-rule count | 1 |
| Direct-rule resource ID | `16777219` |
| Marker application assignment count | 1 |
| Assignment target collection | `LAB00016` |

The assignment is enabled with install intent (`DesiredConfigType=1`), Required
purpose (`OfferTypeID=0`), and visible user experience (`NotifyUser=true`,
`UserUIExperience=true`).

Two historical one-device marker collections (`LAB00014` and `LAB00015`) and
the historical undeployed application `LABZ1 MECM Marker Application` were
audited and left unchanged. Neither has an assignment for the accepted Phase 1
application.

## Client policy and deployment proof

The initial application policy arrived normally, but its PowerShell detection
script was rejected with `0x87D00327` because the lab requires signed
PowerShell scripts. There was no trusted code-signing certificate on CM01 or
the client. Instead of weakening the client-wide policy or adding certificate
trust, only the deployment type detector was revised to the tested VBScript
SHA-256 detector.

CM01 generated revision-3 policy at 2026-08-30 03:53:37 UTC. The client direct
policy request returned 0 and advanced both marker policy objects to version
`2.00`; machine-policy and application-deployment evaluations also returned 0.

Client logs then proved the complete path:

1. Revision-2 deployment-type detection correctly reported the marker absent.
2. Location Services selected
   `LABZ1-CM01.test.gell.one` as a subnet-local Distribution Point.
3. CAS downloaded `Content_8b2f7ca4-c603-4079-a7f4-58206c7d4064.1`, verified
   its content hash, and cached it at `C:\Windows\ccmcache\2`.
4. AppEnforce started the install as `SYSTEM`, ran
   `Install-SetupCmPhase1Marker.ps1`, and received process exit code 0.
5. Post-install detection discovered the application and completed enforcement
   in three seconds.
6. Client state messages recorded `APP_CI_ENFORCEMENT_SUCCEEDED` and
   `APP_CI_PRESENT` for application revision 3 and deployment-type revision 2.

Fresh client state at 2026-08-30 03:57:01 UTC:

| Check | Accepted result |
| --- | --- |
| Application revision | 3 |
| Install state | `Installed` |
| Evaluation state | 1 |
| Resolved state | `Installed` |
| Client error code | 0 |
| Marker exists | true |
| Marker SHA-256 exact match | true |

A final application re-evaluation at 2026-08-30 04:01:27 UTC advanced the
client `LastEvalTime` and retained revision 3, `Installed`, error code 0, and
the exact marker hash.

## Independent server compliance

After the client sent its state messages, the site provider returned exactly
one `SMS_AppDeploymentAssetDetails` row for assignment `16777217`:

| Field | Accepted value |
| --- | --- |
| Machine | `RING0IVY24-01` |
| Machine ID | `16777219` |
| Collection | `LAB00016` |
| Application revision | 3 |
| Deployment type CI | `16777525` |
| Compliance state | 1 |
| Enforcement state | 1000 |
| Installed state | 2 |

This provider row is the independent server-side acceptance gate; aggregate
deployment summarization had not yet populated when the per-device row already
reported compliant and enforcement succeeded.

## Operational notes

- Configuration Manager console module `5.2509.1036.1200` under PowerShell 7
  rejected `-TimeBaseOn LocalTime` after submitting a deadline earlier than its
  start time. `SMSProv.log` identified the exact provider validation failure.
  Omitting that optional parameter created the single intended assignment; a
  duplicate was never created.
- The client schedule trigger accepted the initial request but did not start a
  new retrieval cycle. The supported `SMS_Client.RequestMachinePolicy(0)` and
  `EvaluateMachinePolicy()` methods produced the current policy and were used
  before application evaluation.
- The temporary CM01 Windows-integration staging directory was removed after
  the detector passed and the deployment type embedded the tested script. The
  application content source and installed marker remain in place.

## Rollback boundary

No rollback was performed because the marker is the accepted desired state.
The application has an explicit uninstall command. A future rollback should
use Configuration Manager against the same one-member collection, then verify
all of the following before removing any server object:

1. `marker.json` is absent from `RING0IVY24-01`.
2. No unrelated file under `C:\ProgramData\SetupCm\Phase1` was removed.
3. The uninstall assignment reports success for resource `16777219`.
4. No application assignment targets another collection or device.

Do not weaken the lab's signed-PowerShell client setting as part of rollback.
