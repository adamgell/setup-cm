# Two Execution Models

`setup-cm` supports two ways to run the same stages. Both use the same PowerShell module, the same YAML configuration, and the same evidence format. The difference is who invokes the entry point and where the operator sits.

## Model 1: Local terminal (PowerShell 7)

The operator runs `setup-cm` directly on the Windows Server in a PowerShell 7 session.

```powershell
Import-Module ./src/SetupCm/SetupCm.psd1 -Force
Test-SetupCmPreflight -ConfigPath ./config/lab.local.yaml

pwsh ./scripts/Invoke-SetupCm.ps1 `
  -ConfigPath ./config/lab.local.yaml `
  -Mode Guided `
  -SourceCommit '<FULL_40_CHARACTER_GIT_COMMIT>'
```

**When to use this:**
- Initial lab bring-up and debugging
- Learning how the stages work
- Validating a new configuration before handing it to the Agent
- One-off runs where the Agent is not yet deployed

**Characteristics:**
- Guided mode pauses between stages for operator inspection
- Full console output is visible immediately
- The operator controls timing and can intervene between stages
- Works through an authenticated PowerShell/SSH session; visual console access
  is not an acceptance dependency

## Model 2: Autopilot Agent (unattended)

The operator queues a typed work item through the ProxmoxVEAutopilot controller. The Agent on the target server executes `setup-cm` without interactive login.

```powershell
# On the server, staged by the provisioning layer:
$env:SETUPCM_CONFIG = 'C:\Path\To\lab.local.yaml'
$env:SETUPCM_SOURCE_COMMIT = '<FULL_40_CHARACTER_GIT_COMMIT>'
pwsh ./scripts/Invoke-SetupCm.ps1 -Mode Unattended
```

**When to use this:**
- Repeatable, hands-off lab rebuilds
- CI/CD-style automation where the lab is provisioned and configured without human presence
- Environments where RDP/SSH access is restricted or audited
- Client installation on remote machines where no interactive session exists

**Characteristics:**
- Unattended mode runs all selected stages without pausing
- The Agent validates the work item before execution
- Structured results and bounded output are returned to the controller
- Evidence is written to the same `evidenceRoot` as local runs

## Same stages, same evidence

Regardless of the model, the stage engine behaves identically:

- `Test` → `Apply` → `Verify` → `stage-<name>.json`
- Idempotent skip when already compliant
- Conflict stops before mutation; verification failure still fails the stage
- Fail-fast with preserved sanitized evidence tied to the exact source commit
- Resume by rerunning the failed stage and later dependents

The operator chooses the model that fits the situation. The tool does not change.

## Future direction

Both models are first-class execution paths for the supported LabZ1 topology.
Other platforms or broader automation require their own design and acceptance
boundary; see [Future Projects](../development/future-projects.md).
