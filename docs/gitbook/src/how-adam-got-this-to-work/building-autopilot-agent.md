# Building the Autopilot Agent

The Autopilot Agent is the execution layer that makes unattended, validated MECM deployment possible. This page explains why it exists, how it was built, and what it enforces.

## Why not just use WinRM or SSH?

Windows remote management protocols are powerful but poorly suited to this use case:

- They require network connectivity and firewall rules that may not exist in an isolated lab
- They provide no built-in validation of the work being requested
- They make it easy to run arbitrary commands, which violates the principle of constrained, typed work
- They leave no structured evidence of what was requested versus what was executed

The Autopilot Agent solves these problems by running locally on the target Windows host and accepting only typed, validated work items from a trusted controller.

## Architecture

```text
ProxmoxVEAutopilot Controller (FastAPI/Python)
  └─ queues typed work items
       └─ Autopilot Agent (.NET 8 Windows Service)
            ├─ validates work item schema and constraints
            ├─ stages approved archives (SHA-256 verified)
            ├─ executes PowerShell 7 entry points
            └─ returns structured results and bounded output
```

The Agent is a Windows service written in C# on .NET 8. It polls the controller for work, validates each item against a strict schema, and executes only approved entry points.

## Typed work kinds

The Agent does not accept arbitrary commands. It supports specific work kinds, each with its own validation rules:

| Work kind | Purpose | Key constraints |
| --- | --- | --- |
| `setup_cm_acquire` | Download and verify installation media | Approved URIs only; SHA-256 pinned |
| `setup_cm_sql` | Install SQL Server | Non-template config required; isolated-lab check |
| `setup_cm_mecm` | Install MECM primary site | VC++ 14.34+ gate; approved prerequisite path |
| `setup_cm_health` | Run health validation | Read-only; no state changes |
| `setup_cm_client_install` | Install MECM client on a target | FQDN suffix restricted; SHA-256-pinned module archive |

Each work kind has a dedicated request model. Unknown fields are rejected. Secrets are never accepted.

## The client install work kind

The `setup_cm_client_install` work kind illustrates the Agent's design philosophy:

1. **Constraint:** The management point FQDN must end in the approved lab domain suffix. Any other domain is rejected before execution.
2. **Pinning:** The module archive must match a 64-character SHA-256 provided at queue time. The Agent verifies the hash before extraction.
3. **Derivation:** The only permitted installer path is `\\<managementPoint>\SMS_<siteCode>\Client\ccmsetup.exe`. No arbitrary UNC paths.
4. **Evidence:** The Agent captures sanitized `ccmsetup.log` and `ClientIDManagerStartup.log` tails, redacting any `Password=` values.

This is deliberately less flexible than a generic script runner. The constraint is the feature.

## Building and releasing

The Agent is built as a signed MSI using WiX. The build requires a Windows host; WiX cannot build MSIs on macOS. The release process is:

1. Update the Agent version in the project file
2. Build and sign the MSI on a Windows build machine
3. Publish the MSI to the private distribution point
4. Existing Agents self-update on their next heartbeat

The controller tracks Agent versions and capabilities through heartbeat telemetry. Before queueing a work item, the controller verifies the target Agent supports the requested kind.

## Contract testing

The Agent's validation logic is covered by C# contract tests that run without a Windows domain or live controller. These tests verify:

- Each work kind is registered
- Invalid FQDNs, malformed SHA-256 values, and unexpected fields are rejected
- The client work kind accepts only the approved domain suffix
- No secret fields are accepted in any request model

Contract tests run in CI and must pass before any Agent release.
