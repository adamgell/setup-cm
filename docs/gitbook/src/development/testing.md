# Testing

`setup-cm` uses Pester 6 for unit tests and a live-lab integration suite for
end-to-end validation. Run this repository's Pester suite with PowerShell 7.4
or later. Pester 6 also supports Windows PowerShell 5.1, but the SetupCm module
itself requires PowerShell 7.

## Unit tests

Run all unit tests:

```powershell
Invoke-Pester ./tests/Unit -Output Detailed -CI
```

Run a focused test file:

```powershell
Invoke-Pester ./tests/Unit/Mecm.Tests.ps1 -Output Detailed
```

## Test structure

Every private function has a corresponding `*.Tests.ps1` file in `tests/Unit/`. Tests use mocks to isolate Windows-specific APIs (registry, services, processes, file system) so they run on any platform.

| Test file | Coverage |
| --- | --- |
| `Module.Tests.ps1` | Module load, exported commands, PowerShell version |
| `Configuration.Tests.ps1` | YAML parsing, schema validation, safety guardrails |
| `Acquisition.Tests.ps1` | Exact cache state, affected-artifact-only acquisition, source redaction |
| `StageEngine.Tests.ps1` | Idempotency, skip logic, failure handling, evidence writes |
| `Sql.Tests.ps1` | SQL component state, bounded repair, conflict and verification gates |
| `Mecm.Tests.ps1` | Site/component state, bounded repair, media skip and conflict gates |
| `MarkerAcceptance.Tests.ps1` | Fixed boundary, provider reconciliation, no-op behavior, evidence provenance |
| `MarkerEvidenceChannel.Tests.ps1` | Strict six-field parser, SID/ACL/share state, proof precedence, freshness, and bounded convergence |
| `MarkerApplication.Tests.ps1` | Exact payload/detector and safe uninstall behavior |
| `Health.Tests.ps1` | Read-only SQL/MECM/MP/DP/client checks and fresh evidence |
| `Client.Tests.ps1` | Manifest validation, install arguments, rerun logic, redaction |
| `Media.Tests.ps1` | Media path helpers |
| `AgentEntrypoint.Tests.ps1` | Script entry-point contract |
| `MarkdownLinks.Tests.ps1` | Portable local file/heading link validation |

## Integration tests

The integration suite in `tests/Integration/` has four independent boundaries:

| File | Gate |
| --- | --- |
| `CoreStages.Windows.Tests.ps1` | Real SQL, MECM, and read-only Health state on CM01, with installer/setup calls guarded. |
| `MarkerDetection.Windows.Tests.ps1` | Exact VBScript detection plus strict target-only authenticated publication for valid, tampered, missing, transport-failure, and test-path cases. |
| `MarkerEvidenceChannel.Windows.Tests.ps1` | Real Windows protected ACL construction, SID-normalized inventory, and bounded reads in temporary paths. |
| `MarkerAcceptance.Provider.Tests.ps1` | Exact one-device provider state in explicit `PreMigration` or `PostMigration` mode, with every mutation/side-effect adapter replaced by a throw. |

> **Note:** Integration tests require a completed single-box lab and are not run in CI.

Run the CM01 Windows and provider suites as the authorized LabZ1 domain
operator. Use a fresh PowerShell process for the provider suite so module-scope
mocks from another Pester invocation cannot leak into it:

```powershell
$env:SETUPCM_LAB_INTEGRATION = '1'
Invoke-Pester ./tests/Integration/CoreStages.Windows.Tests.ps1, `
  ./tests/Integration/MarkerDetection.Windows.Tests.ps1, `
  ./tests/Integration/MarkerEvidenceChannel.Windows.Tests.ps1 `
  -Output Detailed -CI

$env:SETUPCM_LAB_PROVIDER_INTEGRATION = '1'
$env:SETUPCM_MARKER_PROVIDER_MODE = 'PreMigration' # or PostMigration
Invoke-Pester ./tests/Integration/MarkerAcceptance.Provider.Tests.ps1 `
  -Output Detailed -CI
```

Build the Windows test source with `git archive` from the exact reviewed commit,
verify both the archive SHA-256 and embedded commit on CM01, and retain those
values with the result. The target-only detector publication cases must run on
`RING0IVY24-01` after asserting its exact computer name. If only Pester 3.4 is
available there, use a temporary mechanically translated test copy; do not edit
the tracked source or production detector, and record both exact source hashes.

## Quality gates

- All unit tests must pass before committing.
- `./scripts/Test-MarkdownLinks.ps1` must resolve every local file and heading.
- `mdbook build ./docs/gitbook` must succeed.
- PowerShell files must parse and PSScriptAnalyzer must report zero errors.
- Diff/whitespace and staged-secret scans must pass.
- CodeRabbit review is requested after meaningful changes; reproduce findings
  before changing code and rerun affected plus full suites.
- Pull-request CI runs PowerShell 7, Pester 6, and the link checker; Pages CI
  repeats the link checker before mdBook.
