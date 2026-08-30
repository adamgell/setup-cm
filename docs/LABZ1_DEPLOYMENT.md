# LabZ1 Deployment Target

**Status:** Accepted v1 baseline — the first reviewed five-stage run refreshed
only stale authenticated evidence, and the immediate second run skipped all
five stages with zero object, installer, or policy action.

This is the current LabZ1 inventory. The earlier plan to provision
`LABZ1-CMCLIENT01` was not the path used for final acceptance and is retained
only in clearly labelled historical documents.

## Accepted identities

| Role | Current identity |
| --- | --- |
| Single-box SQL/MECM server, provider, MP, and DP | `LABZ1-CM01.test.gell.one` (VM 107) |
| Site | `LAB` — `LABZ1 Configuration Manager` |
| Database | `CM_LAB` |
| Only accepted test client | `RING0IVY24-01.test.gell.one` (VM 135) |
| Controller | `autopilot-docker` (CT 500) |

The two domain controllers, `LABZ1-DC01` (VM 111) and `LABZ1-DC02` (VM 115),
remain part of the isolated LabZ1 dependency set. Other domain-joined devices
remain unchanged and are not marker targets or v1 acceptance clients.

## Ownership boundary

- ProxmoxVEAutopilot owns VM lifecycle, OS deployment, network/storage, domain
  join, the controller, and Autopilot Agent.
- `setup-cm` owns Windows-side SQL/MECM desired state, client and site health,
  the bounded marker deployment, and sanitized evidence.
- Production, co-management, Patch My PC, reporting expansion, distributed
  roles, extra clients, and tenant integrations are outside v1.

## Completed milestones

1. [Phase 0 — Lab inventory and final acceptance](PHASE0-2026-08-29-LAB-INVENTORY.md)
   proves SQL, site roles, the typed client path, provider/SQL registration, and
   a fresh Health run.
2. [Phase 1 — Required marker application acceptance](PHASE1-2026-08-29-MARKER-DEPLOYMENT.md)
   proves one required application deployment is compliant exclusively on
   `RING0IVY24-01`.
3. Typed client-install implementation-plan Task 5 is complete. The preserved
   [2026-08-02 handoff](HANDOFF-2026-08-02-agent-mecm-client-install.md) is
   superseded historical context.
4. Acquire, SQL, MECM, Marker, and Health now use real desired-state probes.
   The authenticated marker-evidence implementation is complete in source.
5. At implementation commit `2d61457d918a49a6ef141da8684e4afed84c3ecf`, an
   exact Git archive passed 11 CM01 Windows tests with five target-only tests
   skipped, all 10 detector/publication tests on `RING0IVY24-01`, and the
   read-only provider pre-migration test. That provider probe found exactly
   three expected repairable states: missing evidence channel, approved
   predecessor detector, and pending client evidence. It performed no
   mutation.
6. [v1 hands-off acceptance](V1-ACCEPTANCE-2026-08-30.md) fixes execution
   source `33535c6a0e47bb0bb0f838eb990b0e9e9cb2ac95`, records the native
   Windows and post-migration provider gates, and proves one bounded
   stale-receipt refresh followed by a complete five-stage zero-action run,
   with no object or installer mutation.

## Safe restart point

1. Confirm VMs 107, 111, 115, and 135 plus CT 500 are running on their owner
   node.
2. Confirm controller health and current Agent check-ins for CM01 and
   `RING0IVY24-01`.
3. Use SSH, ConfigMgr provider queries, SQL inventory, and client state for
   deterministic validation; visual console acceptance is not required.
4. On the accepted source, run only the read-only `Health` stage unless a
   specific missing component has been proven. Run SQL/provider acceptance as
   the authorized domain operator; CM01's local Administrator is not the
   accepted SQL/SMS provider identity.
5. Verify the Phase 1 collection still has exactly one direct member and the
   marker assignment targets no other collection.

Do not replay bootstrap installers merely for new timestamps. Routine checks
remain read-only Health runs. The complete Acquire, SQL, MECM, Marker, and
Health workflow is accepted as a no-op from exact reviewed source and may be
used for a full confirmation or a proven owned-component repair. Follow the
safe command in the [v1 acceptance record](V1-ACCEPTANCE-2026-08-30.md) and
the operating boundary in the [runbook](RUNBOOK.md).

Capabilities intentionally excluded from this gate are tracked in
[Future projects](FUTURE-PROJECTS.md).
