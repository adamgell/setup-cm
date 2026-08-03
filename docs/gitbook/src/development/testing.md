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
| `Acquisition.Tests.ps1` | Cache-first download, SHA-256 verification, signature checks |
| `StageEngine.Tests.ps1` | Idempotency, skip logic, failure handling, evidence writes |
| `Sql.Tests.ps1` | SQL prerequisite detection, unattended setup, service verification |
| `Mecm.Tests.ps1` | Prerequisite ordering, VC++ detection, site setup arguments |
| `Health.Tests.ps1` | SQL/MP/DP/boundary/client checks, registration gate |
| `Client.Tests.ps1` | Manifest validation, install arguments, rerun logic, redaction |
| `Media.Tests.ps1` | Media path helpers |
| `AgentEntrypoint.Tests.ps1` | Script entry-point contract |

## Integration tests

The integration suite in `tests/Integration/` validates the live lab. It asserts SQL reachability, site service health, MP and DP health, a configured boundary, and a reporting test client.

> **Note:** Integration tests require a completed single-box lab and are not run in CI.

## Quality gates

- All unit tests must pass before committing.
- CodeRabbit review is requested after meaningful changes; each auto-fix is approved independently and affected tests are rerun.
- The CI workflow runs PowerShell 7 and Pester 6 on every push.
