# setup-cm

> **Current status — accepted lab, v1 live rerun gate pending**
> The LabZ1 SQL/MECM/client baseline and its one-device required marker
> deployment are accepted. Idempotent probes and bounded reconciliation now
> exist for the complete five-stage workflow. The reviewed two-run live gate,
> merge, and v1 release are still pending, so follow the accepted restart
> records rather than replaying bootstrap stages merely for newer timestamps.

`setup-cm` automates a repeatable, evidence-backed Microsoft Configuration Manager (MECM, formerly SCCM) primary-site deployment for an **isolated lab**.

It installs and validates a single Windows Server that hosts SQL Server, a MECM primary site, Management Point, and Distribution Point. The baseline also verifies that a dedicated test client can use the site.

> [!WARNING]
> This repository is for lab automation, not production MECM deployment. Do not use its default topology, example configuration, or unattended workflow against production infrastructure.

## Current LabZ1 acceptance

The current reference lab is `LABZ1-CM01.test.gell.one`, site `LAB`, database
`CM_LAB`, with `RING0IVY24-01.test.gell.one` as the only accepted client. The
older planned `LABZ1-CMCLIENT01` identity is obsolete for current acceptance.

- [Phase 0 Lab inventory and baseline acceptance](docs/PHASE0-2026-08-29-LAB-INVENTORY.md)
  is the authoritative server/client restart record.
- [Phase 1 marker acceptance](docs/PHASE1-2026-08-29-MARKER-DEPLOYMENT.md)
  proves the required marker is compliant exclusively on `RING0IVY24-01`.
- [LabZ1 deployment target](docs/LABZ1_DEPLOYMENT.md) summarizes the current
  inventory, safe restart point, and remaining v1 work.

Until the two-run gate is accepted, use current read-only Health and
provider/client checks on the accepted lab. The release-candidate workflow now
tests exact Acquire, SQL, MECM, Marker, and Health state before applying and
fails closed on unsupported or conflicting identity.

## Why this exists

A working MECM lab depends on licensed media, exact prerequisite versions, Windows and SQL configuration, and a sequence of setup steps that are difficult to reproduce or diagnose from a script transcript alone. `setup-cm` makes that process explicit:

- one reviewed YAML configuration declares the target and approved media;
- the stage engine supports testing, applying, and independently verifying a
  specific desired state;
- every run preserves structured evidence for successful and failed stages;
- source media, secrets, certificates, and product keys stay outside Git.

Read [why this repository is designed this way](docs/WHY.md) for the boundaries and trade-offs behind those choices.

## What it does

```text
ProxmoxVEAutopilot / Autopilot Agent
  └─ provisions the isolated, domain-joined Windows hosts
       └─ setup-cm
            Acquire → Sql → Mecm → Marker → Health
                 └─ run evidence in the configured evidence root
```

`setup-cm` owns Windows-side MECM configuration and validation. Virtual-machine lifecycle, operating-system deployment, networking, storage, and domain joining belong to the provisioning layer (for example, ProxmoxVEAutopilot).

The first-release baseline intentionally excludes production targets, distributed topologies, co-management, Patch My PC, reporting, and other optional integrations.

## Requirements

- An isolated, domain-joined lab with a Windows Server host and a separate test client.
- PowerShell 7 or later.
- Git for Windows with `git.exe` on `PATH`, used to verify the commit embedded
  in the reviewed source archive before extraction.
