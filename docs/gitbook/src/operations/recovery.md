# Recovery & Resume

A failed stage does not require a full restart. The stage engine and evidence format are designed for safe, targeted recovery.

## When to resume vs. reset

| Scenario | Recommended action |
| --- | --- |
| A stage fails because a prerequisite is missing or misconfigured. | Correct the prerequisite, then rerun the failed stage and later dependent stages. |
| A stage fails because media is corrupt or the wrong version. | Replace the media in the cache or vault, update the configuration if necessary, then rerun. |
| A stage fails partway through and the system state is ambiguous. | Reset the VM through the provisioning layer and start over. Do not assume a partial MECM installation is recoverable. |
| The `Health` stage fails after a successful `Mecm` stage. | Investigate the specific health check in the evidence, correct the issue, then rerun `Health` alone. |

## How to resume

1. Preserve the evidence directory from the failed run.
2. Review the failed `stage-<name>.json` to identify the immediate error.
3. Correct the stated prerequisite, source, configuration, or host condition.
4. Rerun the failed stage and any later dependent stages:

   ```powershell
   pwsh ./src/SetupCm/Public/Invoke-SetupCm.ps1 `
     -ConfigPath ./config/lab.local.yaml `
     -Stage Sql,Mecm,Health
   ```

## What the stage engine protects

- **Idempotency** — if a stage test reports `Compliant`, the stage is skipped entirely.
- **No partial verify** — if `Apply` throws, `Verify` does not run.
- **Evidence preservation** — both successful and failed stage results are written before the engine returns or throws.

## When to reset the VM

Reset the VM through the provisioning layer when:

- The MECM setup log shows an unrecoverable error.
- The SQL Server installation is incomplete and cannot be repaired.
- The Windows Server host is in an unknown or untrusted state.
- You are unsure whether a partial installation is safe to resume.

A reset is always safer than guessing. The provisioning layer can recreate the isolated lab quickly, and `setup-cm` can rerun the full sequence.
