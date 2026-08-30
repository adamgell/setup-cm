# Phase 0 — Lab inventory and final acceptance

**Operator date:** 2026-08-29

**Final evidence time:** 2026-08-30 02:51 UTC

**Status:** Accepted — the isolated single-box MECM lab baseline is complete
and ready for hands-off use.

This is the authoritative restart and acceptance record for the LabZ1
`setup-cm` baseline. It contains no credentials, tokens, private URLs, raw log
bodies, or generated configuration content.

The follow-on [Phase 1 marker record](PHASE1-2026-08-29-MARKER-DEPLOYMENT.md)
is also accepted. It adds one required, lab-only application deployment without
changing this baseline identity.

The later [v1 hands-off acceptance](V1-ACCEPTANCE-2026-08-30.md) supersedes
the historical apply-only rerun limitation: it proves the complete five-stage
workflow twice from exact source with every compliant stage skipped, zero
mutation actions, and zero installers.

## Accepted scope

The accepted target is one isolated single-box MECM lab:

- `setup-cm` owns Windows-side SQL/MECM configuration, health validation,
  client validation, and sanitized evidence.
- `ProxmoxVEAutopilot` owns VM lifecycle, Windows provisioning, networking,
  storage, domain joining, and the Autopilot Agent.
- The baseline includes SQL Server, one MECM primary site, Management Point,
  Distribution Point, and one dedicated test client.
- Co-management, Patch My PC, reporting, production deployment, and a
  distributed MECM topology remain out of scope.

## Resolved target identity

Live Proxmox, controller, Windows, ConfigMgr provider, and SQL inventory agree
on the acceptance pair:

| Role | Accepted identity |
| --- | --- |
| MECM server / MP / DP | `LABZ1-CM01.test.gell.one` (VM 107) |
| Site | `LAB` — `LABZ1 Configuration Manager` |
| Database | `CM_LAB` |
| Test client | `RING0IVY24-01.test.gell.one` (VM 135) |

The older `LABZ1-CMCLIENT01` documentation does not describe the live
acceptance client and is superseded for this baseline.

## Source and repository baseline

| Check | Accepted result |
| --- | --- |
| Accepted execution source | `99e0b9a4a82cf722e130ddcfac2481a6362b93c9` |
| Exact source archive | 97,319 bytes; SHA-256 `0ba83fc48c5414a2ffa9e7ac80c610630996d51cc3f02d7acd5903ea4aa6b6e0` |
| CM01 exact-source root | `C:\ProgramData\SetupCm\staged\99e0b9a-20260829T2240Z` |
| Preflight | `Ready=true`, no missing requirements, topology `single-box` |
| `setup-cm` unit tests | PASS — 55 passed, 0 failed |
| Autopilot Agent contract tests | PASS — one pre-existing nullable warning |
| Controller queue tests | PASS — 2 passed, 51 deselected |
| mdBook build | PASS |

The archive was produced from `git archive 99e0b9a`, transferred through a
temporary lab-only HTTP listener, and verified by SHA-256 on each Windows
target. The temporary listener was stopped immediately after transfer.
This acceptance record is a documentation-only successor to the execution
source; no executable source changed after `99e0b9a` during acceptance.
The pve2 transfer copy and the Mac-local temporary archive were removed after
both Windows targets completed their hash checks; the accepted guest copies and
evidence were retained for reproducibility.

## Live infrastructure inventory

The two-node Proxmox cluster is quorate. The following resources are owned by
`pve2` and were running at final acceptance:

| Resource | ID | Final state |
| --- | ---: | --- |
| `LABZ1-CM01` | VM 107 | running |
| `LABZ1-DC01` | VM 111 | running |
| `LABZ1-DC02` | VM 115 | running |
| `RING0IVY24-01` | VM 135 | running |
| `autopilot-docker` | CT 500 | running |

The controller returned `{"ok":true}` from `/healthz` and reports release
`2026.08.48` at source revision `8ba1c80`. Both CM01 and the test client report
Autopilot Agent `2026.8.48.0` with current check-ins. The client work item being
claimed and completed is direct proof that its signed Agent supports
`setup_cm_client_install`.

## Bootstrap stage lineage

The retained CM01 evidence includes successful bootstrap stages:

| Stage | Evidence run | Result |
| --- | --- | --- |
| Acquire | `20260802-005500-a26039ce` | Succeeded — verified compliant |
| SQL | `20260801-234355-49212d28` | Succeeded — verified compliant |
| MECM | `20260802-010048-f1fd1688` | Succeeded — verified compliant |

