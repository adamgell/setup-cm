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
| `Stage` | `string[]` | Config-dependent | Operator-selected subset of `Acquire`, `Sql`, `Mecm`, `Marker`, and `Health`. A validated lab-only marker configuration with the fixed LabZ1 identities defaults to all five and requires a full `SourceCommit`; a marker-disabled configuration omits Marker. |
| `SourceCommit` | `string` | `SETUPCM_SOURCE_COMMIT` | Full 40-character commit for evidence provenance. Required whenever Marker is selected. |

The canonical order is `Acquire` → `Sql` → `Mecm` → `Marker` → `Health`.
The command does not reorder an explicit subset, so operators must preserve
that relative order. Select `Marker` only when `markerAcceptance.enabled` and
`markerAcceptance.labOnly` are both `true`, the exact fixed LabZ1 identities
validate, and a full source commit is available. An enabled marker
configuration without that commit fails before stage execution rather than
silently omitting the required Marker stage.

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

Client proof comes from an authenticated `C$` marker read when available, or
from the code-fixed `SetupCmMarkerEvidence$` channel when the direct route is
unavailable. Missing or stale evidence permits only the bounded, lab-approved
channel, predecessor-detector policy, and client reevaluation sequence.
Malformed or contradictory evidence fails closed, and `ClientProbeUnavailable`
means both authenticated proof routes failed unexpectedly.

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
