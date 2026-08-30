# Recovery & Resume

A failed stage does not require a full restart. The stage engine and evidence format are designed for safe, targeted recovery.

## When to resume vs. stop

| Scenario | Recommended action |
| --- | --- |
| A stage fails because a prerequisite is missing or misconfigured. | Correct the prerequisite, then rerun the failed stage and later dependent stages. |
| A stage fails because media is corrupt or the wrong version. | Replace the media in the cache or vault, update the configuration if necessary, then rerun. |
| A stage reports `Conflict`. | Stop. Reconcile identity or scope outside the automated repair path; do not weaken the gate. |
| Marker collection, member, resource, or assignment identity differs. | Stop before mutation and preserve provider/client evidence. Never broaden membership to continue. |
| A stage fails partway through and the system state is ambiguous. | Stop, preserve evidence, and hand off to the provisioning owner. Do not reset or reinstall as a setup-cm recovery action. |
| The `Health` stage fails after a successful `Mecm` stage. | Investigate the specific health check in the evidence, correct the issue, then rerun `Health` alone. |

## How to resume

1. Preserve the evidence directory from the failed run.
2. Review the failed `stage-<name>.json` and corresponding component-state
   artifact to identify the immediate error.
3. Correct the stated prerequisite, source, configuration, or host condition.
4. Rerun the failed stage and any later dependent stages:

   ```powershell
   pwsh ./scripts/Invoke-SetupCm.ps1 `
     -ConfigPath $env:SETUPCM_CONFIG `
     -Mode Unattended `
     -Stage Sql,Mecm,Marker,Health `
     -SourceCommit $env:SETUPCM_SOURCE_COMMIT
   ```

## What the stage engine protects

- **Idempotency** — if a stage test reports `Compliant`, the stage is skipped entirely.
- **No partial verify** — if `Apply` throws, `Verify` does not run.
- **Evidence preservation** — both successful and failed stage results are written before the engine returns or throws.
- **Source pinning** — any Marker run rejects a missing or abbreviated commit.
- **Conflict boundary** — unsupported topology, target, or same-name object
  state never enters Apply.

## VM reset boundary

Stop and request a separate provisioning decision when:

- The MECM setup log shows an unrecoverable error.
- The SQL Server installation is incomplete and cannot be repaired.
- The Windows Server host is in an unknown or untrusted state.
- Marker scope cannot be reconciled across provider and direct client checks.
- Repair would change trust, authentication, client-wide policy, or target
  scope.
- You are unsure whether a partial installation is safe to resume.

Never guess through ambiguous state. A reset or rebuild belongs to
ProxmoxVEAutopilot, is outside the setup-cm v1 acceptance boundary, and requires
its own authorization and evidence. The accepted LabZ1 site must not be reset
to make a rerun pass.
