# Overview & Quick Start

`setup-cm` treats a lab MECM deployment as a sequence of small, verifiable
stages. The stage engine supports Test, Apply, Verify, and structured evidence.
The accepted LabZ1 environment must currently use the
[read-only restart procedure](../operations/current-status.md): Acquire now
skips exact cached media, while complete SQL and MECM no-op probes remain v1
work.

## Architecture at a glance

```text
ProxmoxVEAutopilot / Autopilot Agent
  └─ provisions the isolated, domain-joined Windows hosts
       └─ setup-cm
            Acquire → Sql → Mecm → Health
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

4. Run the guided workflow:

   ```powershell
   pwsh ./src/SetupCm/Public/Invoke-SetupCm.ps1 `
     -ConfigPath ./config/lab.local.yaml `
     -Mode Guided
   ```

For unattended agent execution, set `SETUPCM_CONFIG` to the staged configuration path and run:

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1
```

See the [Operator Runbook](../operations/runbook.md) before operating the workflow.

## Stages

| Stage | Purpose |
| --- | --- |
| `Acquire` | Obtains and verifies SQL Server and MECM installation media in the configured cache. |
| `Sql` | Installs SQL Server prerequisites, SQL Server, and SQL network configuration. |
| `Mecm` | Installs MECM prerequisites, ADK, Windows PE, ODBC Driver 18, and the primary site. |
| `Health` | Checks core SQL and MECM health, site roles, boundaries, test-client state, and expected logs. |

Each selected stage records a JSON result named `stage-<stage>.json` in a unique run directory beneath `evidenceRoot`. The result records the stage name, state (`Succeeded`, `Skipped`, or `Failed`), timestamps, and a message. Preserve that directory when investigating or resuming a failed run.
