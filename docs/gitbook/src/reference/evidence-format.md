# Evidence Format

Each run creates a unique directory under `evidenceRoot`. The directory name includes the run timestamp.

## Run metadata

Every run writes `run.json` with its run ID and UTC start time. Accepted and
release-critical runs set `SETUPCM_SOURCE_COMMIT` to the full 40-character Git
commit before invocation; the validated lowercase value is recorded as
`sourceCommit`.

## Stage result files

Every selected stage writes `stage-<stage>.json`.

### Schema

```json
{
  "name": "string",
  "state": "Succeeded | Skipped | Failed",
  "startedAt": "ISO 8601 UTC",
  "finishedAt": "ISO 8601 UTC",
  "message": "string"
}
```

### Example

```json
{
  "name": "Mecm",
  "state": "Failed",
  "startedAt": "2026-08-03T14:22:10.123Z",
  "finishedAt": "2026-08-03T14:35:44.567Z",
  "message": "SHA-256 mismatch for mecm.iso. Expected a1b2..., got c3d4..."
}
```

## Acquisition metadata

The `Acquire` stage also writes `acquisition.json` in the run directory. It
records bounded artifact identity, SHA-256, and verification time. Source URIs,
vault paths, and source bytes are excluded.

## Client evidence

The `Client` stage writes sanitized log tails and local state to the run
directory. Evidence serialization recursively omits password, secret, token,
authorization, credential, private-key, source-URI, and vault-path fields and
redacts credential-like values embedded in strings.

## Retention

Evidence directories are not automatically cleaned up. Operators should retain the first successful `Health` run as the baseline proof of a working lab, and preserve failed-run directories until the issue is resolved.
