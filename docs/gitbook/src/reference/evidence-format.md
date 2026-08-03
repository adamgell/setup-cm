# Evidence Format

Each run creates a unique directory under `evidenceRoot`. The directory name includes the run timestamp.

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

The `Acquire` stage also writes `acquisition.json` in the run directory. It records the verified artifact path, SHA-256, source URI, and verification timestamp for each downloaded or cached file.

## Client evidence

The `Client` stage writes sanitized log tails and local state to the run directory. Raw passwords and sensitive values are redacted before evidence is persisted.

## Retention

Evidence directories are not automatically cleaned up. Operators should retain the first successful `Health` run as the baseline proof of a working lab, and preserve failed-run directories until the issue is resolved.
