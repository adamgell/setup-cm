# Public Commands

`setup-cm` exports four public commands. All other functions are private implementation details.

## `Invoke-SetupCm`

The main stage orchestrator.

```powershell
Invoke-SetupCm [-ConfigPath] <string> [[-Mode] <string>] [[-Stage] <string[]>]
```

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `ConfigPath` | `string` | — | Path to the validated YAML configuration. |
| `Mode` | `string` | `Guided` | `Guided` pauses between stages; `Unattended` runs without interaction. |
| `Stage` | `string[]` | All | Subset of stages to run: `Acquire`, `Sql`, `Mecm`, `Health`. |

**Example:**

```powershell
pwsh ./src/SetupCm/Public/Invoke-SetupCm.ps1 `
  -ConfigPath ./config/lab.local.yaml `
  -Mode Guided
```

## `Invoke-SetupCmAcquire`

Runs only the acquisition stage. Useful for cache warming and diagnostics.

```powershell
Invoke-SetupCmAcquire [-ConfigPath] <string>
```

## `Invoke-SetupCmClient`

Runs the MECM client installation stage using a JSON manifest.

```powershell
Invoke-SetupCmClient [-ManifestPath] <string>
```

The manifest must contain `siteCode`, `managementPointFqdn`, and `evidenceRoot`.

## `Test-SetupCmPreflight`

Validates the configuration and reports readiness.

```powershell
Test-SetupCmPreflight [-ConfigPath] <string>
```

Returns an object with `Ready` (boolean) and `Missing` (string array). Continue only when `Ready` is `True`.
