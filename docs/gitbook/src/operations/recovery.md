# Recovery & Resume

A failed stage does not require a full restart. The stage engine and evidence format are designed for safe, targeted recovery.

## When to resume vs. stop

| Scenario | Recommended action |
| --- | --- |
| A stage fails because a prerequisite is missing or misconfigured. | Correct the prerequisite, then rerun the failed stage and later dependent stages. |
| A stage fails because media is corrupt or the wrong version. | Replace the media in the cache or vault, update the configuration if necessary, then rerun. |
| A stage reports `Conflict`. | Stop. Reconcile identity or scope outside the automated repair path; do not weaken the gate. |
| Marker collection, member, resource, or assignment identity differs. | Stop before mutation and preserve provider/client evidence. Never broaden membership to continue. |
| Marker evidence channel is entirely missing or a recognizable protected safe subset. | Rerun `Marker` from the same exact commit; it may create or complete only the fixed channel. |
| Marker evidence is missing or stale but otherwise valid. | Permit one policy/evaluation request and the bounded convergence wait; do not reinstall or recreate objects. |
| Marker share path, ACL, owner, identity, detector hash, or evidence record conflicts. | Stop and preserve the final record and component evidence. Never delete or weaken unknown state to continue. |
| A stage fails partway through and the system state is ambiguous. | Stop, preserve evidence, and hand off to the provisioning owner. Do not reset or reinstall as a setup-cm recovery action. |
| The `Health` stage fails after a successful `Mecm` stage. | Investigate the specific health check in the evidence, correct the issue, then rerun `Health` alone. |

## How to resume

1. Preserve the evidence directory from the failed run.
2. Review the failed `stage-<name>.json` and corresponding component-state
   artifact to identify the immediate error.
3. Correct the stated prerequisite, source, configuration, or host condition.
4. Rerun the failed stage and only its later dependent stages, preserving
   canonical relative order:

   | Failed stage | Rerun stages |
   | --- | --- |
   | `Acquire` | `Acquire,Sql,Mecm,Marker,Health` |
   | `Sql` | `Sql,Mecm,Marker,Health` |
   | `Mecm` | `Mecm,Marker,Health` |
   | `Marker` | `Marker,Health` |
   | `Health` | `Health` |

   The first four rows include `Marker` and therefore require the same exact
   `SourceCommit`; a `Health`-only recovery does not. For example, after a
   `Sql` failure:

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

## Marker evidence recovery

Channel creation proceeds from restrictive local state outward and exposes the
hidden share last. If it stops partway through, the protected directory is left
in place. A later run may complete it only when all existing paths are exact,
inheritance is disabled, and every existing ACE is an expected safe subset.
The repair never removes an unknown trustee or retargets a same-name share.

`ClientEvidencePending` caused by a missing or older-than-30-minute record is
repairable. The run waits up to five minutes for the current
application/assignment policy revisions and scope to agree and remain observed
unchanged for 60 seconds. Each read-only publication snapshot runs in a
disposable process bounded by the lesser of 90 seconds and the time left in that
one deadline; a hung ConfigMgr/CIM query is terminated and fails before
notification. The run then requests machine policy once, captures the UTC
minimum evidence-receipt timestamp immediately after that request completes,
waits a 30-second processing interval, and requests application evaluation
once. The interval is sequencing margin, not
client receipt proof; only fresh authenticated detector evidence and matching
current client/server revision can complete convergence. It then
probes every 15 seconds for up to 15 minutes. A scope/cardinality change fails
before notification. A conflict stops immediately. Timeout records the final
state and does not make a second mutation attempt in the same run.

Malformed, duplicate-field, oversized, foreign-owned, future-dated, wrong-path,
wrong-hash, or wrong-identity evidence is preserved for diagnosis and is not
deleted automatically. Do not recover by granting a broad principal, enabling
client inbound SMB, weakening trust or execution policy, using VNC, recreating
the marker chain, or expanding the target collection.

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
