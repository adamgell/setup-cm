# Operator Runbook

Use this runbook only after a provisioning layer has created an isolated, domain-joined Windows Server and a separate test client. Read the [Overview & Quick Start](../getting-started/overview.md) and [Configuration Reference](../configuration/reference.md) first.

> **Current LabZ1 note:** The accepted baseline is already installed. Until
> the hands-off v1 rerun plan completes the SQL and MECM desired-state probes,
> do not replay the complete workflow solely for newer timestamps. Acquire now
> verifies exact cached artifacts without downloading compliant media. Follow
> [Current LabZ1 Status](./current-status.md) and run read-only `Health` checks.

## Prepare the lab

1. Install PowerShell 7 and the `powershell-yaml` module on the server:

   ```powershell
   Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser
   ```

2. Copy `config/lab.example.yaml` to the ignored `config/lab.local.yaml`.
3. Replace every placeholder source, checksum, version, host name, domain, directory, and license acknowledgement with the isolated-lab values.
4. Put SQL Server and MECM media in the configured cache or an approved private vault when they cannot be retrieved directly. Confirm that the ADK source with Deployment Tools and USMT, the matching Windows PE add-on, ODBC Driver 18, and the Microsoft Visual C++ v14 Redistributables for both x64 and x86 are available for the MECM stage. The Agent verifies and installs both runtime architectures before MECM downloads prerequisites.
5. Confirm there is sufficient space at the configured cache, evidence, SQL, MECM, and prerequisite paths.

Do not place product keys, credentials, certificates, or installer media in the repository.

## Run preflight

```powershell
Import-Module ./src/SetupCm/SetupCm.psd1 -Force
Test-SetupCmPreflight -ConfigPath ./config/lab.local.yaml
```

Continue only when `Ready` is `True`. Resolve the names in `Missing` by accepting the relevant license or supplying a source, vault location, or cached file.

## Guided run

Guided mode pauses between stages so the operator can inspect progress:

```powershell
pwsh ./src/SetupCm/Public/Invoke-SetupCm.ps1 `
  -ConfigPath ./config/lab.local.yaml `
  -Mode Guided
```

The default order is `Acquire`, `Sql`, `Mecm`, then `Health`.

## Unattended agent run

Stage the source bundle and a non-template local configuration on the server. Set `SETUPCM_CONFIG` to the configuration path, then run:

```powershell
$env:SETUPCM_CONFIG = 'C:\Path\To\lab.local.yaml'
pwsh ./scripts/Invoke-SetupCm.ps1
```

The wrapper runs in unattended mode by default. To run a subset, pass `-Stage Acquire`, `-Stage Sql`, `-Stage Mecm`, or `-Stage Health`.

## Inspect evidence and recover

Each execution creates a new directory under `evidenceRoot`. It contains `stage-<name>.json` for every selected stage. A result has one of these states:

| State | Meaning |
| --- | --- |
| `Succeeded` | The stage applied its work and its verification passed. |
| `Skipped` | The stage test found the target already compliant. |
| `Failed` | The stage stopped; its message identifies the immediate error. |

For a failed stage:

1. Preserve the evidence directory and review the failed `stage-<name>.json`.
2. Correct the stated prerequisite, source, configuration, or host condition.
3. Rerun the failed stage and any later dependent stages:

   ```powershell
   pwsh ./src/SetupCm/Public/Invoke-SetupCm.ps1 `
     -ConfigPath ./config/lab.local.yaml `
     -Stage Sql,Mecm,Health
   ```

4. If the installation is ambiguous or would require a VM reset/reinstall,
   stop and hand the exact evidence to the provisioning owner. VM lifecycle is
   outside setup-cm and is not an automatic recovery action.

## Validate and extend

Keep the evidence from the first successful `Health` run. It is the baseline proof that SQL, site roles, boundaries, the test client, and expected logs are healthy.

Run the core health stage successfully before enabling future co-management, Patch My PC, reporting, or diagnostic modules. These capabilities are not part of the current baseline.
