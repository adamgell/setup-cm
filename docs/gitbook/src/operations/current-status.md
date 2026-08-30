# Current LabZ1 Status

The LabZ1 baseline and one-device marker deployment are accepted; the v1
hands-off full-rerun gate remains in progress.

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
timestamps: real no-op tests for Acquire and MECM are the remaining v1 work.

Production, co-management, Patch My PC, reporting expansion, distributed
roles, extra clients, tenant integrations, and client-wide security-policy
changes are outside v1.
