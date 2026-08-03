# Two Execution Models

`setup-cm` supports two ways to run the same stages. Both use the same PowerShell module, the same YAML configuration, and the same evidence format. The difference is who invokes the entry point and where the operator sits.

## Model 1: Local terminal (PowerShell 7)

The operator runs `setup-cm` directly on the Windows Server in a PowerShell 7 session.

```powershell
Import-Module ./src/SetupCm/SetupCm.psd1 -Force
Test-SetupCmPreflight -ConfigPath ./config/lab.local.yaml

pwsh ./src/SetupCm/Public/Invoke-SetupCm.ps1 `
  -ConfigPath ./config/lab.local.yaml `
  -Mode Guided
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
- Requires RDP or console access to the server

## Model 2: Autopilot Agent (unattended)

The operator queues a typed work item through the ProxmoxVEAutopilot controller. The Agent on the target server executes `setup-cm` without interactive login.

```powershell
# On the server, staged by the provisioning layer:
$env:SETUPCM_CONFIG = 'C:\Path\To\lab.local.yaml'
pwsh ./scripts/Invoke-SetupCm.ps1
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
- Fail-fast with preserved evidence
- Resume by rerunning the failed stage and later dependents

The operator chooses the model that fits the situation. The tool does not change.

## Future direction

Both models are first-class citizens. The local terminal path is the fastest way to develop and debug. The Agent path is the way to scale and automate. New platforms (Hyper-V, VMware Workstation) will support both models: the same PowerShell module runs locally, and the same typed work contract runs through an Agent or equivalent executor.
