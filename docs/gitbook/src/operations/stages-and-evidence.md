# Stages & Evidence

`setup-cm` executes four stages in order. Each stage is idempotent: it tests whether it is already compliant, applies only the required work, and verifies the result.

## Stage lifecycle

Every stage follows the same pattern:

1. **Test** — check whether the desired state already exists.
2. **Apply** — perform the work only if the test reports `NotCompliant`.
3. **Verify** — confirm the resulting state matches the intent.
4. **Evidence** — write a structured JSON result to the run directory.

## The four stages

| Stage | Purpose | Key actions |
| --- | --- | --- |
| `Acquire` | Obtain and verify installation media. | Downloads or validates cached SQL Server, MECM, ADK, WinPE, ODBC, and VC++ redistributable installers. Verifies SHA-256 and Authenticode signatures. |
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
