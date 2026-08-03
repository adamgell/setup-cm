# Module Layout

```text
src/SetupCm/
├── SetupCm.psd1              # Module manifest and exported commands
├── SetupCm.psm1              # Loads private and public functions
├── Private/
│   ├── Acquisition.ps1       # Download, hash, signature, and cache verification
│   ├── Client.ps1            # MECM client installation and evidence
│   ├── Configuration.ps1     # YAML parsing, schema validation, safety checks
│   ├── Evidence.ps1          # Run-folder creation and structured stage-result writes
│   ├── Health.ps1            # SQL, MECM, MP, DP, boundary, and client checks
│   ├── Mecm.ps1              # MECM prerequisites, ADK, WinPE, ODBC, site setup
│   ├── Media.ps1             # Media path helpers
│   ├── Sql.ps1               # SQL prerequisites and unattended installation
│   └── StageEngine.ps1       # Shared idempotent stage executor
└── Public/
    ├── Invoke-SetupCm.ps1        # Guided/unattended stage orchestrator
    ├── Invoke-SetupCmAcquire.ps1 # Acquisition-only command
    ├── Invoke-SetupCmClient.ps1  # Client-stage command
    └── Test-SetupCmPreflight.ps1 # Configuration readiness check
```

## Scripts

```text
scripts/
├── Invoke-SetupCm.ps1        # Autopilot Agent entry point (unattended)
└── Invoke-SetupCmClient.ps1  # Agent client-stage entry point
```

## Tests

```text
tests/Unit/
├── Acquisition.Tests.ps1
├── AgentEntrypoint.Tests.ps1
├── Client.Tests.ps1
├── Configuration.Tests.ps1
├── Health.Tests.ps1
├── Mecm.Tests.ps1
├── Media.Tests.ps1
├── Module.Tests.ps1
├── Sql.Tests.ps1
└── StageEngine.Tests.ps1
```

## Configuration

```text
config/
└── lab.example.yaml          # Complete, safe template with placeholders
```
