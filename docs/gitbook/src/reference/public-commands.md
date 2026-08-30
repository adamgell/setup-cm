# Public Commands

`setup-cm` exports five public commands. Run operational workflows through
the wrappers in `scripts/`; files under `src/SetupCm/Public/` define module
functions and are not standalone entry points.

## `Invoke-SetupCm`

The main stage orchestrator:

```powershell
Invoke-SetupCm [-ConfigPath] <string> [[-Mode] <string>]
  [[-Stage] <string[]>] [[-SourceCommit] <string>]
```

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `ConfigPath` | `string` | — | Path to the validated private YAML configuration. |
| `Mode` | `string` | `Guided` | `Guided` pauses after each stage; `Unattended` does not. |
| `Stage` | `string[]` | Config-dependent | Any ordered subset of `Acquire`, `Sql`, `Mecm`, `Marker`, and `Health`. Enabled marker acceptance defaults to all five; otherwise Marker is omitted. |
| `SourceCommit` | `string` | `SETUPCM_SOURCE_COMMIT` | Full 40-character commit for evidence provenance. Required whenever Marker is selected. |

Operational example:

```powershell
pwsh ./scripts/Invoke-SetupCm.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -Mode Unattended `
  -Stage Acquire,Sql,Mecm,Marker,Health `
  -SourceCommit $env:SETUPCM_SOURCE_COMMIT
```

## `Invoke-SetupCmMarkerAcceptance`

Evaluates or reconciles only the fixed LabZ1 marker chain:

```powershell
Invoke-SetupCmMarkerAcceptance [-ConfigPath] <string>
  [[-EvidenceRoot] <string>] [[-SourceCommit] <string>]
```

`SourceCommit` is mandatory in behavior even though PowerShell permits the
parameter to be omitted; the command resolves the environment fallback and
fails before evidence or provider mutation when no exact commit is available.

```powershell
pwsh ./scripts/Invoke-SetupCmMarkerAcceptance.ps1 `
  -ConfigPath $env:SETUPCM_CONFIG `
  -SourceCommit $env:SETUPCM_SOURCE_COMMIT
```

The command refuses any boundary other than site `LAB`, server
`LABZ1-CM01.test.gell.one`, and target `RING0IVY24-01.test.gell.one`
resource `16777219`.

## `Invoke-SetupCmAcquire`

Runs the acquisition apply path for artifacts identified by the outer Acquire
stage:

```powershell
Invoke-SetupCmAcquire [-ConfigPath] <string> [[-EvidenceRoot] <string>]
```

It reuses each exact artifact and applies only invalid entries. Normal
operators should select `Acquire` through `Invoke-SetupCm` so the stage's
read-only Test and independent Verify wrap this command.

## `Invoke-SetupCmClient`

Runs the separate typed MECM client installation workflow using a JSON
manifest:

```powershell
Invoke-SetupCmClient [-ManifestPath] <string>
```

The manifest must contain `siteCode`, `managementPointFqdn`, and
`evidenceRoot`. This command is not the Marker stage and does not broaden the
accepted one-device marker boundary.

## `Test-SetupCmPreflight`

Validates configuration and reports readiness:

```powershell
Test-SetupCmPreflight [-ConfigPath] <string>
```

It returns `Ready` and `Missing`. Continue only when `Ready` is `True`.