The historical Phase 0 runner treated `Acquire` and `Mecm` as apply-only stages,
so a whole-run replay could reprocess installation media instead of acting as a
read-only acceptance check. The v1 runner replaces that limitation with the
Test/Apply/Verify contract: it performs read-only desired-state probes before
any bounded Apply repair. The retained successful bootstrap artifacts, current
exact-head preflight, independent live inventory, and fresh exact-head Health
stage remain the accepted Phase 0 restart evidence rather than an instruction
to replay the historical bootstrap solely for newer timestamps.

## Fresh typed client acceptance

The exact source archive was staged on the client at
`C:\ProgramData\SetupCm\setup-cm-99e0b9a.zip` and verified against the accepted
SHA-256 before queueing.

The deployment has passwordless local web authentication disabled. No auth
setting was weakened and no database row was inserted manually. Instead, the
deployed controller's `SetupCmClientInstallBody` model and
`queue_setup_cm_client_install` handler were invoked operator-locally inside the
controller container. This preserved the deployed Pydantic validation and work
queue implementation; the signed Windows Agent then claimed and completed the
work through its normal Agent API.

| Typed work evidence | Result |
| --- | --- |
| Work item | `c6098efd-7455-4b54-82be-c9e1e0668b62` |
| Agent / VM | `agent-ring0ivy24-01` / VM 135 |
| Kind | `setup_cm_client_install` |
| Created | 2026-08-30 02:49:58 UTC |
| Claimed | 2026-08-30 02:50:07 UTC |
| Completed | 2026-08-30 02:50:13 UTC |
| Final controller state | `complete`, no error, empty stderr |
| Archive hash returned by Agent | Exact match |

The client wrote fresh sanitized evidence under run
`20260830-025010-500e3d96`:

- stage `Client`: `Skipped` — `Already compliant.`
- site code: `LAB`
- Management Point: `LABZ1-CM01.test.gell.one`
- `CcmExec`: running, automatic
- `AutopilotAgent`: running, automatic
- installed product version: `5.00.9141.1000`
- reported client version: `5.00.9141.1011`
- `EventLastUsedMP`: `labz1-cm01.test.gell.one`
- sanitized evidence includes `ccmsetup.log` and
  `ClientIDManagerStartup.log`; raw log bodies were not copied into this record.

This completed typed client-install implementation-plan Task 5. Any older plan
or handoff statement that says Task 5 is pending is superseded by this evidence.

## Final server acceptance

After the fresh client action, CM01 ran `Health` from the exact accepted source.
Evidence run `20260830-025138-89eba1b2` completed at 2026-08-30 02:51:39 UTC:

| Health check | Result |
| --- | --- |
| SQL | true |
| Management Point | true |
| Distribution Point | true |
| Client | true |
| Client registration | true |

The stage result is `Succeeded` with message `Verified compliant.` The evidence
directory contains only `health.json` and `stage-Health.json`.

Independent bounded queries were run after the client action. Both the
ConfigMgr provider (`SMS_R_System`) and `CM_LAB.dbo.v_R_System` returned the
same row:

| Name | Resource ID | Active | Obsolete | Client | Version |
| --- | ---: | ---: | ---: | ---: | --- |
| `RING0IVY24-01` | 16777219 | 1 | 0 | 1 | `5.00.9141.1011` |

## Hands-off acceptance checklist

- [x] Proxmox cluster and all five LabZ1 resources are running.
- [x] Controller health, release, Agent identities, and current check-ins are
  confirmed.
- [x] The accepted `setup-cm` source revision and archive hash are fixed and
  reproducible.
- [x] Historical Acquire, SQL, and MECM bootstrap stages have successful
  evidence.
- [x] Current exact-head preflight reports ready for the single-box topology.
- [x] A fresh typed client work item was claimed and completed by the selected
  signed Agent.
- [x] Fresh client evidence proves the installed client is already compliant
  with site `LAB` and the expected MP.
- [x] ConfigMgr provider and SQL inventory independently prove active,
  non-obsolete client registration.
- [x] The post-client exact-head Health artifact has every required check true.
- [x] No VM reset, guest reinstall, auth weakening, direct database insertion,
  or secret capture was used.

## Safe restart point

The single-box MECM baseline itself requires no further installation work. For
a later validation session:

1. Confirm the five Proxmox resources above are running on their owner node.
2. Confirm `/healthz` and the two Agent check-ins are current.
3. Use SSH, provider queries, SQL inventory, and bounded client/controller state
   for deterministic checks; no visual-console acceptance is required.
4. Rerun only the current exact-head `Health` stage unless there is concrete
   evidence that a bootstrap component is missing.
5. Treat co-management, third-party patching, reporting, and production
   topology as separate future phases.
6. Confirm the [Phase 1 marker acceptance](PHASE1-2026-08-29-MARKER-DEPLOYMENT.md)
   remains exclusive to `RING0IVY24-01`.

Any earlier local Agent MECM client handoff draft is historical context only.
Its branch, version, and Task 5 status are stale and are superseded by this
record.
