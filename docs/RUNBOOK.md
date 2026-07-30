# SetupCm Runbook

## Prepare

1. Copy `config/lab.example.yaml` to ignored `config/lab.local.yaml`.
2. Set every installer source, SHA-256, version, and license acknowledgement.
3. Put hard-to-find media in the configured private vault or cache.

## Guided run

```powershell
pwsh ./src/SetupCm/Public/Invoke-SetupCm.ps1 -ConfigPath ./config/lab.local.yaml -Mode Guided
```

## Unattended Autopilot Agent run

Set `SETUPCM_CONFIG` to the staged lab configuration, then run:

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1
```

## Reset and resume

Reset the VM through ProxmoxVEAutopilot. For a failed stage, inspect `artifacts/<run-id>/stage-<name>.json`, correct the named prerequisite, and rerun that stage using `-Stage <name>`.

## Modules

Run the core health stage successfully before enabling future co-management, Patch My PC, reporting, or diagnostic modules.
