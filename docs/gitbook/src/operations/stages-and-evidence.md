# Stages & Evidence

`setup-cm` executes five desired-state stages. Each reads current state before
deciding whether any owned action is necessary. The accepted LabZ1 two-run
release gate is still pending; see [Current LabZ1 Status](./current-status.md)
before operating the live site.

## Stage lifecycle

Every stage follows:

1. **Test** — collect structured, read-only component state.
2. **Apply** — run only for `NotCompliant`, and only for owned components.
3. **Verify** — independently collect state again.
4. **Evidence** — write a sanitized component artifact and stage result.

A `Compliant` test produces `Skipped` without invoking Apply. A `Conflict`
stops before mutation. Apply success is not acceptance: Verify must return
`Compliant`. Health has an empty Apply and is always read-only.

## The five stages

| Stage | Read-only test | Bounded apply |
| --- | --- | --- |
| `Acquire` | Verifies every configured artifact's license, byte length, SHA-256, version, architecture, publisher, and cache identity. | Acquires only missing or invalid artifacts under the approved source policy. |
| `Sql` | Verifies Windows prerequisites, instance and services, startup state, TCP/listener/firewall, query reachability, owned configuration, VC++ x64/x86, and conditional `CM_LAB` reachability. | Installs an absent instance or repairs only owned missing components; conflicting instance identity fails closed. |
| `Mecm` | Verifies site/provider/database/role identity, services, prerequisites, ADK/WinPE/ODBC/VC++, content library, MP/DP, and the active non-obsolete client. | Installs an absent site or repairs only owned missing prerequisites or roles; an exact site never opens media or reruns setup. |
| `Marker` | Verifies the fixed LabZ1 boundary, source and detector hashes, application, deployment type, content, distribution, one-device direct collection, required assignment, and per-device compliance. | Reconciles only the fixed marker chain and requests policy/evaluation only when client or server compliance is missing. |
| `Health` | Re-reads SQL, MECM, MP, DP, and active-client state. | None. |

## Marker safety contract

Marker acceptance is fixed to:

- site `LAB` on `LABZ1-CM01.test.gell.one`;
- target `RING0IVY24-01.test.gell.one`, resource `16777219`;
- application `Setup-CM Phase 1 Marker`;
- deployment type `Install Setup-CM Phase 1 Marker`;
- collection `Setup-CM Phase 1 Marker - RING0IVY24-01 Only`;
- marker SHA-256
  `3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254`.

The collection must have exactly one direct rule and one member, both for the
accepted resource. No marker assignment may target another collection.
Same-name conflicts, unexpected rules or files, broader membership, another
assignment, or hash drift are `Conflict`, not repair opportunities.

## Stage result files

Every selected stage writes `stage-<stage>.json`:

```json
{
  "name": "Marker",
  "state": "Skipped",
  "startedAt": "2026-08-30T06:00:00.0000000Z",
  "finishedAt": "2026-08-30T06:00:05.0000000Z",
  "message": "Already compliant."
}
```

| State | Meaning |
| --- | --- |
| `Succeeded` | Apply ran and independent Verify returned `Compliant`. |
| `Skipped` | Test returned `Compliant`; Apply did not run. |
| `Failed` | Test found conflict, Apply failed, or Verify did not return `Compliant`. |

## Component evidence

| File | Contents |
| --- | --- |
| `run.json` | Run ID, UTC start, and exact source commit when provided. Marker runs require it. |
| `acquire-state.json` | Artifact component state without source URI or vault location. |
| `acquisition.json` | Bounded identities and hashes for every artifact evaluated during Acquire Apply, distinguishing reused `Verified` entries from `AcquiredAndVerified` entries. |
| `sql-state.json` | SQL component state and reasons. |
| `mecm-state.json` | MECM component state and reasons. |
| `marker-state.json` | Application/DT revisions, content/package/distribution, collection and membership, assignment/policy, projected client detection fields, per-device server compliance, evaluated time, and exact source commit. |
| `health.json` | Fresh Boolean results for each read-only health check. |

Marker provider state proves the exact detector and per-device compliance row.
Release acceptance must independently corroborate the client's application
revision, installed/evaluation state, marker bytes and SHA-256, and last-write
time; a server projection is not a substitute for direct client evidence.

## Sanitization boundary

Evidence serialization recursively removes sensitive keys and redacts
credential-like values and private locations in strings. Never add source
URLs, vault paths, credentials, tokens, private keys, generated policy XML, raw
configuration, raw log bodies, or installer media to an evidence bundle.

## Interpreting a no-op run

A successful process exit is not sufficient. A genuine second-run no-op has:

- all five stage results `Skipped`;
- a fresh run ID and timestamps tied to the same exact source commit;
- all component states `Compliant`;
- no installer process, object creation, membership change, deployment
  creation, policy repair, or content redistribution;
- the same ConfigMgr identities and exact client marker hash;
- all Health values `true`.