- The `powershell-yaml` module to read the YAML configuration.
- [mdBook](https://rust-lang.github.io/mdBook/guide/installation.html) to build
  the documentation site locally.
- Approved SQL Server, MECM, Windows ADK, Windows PE add-on, ODBC Driver 18,
  and VC++ x64/x86 media, checksums, and accepted licenses.
- Sufficient local disk space for the configured cache, SQL installation directory, MECM installation directory, and evidence.

The CI workflow uses Pester 6. Install the dependencies locally when you want to run the unit tests:

```powershell
Install-Module Pester -RequiredVersion 6.0.0 -Scope CurrentUser
Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser
```

Install mdBook using its linked official installation guide before running the
documentation build command.

## Quick start

1. Copy `config/lab.example.yaml` to `config/lab.local.yaml`. The local file is ignored by Git.
2. Replace every placeholder with your isolated-lab details, approved source location, byte length, SHA-256 checksum, version, architecture, and license acknowledgement. See the [configuration reference](docs/CONFIGURATION.md).
3. Import the module and check readiness:

   ```powershell
   Import-Module ./src/SetupCm/SetupCm.psd1 -Force
   Test-SetupCmPreflight -ConfigPath ./config/lab.local.yaml
   ```

4. Run the guided workflow. When marker acceptance is enabled, pin evidence to
   the full 40-character commit used to stage the source:

   ```powershell
   $sourceCommit = '<FULL_40_CHARACTER_GIT_COMMIT>'
   pwsh ./scripts/Invoke-SetupCm.ps1 `
     -ConfigPath ./config/lab.local.yaml `
     -Mode Guided `
     -SourceCommit $sourceCommit
   ```

For unattended agent execution, stage the private configuration separately
from the source archive, set both inputs, and run:

```powershell
$env:SETUPCM_CONFIG = 'C:\ProgramData\SetupCm\config\lab.local.yaml'
$env:SETUPCM_SOURCE_COMMIT = '<FULL_40_CHARACTER_GIT_COMMIT>'
pwsh ./scripts/Invoke-SetupCm.ps1 -Mode Unattended
```

See the [runbook](docs/RUNBOOK.md) before operating the workflow.

## Stages and evidence

| Stage | Purpose |
| --- | --- |
| `Acquire` | Obtains and verifies SQL Server and MECM installation media in the configured cache. |
| `Sql` | Installs ODBC Driver 18, SQL Server prerequisites, SQL Server, and SQL network configuration. |
| `Mecm` | Installs MECM prerequisites, ADK, Windows PE, and the primary site; it re-verifies ODBC Driver 18. |
| `Marker` | Reconciles the fixed lab-only marker application and verifies its required one-device deployment. |
| `Health` | Rechecks SQL, MECM, Management Point, Distribution Point, and active-client state without repair. |

Every stage follows Test → bounded Apply when required → independent Verify →
sanitized evidence. Exact compliance produces `Skipped` and performs no Apply.
A conflict fails before mutation. Health is always read-only. Each selected
stage records `stage-<stage>.json` in a unique run directory beneath
`evidenceRoot`; component probes write their state artifacts alongside it.
Preserve that directory when investigating or resuming a failed run. The
accepted LabZ1 restart procedure currently selects `Health` only; the reviewed
two-run no-op acceptance remains the final live v1 gate.

## Documentation

The full documentation is published as a [GitBook-style site](https://adamgell.github.io/setup-cm/) built with mdBook. It includes:

- [Getting started](https://adamgell.github.io/setup-cm/getting-started/overview.html) — overview, prerequisites, and quick start.
- [Configuration](https://adamgell.github.io/setup-cm/configuration/reference.html) — field-by-field YAML reference.
- [Operations](https://adamgell.github.io/setup-cm/operations/runbook.html) — runbook, stages, evidence, and recovery.
- [Architecture](https://adamgell.github.io/setup-cm/architecture/why.html) — design principles and module layout.
- [Reference](https://adamgell.github.io/setup-cm/reference/public-commands.html) — commands, schema, and evidence format.
- [Development](https://adamgell.github.io/setup-cm/development/design-documents.html) — designs, plans, testing, and handoffs.

The source lives in `docs/gitbook/` and is built automatically on every push to `main`.

For offline reading, the original markdown sources are still available:

- [Why setup-cm exists](docs/WHY.md) — the problem, design choices, and non-goals.
- [Operator runbook](docs/RUNBOOK.md) — prepare, run, recover, and validate a lab deployment.
- [Configuration reference](docs/CONFIGURATION.md) — how to safely complete `lab.local.yaml`.
- [LabZ1 deployment target](docs/LABZ1_DEPLOYMENT.md) — the current reference-lab inventory and order.
- [Future projects](docs/FUTURE-PROJECTS.md) — optional capabilities kept outside the v1 boundary.

## Test

```powershell
Invoke-Pester ./tests/Unit -Output Detailed -CI
./scripts/Test-MarkdownLinks.ps1
mdbook build ./docs/gitbook
```
