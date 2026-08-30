# Testing

`setup-cm` uses Pester 6 for unit tests and a live-lab integration suite for end-to-end validation.

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
| `MarkerApplication.Tests.ps1` | Exact payload/detector and safe uninstall behavior |
| `Health.Tests.ps1` | Read-only SQL/MECM/MP/DP/client checks and fresh evidence |
| `Client.Tests.ps1` | Manifest validation, install arguments, rerun logic, redaction |
| `Media.Tests.ps1` | Media path helpers |
| `AgentEntrypoint.Tests.ps1` | Script entry-point contract |
| `MarkdownLinks.Tests.ps1` | Portable local file/heading link validation |

## Integration tests

The integration suite in `tests/Integration/` has three independent boundaries:

| File | Gate |
| --- | --- |
| `CoreStages.Windows.Tests.ps1` | Real SQL, MECM, and read-only Health state on CM01, with installer/setup calls guarded. |
| `MarkerDetection.Windows.Tests.ps1` | Exact VBScript detection for valid, tampered, path-confused, and missing markers. |
| `MarkerAcceptance.Provider.Tests.ps1` | Exact one-device provider state plus throwing mutation adapters to prove reconciliation is a no-op. |

> **Note:** Integration tests require a completed single-box lab and are not run in CI.

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
