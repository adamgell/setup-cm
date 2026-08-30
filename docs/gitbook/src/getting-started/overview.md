# Overview & Quick Start

`setup-cm` treats a lab MECM deployment as a sequence of small, verifiable
stages. The stage engine supports Test, Apply, Verify, and structured evidence.
The complete release-candidate workflow now has real read-only probes and
bounded repair. The LabZ1 live gate is accepted; routine operation should use
its [read-only restart procedure](../operations/current-status.md), while the
complete workflow remains available for proven owned-state repair.

## Architecture at a glance

```text
ProxmoxVEAutopilot / Autopilot Agent
  └─ provisions the isolated, domain-joined Windows hosts
       └─ setup-cm
            Acquire → Sql → Mecm → Marker → Health
                 └─ run evidence in the configured evidence root
```

`setup-cm` owns Windows-side MECM configuration and validation. Virtual-machine lifecycle, operating-system deployment, networking, storage, and domain joining belong to the provisioning layer (for example, ProxmoxVEAutopilot).

## Quick start

These steps describe a new isolated lab. They are not the restart procedure for
the already accepted LabZ1 site.

1. Copy `config/lab.example.yaml` to `config/lab.local.yaml`. The local file is ignored by Git.
2. Replace every placeholder with your isolated-lab details, approved source location, byte length, SHA-256 checksum, version, architecture, and license acknowledgement. See the [Configuration Reference](../configuration/reference.md).
3. Import the module and check readiness:

   ```powershell
   Import-Module ./src/SetupCm/SetupCm.psd1 -Force
   Test-SetupCmPreflight -ConfigPath ./config/lab.local.yaml
   ```

4. Run the guided workflow. Marker-enabled runs require the full source commit:

   ```powershell
   pwsh ./scripts/Invoke-SetupCm.ps1 `
     -ConfigPath ./config/lab.local.yaml `
     -Mode Guided `
     -SourceCommit '<FULL_40_CHARACTER_GIT_COMMIT>'
   ```

For unattended execution, stage private configuration separately, then set:

```powershell
$env:SETUPCM_CONFIG = 'C:\ProgramData\SetupCm\config\lab.local.yaml'
$env:SETUPCM_SOURCE_COMMIT = '<FULL_40_CHARACTER_GIT_COMMIT>'
pwsh ./scripts/Invoke-SetupCm.ps1 -Mode Unattended
```

See the [Operator Runbook](../operations/runbook.md) before operating the workflow.

## Stages

| Stage | Purpose |
| --- | --- |
| `Acquire` | Obtains and verifies SQL Server and MECM installation media in the configured cache. |
| `Sql` | Installs ODBC Driver 18, SQL Server prerequisites, SQL Server, and SQL network configuration. |
| `Mecm` | Installs MECM prerequisites, ADK, Windows PE, and the primary site; it re-verifies ODBC Driver 18. |
| `Marker` | Reconciles and verifies the fixed one-device LabZ1 marker deployment. |
| `Health` | Rechecks SQL, MECM, Management Point, Distribution Point, and active-client state without repair. |

Each selected stage records a JSON result named `stage-<stage>.json` in a
unique run directory beneath `evidenceRoot`. Exact compliance is `Skipped`
with no Apply; conflicts stop before mutation. Preserve the whole directory
when investigating or resuming a failed run.
