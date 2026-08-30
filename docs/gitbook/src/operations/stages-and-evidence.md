# Stages & Evidence

`setup-cm` executes four core stages in order. Acquire has a real read-only
artifact probe and skips exact cached media. The complete SQL desired-state
probe is still being expanded, and MECM still has a hardcoded noncompliant
stage test. Do not describe a complete LabZ1 replay as a no-op until the
2026-08-30 v1 rerun plan is accepted.

Health is read-only and the accepted client stage already skips exact
compliance. Use [Current LabZ1 Status](./current-status.md) for the safe restart
boundary.

## Stage lifecycle

The intended contract for every stage is:

1. **Test** — check whether the desired state already exists.
2. **Apply** — perform the work only if the test reports `NotCompliant`.
3. **Verify** — confirm the resulting state matches the intent.
4. **Evidence** — write a structured JSON result to the run directory.

## The four stages

| Stage | Purpose | Key actions |
| --- | --- | --- |
| `Acquire` | Obtain and verify installation media. | Validates license, byte length, SHA-256, version, architecture, and publisher; downloads only missing or invalid artifacts from an approved source. |
| `Sql` | Install and configure SQL Server. | Installs Windows prerequisites, runs unattended SQL Server setup, configures network protocols, and verifies the service is running. |
| `Mecm` | Install MECM prerequisites and primary site. | Installs VC++ runtimes, ADK, WinPE add-on, ODBC Driver 18, downloads MECM prerequisites, runs unattended primary-site setup, and configures MP/DP roles. |
| `Health` | Validate the complete lab. | Checks SQL reachability, MECM site services, Management Point, Distribution Point, boundaries, test-client registration, and expected log files. |

## Evidence format

Each execution creates a unique directory under `evidenceRoot` (for example, `C:\ProgramData\SetupCm\artifacts\run-2026-08-03T14-22-10`). Every selected stage writes a file named `stage-<stage>.json`.

### Example `stage-Acquire.json`

```json
{
  "name": "Acquire",
  "state": "Succeeded",
  "startedAt": "2026-08-03T14:22:10.123Z",
  "finishedAt": "2026-08-03T14:25:44.567Z",
  "message": "All sources verified and cached."
}
```

### State values

| State | Meaning |
| --- | --- |
| `Succeeded` | The stage applied its work and verification passed. |
| `Skipped` | The stage test found the target already compliant; no work was performed. |
| `Failed` | The stage stopped. The `message` field identifies the immediate error. |

## Why evidence matters

- **Diagnosability** — every run gets its own evidence directory, including a result for each completed or failed stage.
- **Safe recovery** — an operator can correct the reported prerequisite and rerun only the affected stage rather than restart blindly.
- **Audit trail** — the evidence directory preserves what happened, when, and why, even after the VM is reset or reprovisioned.
