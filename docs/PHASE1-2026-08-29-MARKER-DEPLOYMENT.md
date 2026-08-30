# Phase 1 — Required marker application acceptance

**Operator date:** 2026-08-29

**Final evidence time:** 2026-08-30 04:37 UTC

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
- Accepted embedded VBScript detector SHA-256:
  `DFDDD8489C137940A06A4DD18630B0618E0BE5868559366D056352A0A88505AC`
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
| Windows VBScript detector integration | PASS — 4 passed, 0 failed |

The Windows integration suite proves that the live detector emits `Installed`
only for the exact expected hash and emits nothing for tampered or missing
markers. It also proves that putting the expected hash in the marker directory
name cannot create a false positive for tampered marker bytes.

## Configuration Manager objects

| Object | Accepted identity |
| --- | --- |
| Application | `Setup-CM Phase 1 Marker`; CI `16777528`; revision 4 |
| Application model | `ScopeId_DA24E410-B098-424D-B335-AF69DBB32CD9/Application_fb49968f-4669-436c-9739-d4835689be6d` |
| Deployment type | `Install Setup-CM Phase 1 Marker`; CI `16777529`; revision 3 |
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

Code review then identified that the revision-2 detector searched all
`certutil` output for the expected hash. A marker directory containing that
hash could therefore make tampered bytes appear installed. The regression was
reproduced on CM01, pinned by a failing Windows integration test, and corrected
by comparing complete normalized output lines. Provider XML independently
proved that deployment-type revision 3 embeds the exact reviewed detector
bytes.

The client retrieved application revision 4 and deployment-type revision 3.
At 2026-08-30 04:31:35 UTC, detection reported the existing exact marker as
installed without running the installer or changing the marker last-write
time. The client sent `APP_CI_PRESENT` state messages for application revision
4, deployment-type revision 3, and required-application revision 4.

Fresh client state after the corrected-detector evaluation:

| Check | Accepted result |
| --- | --- |
| Application revision | 4 |
| Install state | `Installed` |
| Evaluation state | 1 |
| Resolved state | `Installed` |
| Client error code | 0 |
| Marker exists | true |
| Marker SHA-256 exact match | true |

The marker last-write time remained `2026-08-30 03:56:52 UTC`, independently
proving that the revision-4 evaluation was detection-only rather than another
installer execution.

## Independent server compliance

After the client sent its state messages, the site provider returned exactly
one `SMS_AppDeploymentAssetDetails` row for assignment `16777217`:

| Field | Accepted value |
| --- | --- |
| Machine | `RING0IVY24-01` |
| Machine ID | `16777219` |
| Collection | `LAB00016` |
| Application revision | 4 |
| Deployment type CI | `16777529` |
| Compliance state | 1 |
| Enforcement state | 1001 — succeeded, already installed |
| Installed state | 2 |

This provider row is the independent server-side acceptance gate; aggregate
deployment summarization had not yet populated when the per-device row already
reported compliant. Enforcement state `1001` is the expected no-op result after
the corrected detector found an already-installed marker, per Microsoft's
[Configuration Manager state-message reference](https://learn.microsoft.com/en-us/intune/configmgr/core/plan-design/hierarchy/state-messages);
the original install reported enforcement state `1000`.

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
- Code review found and CM01 reproduced a whole-output substring false positive
  in the first VBScript detector. Exact-line matching fixed the root cause; the
  new path-confusion regression failed before the fix and passed afterward.
- The temporary CM01 Windows-integration, review-reproduction, and SQL-query
  staging files were removed after verification. The application content
  source and installed marker remain in place.

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
