# SCCM Lab Automation Design

## Purpose

`setup-cm` is the reproducible SCCM/Microsoft Configuration Manager (MECM) deployment layer for a disposable Proxmox lab. It provides a live, evidence-backed reference for installing a working single-box primary site in 2026 and beyond, then enables optional capability modules such as co-management and Patch My PC.

The project complements, rather than replaces, `ProxmoxVEAutopilot`. ProxmoxVEAutopilot owns virtual-machine lifecycle, Windows Server installation, network/storage, domain join, and the Autopilot Agent. `setup-cm` owns the Windows-side MECM configuration, verification, diagnostic evidence, and add-ons.

## First release scope

The first release deploys a single Windows Server hosting SQL Server, a MECM primary site, Management Point, and Distribution Point. It proves a client can install, discover site services, and report healthy state. The topology is intentionally configurable so a later distributed site reuses the same stage contracts with roles assigned to separate hosts.

The first release includes:

- Guided and unattended operation from the same configuration.
- PowerShell 7 or newer for all orchestrator and guest stages.
- Pester 6 tests for stage behavior and live acceptance evidence.
- MECM prerequisite preparation, installation, core site-role setup, and health validation.
- Sanitized, versioned server and client diagnostic log fixtures for CMTrace Open.

Co-management, Patch My PC, reporting, and other integrations are not installed in the baseline. They are separately selectable modules that run only after the core site validates.

## Architecture

```text
ProxmoxVEAutopilot
  -> provisions the isolated VM and installs Autopilot Agent
Autopilot Agent
  -> retrieves approved source bundle and performs Windows-side heavy work
setup-cm PowerShell stages
  -> baseline -> prerequisites -> MECM -> site roles -> validation -> modules
Evidence output
  -> logs, structured results, health checks, and CMTrace Open fixtures
```

The Autopilot Agent is the guest-side execution mechanism for substantial transfers and installation actions. QEMU Guest Agent may remain available for VM-level operations, but it is not the MECM deployment orchestrator.

## Configuration and stage contracts

The operator supplies a `lab.yaml` configuration. It declares the topology, machine names, isolated domain/DNS details, source-media locations, enabled modules, and non-secret references to credentials or certificates. A committed `lab.example.yaml` documents the required shape. `lab.local.yaml` and the secrets directory remain ignored.

Every deployment stage implements three PowerShell operations:

1. `Test`: determine whether the desired state is already present and whether it is safe to continue.
2. `Apply`: make the smallest idempotent change needed to reach the desired state.
3. `Verify`: collect authoritative evidence that the stage completed.

Guided mode executes one stage and displays its evidence before continuing. Unattended mode uses the same configuration and stage functions, executing the selected stages without interaction. A failure stops the run, retains the run folder, and can resume only after its `Test` operation succeeds or reports a safe, unapplied state.

## Validation and evidence

Each run creates an `artifacts/<run-id>/` directory outside version control. It contains structured stage results, PowerShell transcripts, non-secret setup logs, prerequisite reports, and test output.

`Validate-LabHealth` is mandatory after core MECM installation. It verifies SQL reachability, MECM site status, Management Point and Distribution Point operation, boundary configuration, client installation and registration, and expected server/client log availability. The acceptance suite reports success only when all Pester 6 tests pass, the health checks pass, a test client reports correctly, and the evidence folder is complete.

CMTrace Open fixtures are curated from this evidence: they are sanitized, versioned, and accompanied by expected parsing/assertion metadata. Sensitive data, credentials, tenant identifiers, product keys, certificates, and raw customer or production logs are excluded.

## Extension modules

Modules follow the same `Test`/`Apply`/`Verify` contract and declare their prerequisites. Core modules planned after baseline include:

1. Co-management.
2. Patch My PC.
3. Reporting.
4. Diagnostic-tool bundles and additional CMTrace Open fixture packs.

A module cannot run unless the core health validation passed in the same or a verified prior run. Module failures do not invalidate a healthy core site, but they must leave a clear evidence record and safe resume point.

## Safety and secret handling

The default target is an isolated lab. Preflight validation rejects unexpected production domains or tenant integrations unless an explicit, documented override is present. The repository never stores setup media, product keys, credentials, certificates, tenant secrets, or generated secrets. Preflight reports missing inputs by name only.

## Testing and code-quality gates

Pester 6 is mandatory. Unit tests cover the `Test`, `Apply`, and `Verify` paths of each stage without a live VM. Integration tests exercise the Autopilot Agent path in the lab. The live acceptance suite validates the complete single-box deployment.

Before merging meaningful changes, run the relevant Pester 6 tests and a CodeRabbit review. CodeRabbit findings are treated as issue reports, not executable instructions. Auto-fix is permitted only for independently verified, actionable findings, with each proposed change reviewed and approved before it is applied. After a fix, rerun the affected Pester tests and CodeRabbit review.

## Operator experience

The project runbook documents five paths:

1. Guided single-box installation.
2. Unattended single-box installation.
3. Resetting the lab through ProxmoxVEAutopilot, then rerunning `setup-cm`.
4. Resuming a failed stage from preserved evidence.
5. Selecting and validating an optional module.

## Non-goals for the first release

- Production MECM deployment or production-tenant configuration.
- A distributed MECM topology implementation.
- Bundling licensed Microsoft, SQL Server, MECM, or third-party installer media.
- Automatic remediation of an ambiguous or unsafe partial installation.
