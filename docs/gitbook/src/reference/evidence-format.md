# Evidence Format

Each invocation creates a unique directory under `evidenceRoot`. Evidence is
structured for comparison across reruns and sanitized before serialization.

## Run metadata

`run.json` contains:

```json
{
  "runId": "20260830-060000-1a2b3c4d",
  "startedAt": "2026-08-30T06:00:00.0000000Z",
  "sourceCommit": "0123456789abcdef0123456789abcdef01234567"
}
```

`sourceCommit` is present when supplied through `-SourceCommit` or
`SETUPCM_SOURCE_COMMIT`. Any run containing `Marker` requires a full
40-character commit and records the validated lowercase value in both
`run.json` and `marker-state.json`.

## Stage result schema

Every selected stage writes `stage-<stage>.json`:

```json
{
  "name": "Acquire | Sql | Mecm | Marker | Health",
  "state": "Succeeded | Skipped | Failed",
  "startedAt": "ISO 8601 UTC",
  "finishedAt": "ISO 8601 UTC",
  "message": "string"
}
```

`Skipped` means Test returned `Compliant` and Apply was not invoked.
`Succeeded` means Apply ran and independent Verify returned `Compliant`.
`Failed` covers a conflict, an Apply error, or failed verification.

## Component artifacts

| File | Produced by | Purpose |
| --- | --- | --- |
| `acquire-state.json` | Acquire Test/Verify | Per-artifact compliance, reason, size, hash, version, and architecture. |
| `acquisition.json` | Acquire Apply | Bounded identity and hash metadata for every artifact evaluated during Apply, distinguishing reused `Verified` entries from `AcquiredAndVerified` entries. |
| `sql-state.json` | SQL Test/Verify | Overall state plus SQL component state and reasons. |
| `mecm-state.json` | MECM Test/Verify | Overall state plus site, role, prerequisite, service, content-library, and client components. |
| `marker-state.json` | Marker Test/Verify | Exact boundary, payload, application/DT, content/distribution, collection/member, assignment/policy, client projection, and per-device server compliance. |
| `health.json` | Health Test/Verify | Fresh Boolean read-only checks in deterministic key order. |
| `client-install.json` | Typed client command | Sanitized client-install evidence for the separate manifest workflow. |

Component entries use `Compliant`, `NotCompliant`, or `Conflict` and include
a bounded reason. Private source locations and source bytes are excluded.

## Marker corroboration

`marker-state.json` records ConfigMgr object identities and revisions, content
and package identity, reviewed hashes, DP state, exact collection membership,
assignment intent, policy revision, projected client state, and the exact
per-device server compliance row. Its `evaluatedAt` and the corresponding
`stage-Marker.json` start/end times establish freshness.

Release acceptance separately checks the client application revision,
installed/evaluation/error state, marker existence and SHA-256, and marker
last-write time over an authenticated management channel. Store only the
bounded results and hashes, never raw client logs or policy.

## Sanitization

Serialization recursively omits password, secret, token, authorization,
credential, private-key, source-URI, vault-path, SAS, and API-key fields. It
also redacts credential assignments, bearer values, URLs, and UNC paths
embedded in otherwise safe strings.

Do not put any of the following in source, evidence, commits, PR output, or
release notes:

- credentials, recovery material, keys, certificates, tokens, or SAS values;
- private configuration or source URLs;
- generated unattended files or policy XML;
- raw log bodies or installer media.

## Retention

Evidence is not removed automatically. Preserve failed runs until resolved.
For release acceptance, retain both complete run directories, their archive
hashes, and the final independently verified client/server summary. The second
bundle must be fresh even though every stage is `Skipped`.
