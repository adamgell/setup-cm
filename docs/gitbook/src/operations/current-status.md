# Current LabZ1 Status

The LabZ1 baseline and one-device marker deployment are accepted. All five
v1 stages have real desired-state probes, and applicable mutating stages have
bounded repair. The reviewed first exact-source run refreshed only stale
authenticated evidence; the immediate second run skipped all five stages with
zero action. Neither run invoked an installer or changed a ConfigMgr object.

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
- `docs/V1-ACCEPTANCE-2026-08-30.md` fixes the live-tested source, native and
  provider gate counts, two run IDs, and all acceptance hashes.
- `docs/HANDOFF-2026-08-02-agent-mecm-client-install.md` is preserved and
  prominently marked as superseded historical context.

## Safe restart

Confirm the LabZ1 resources, controller, Agents, provider, SQL inventory, and
one-device marker collection through deterministic remote checks. On the
currently accepted source, run only `Health` unless a specific missing
component is proven. Do not replay the full bootstrap solely for new
timestamps. The full Acquire, SQL, MECM, Marker, and Health workflow is now an
accepted no-op path from exact reviewed source, but routine validation should
remain the smaller read-only Health command.

Live-tested commit `33535c6a0e47bb0bb0f838eb990b0e9e9cb2ac95` passed 12
applicable CM01 Windows tests with five client-only skips, all 10
detector/publication tests on `RING0IVY24-01`, and the read-only post-migration
provider test. Formal run `20260830-203712-76f13d67` refreshed only the stale
authenticated receipt; run `20260830-204052-d3c589a6` then skipped all five
stages with zero action. Each produced 11 sanitized artifacts with all six
Health checks true. The marker evidence directory contains only the exact
target-owned receipt. See the [v1 acceptance record](./v1-acceptance.md) for
the hashes and BITS ambient-state note.

Production, co-management, Patch My PC, reporting expansion, distributed
roles, extra clients, tenant integrations, and client-wide security-policy
changes are outside v1.
