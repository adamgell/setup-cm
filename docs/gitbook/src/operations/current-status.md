# Current LabZ1 Status

The LabZ1 baseline and one-device marker deployment are accepted. All five
release-candidate stages now have real desired-state probes, and applicable
mutating stages have bounded repair. The reviewed two-run live gate, merge, and
v1 publication remain in progress.

## Accepted current state

| Role | Identity |
| --- | --- |
| MECM server, provider, MP, and DP | `LABZ1-CM01.test.gell.one` |
| Site and database | `LAB` / `CM_LAB` |
| Only accepted client | `RING0IVY24-01.test.gell.one` |
| Marker application | `Setup-CM Phase 1 Marker` |

The older `LABZ1-CMCLIENT01` plan is obsolete for current acceptance. Typed
client-install Task 5 completed through the signed Autopilot Agent path.

## Accepted evidence

- The repository root's `docs/PHASE0-2026-08-29-LAB-INVENTORY.md` is the
  authoritative baseline and safe-restart record.
- `docs/PHASE1-2026-08-29-MARKER-DEPLOYMENT.md` proves the required marker is
  compliant exclusively on `RING0IVY24-01`.
- `docs/HANDOFF-2026-08-02-agent-mecm-client-install.md` is preserved and
  prominently marked as superseded historical context.

## Safe restart

Confirm the LabZ1 resources, controller, Agents, provider, SQL inventory, and
one-device marker collection through deterministic remote checks. On the
currently accepted source, run only `Health` unless a specific missing
component is proven. Do not replay the full bootstrap solely for new
timestamps. The release-candidate Acquire, SQL, MECM, Marker, and Health probes
must pass review and then be run twice from one exact source commit before the
full workflow becomes the accepted restart path.

The authenticated marker-evidence implementation is complete in source. At
implementation commit `2d61457d918a49a6ef141da8684e4afed84c3ecf`, an exact
Git archive passed 11 CM01 Windows tests with five target-only tests skipped,
all 10 detector/publication tests on `RING0IVY24-01`, and the isolated read-only
provider pre-migration test. That provider gate reported only the expected
`EvidenceChannel/Missing`, `DeploymentType/ApprovedDetectorUpgrade`, and
`Client/ClientEvidencePending` states and invoked no mutation adapter.

The live channel creation, approved detector migration, post-migration
zero-action provider gate, and two complete workflow runs are still pending.
Run CM01 SQL/provider acceptance as the authorized domain operator; the local
Administrator identity is not the accepted secured SQL/SMS provider context.
These development gates do not replace the final two-run evidence.

Production, co-management, Patch My PC, reporting expansion, distributed
roles, extra clients, tenant integrations, and client-wide security-policy
changes are outside v1.
