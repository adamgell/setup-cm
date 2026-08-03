# setup-cm

work in progress 

`setup-cm` automates a repeatable, evidence-backed Microsoft Configuration Manager (MECM, formerly SCCM) primary-site deployment for an **isolated lab**.

It installs and validates a single Windows Server that hosts SQL Server, a MECM primary site, Management Point, and Distribution Point. The baseline also verifies that a dedicated test client can use the site.

> [!WARNING]
> This repository is for lab automation, not production MECM deployment. Do not use its default topology, example configuration, or unattended workflow against production infrastructure.

## Why this exists

A working MECM lab depends on licensed media, exact prerequisite versions, Windows and SQL configuration, and a sequence of setup steps that are difficult to reproduce or diagnose from a script transcript alone. `setup-cm` makes that process explicit:

- one reviewed YAML configuration declares the target and approved media;
- each stage tests, applies, and verifies a specific desired state;
- every run preserves structured evidence for successful and failed stages;
- source media, secrets, certificates, and product keys stay outside Git.

Read [why this repository is designed this way](docs/WHY.md) for the boundaries and trade-offs behind those choices.

## What it does

```text
ProxmoxVEAutopilot / Autopilot Agent
  └─ provisions the isolated, domain-joined Windows hosts
       └─ setup-cm
            Acquire → Sql → Mecm → Health
                 └─ run evidence in the configured evidence root
```

`setup-cm` owns Windows-side MECM configuration and validation. Virtual-machine lifecycle, operating-system deployment, networking, storage, and domain joining belong to the provisioning layer (for example, ProxmoxVEAutopilot).

The first-release baseline intentionally excludes production targets, distributed topologies, co-management, Patch My PC, reporting, and other optional integrations.

## Requirements

- An isolated, domain-joined lab with a Windows Server host and a separate test client.
- PowerShell 7 or later.
- The `powershell-yaml` module to read the YAML configuration.
- Approved SQL Server, MECM, Windows ADK, Windows PE add-on, and ODBC Driver 18 media, checksums, and accepted licenses.
- Sufficient local disk space for the configured cache, SQL installation directory, MECM installation directory, and evidence.

The CI workflow uses Pester 6. Install the dependencies locally when you want to run the unit tests:

```powershell
Install-Module Pester -RequiredVersion 6.0.0 -Scope CurrentUser
Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser
```

## Quick start

1. Copy `config/lab.example.yaml` to `config/lab.local.yaml`. The local file is ignored by Git.
2. Replace every placeholder with your isolated-lab details, approved source location, SHA-256 checksum, version, and license acknowledgement. See the [configuration reference](docs/CONFIGURATION.md).
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

See the [runbook](docs/RUNBOOK.md) before operating the workflow.

## Stages and evidence

| Stage | Purpose |
| --- | --- |
| `Acquire` | Obtains and verifies SQL Server and MECM installation media in the configured cache. |
| `Sql` | Installs SQL Server prerequisites, SQL Server, and SQL network configuration. |
| `Mecm` | Installs MECM prerequisites, ADK, Windows PE, ODBC Driver 18, and the primary site. |
| `Health` | Checks core SQL and MECM health, site roles, boundaries, test-client state, and expected logs. |

Each selected stage records a JSON result named `stage-<stage>.json` in a unique run directory beneath `evidenceRoot`. The result records the stage name, state (`Succeeded`, `Skipped`, or `Failed`), timestamps, and a message. Preserve that directory when investigating or resuming a failed run.

## Documentation

- [Why setup-cm exists](docs/WHY.md) — the problem, design choices, and non-goals.
- [Operator runbook](docs/RUNBOOK.md) — prepare, run, recover, and validate a lab deployment.
- [Configuration reference](docs/CONFIGURATION.md) — how to safely complete `lab.local.yaml`.
- [LabZ1 deployment target](docs/LABZ1_DEPLOYMENT.md) — the current reference-lab inventory and order.

## Test

```powershell
Invoke-Pester ./tests/Unit -Output Detailed -CI
```
