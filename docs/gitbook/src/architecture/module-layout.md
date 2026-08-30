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
│   ├── Health.ps1            # Read-only SQL, MECM, MP, DP, and client checks
│   ├── MarkerApplication.ps1 # Fixed LabZ1 marker probes and bounded provider repair
│   ├── Mecm.ps1              # MECM prerequisites, ADK, WinPE, ODBC, site setup
│   ├── Media.ps1             # Media path helpers
│   ├── Sql.ps1               # SQL prerequisites and unattended installation
│   └── StageEngine.ps1       # Shared idempotent stage executor
└── Public/
    ├── Invoke-SetupCm.ps1        # Guided/unattended stage orchestrator
    ├── Invoke-SetupCmAcquire.ps1 # Acquisition-only command
    ├── Invoke-SetupCmClient.ps1  # Client-stage command
    ├── Invoke-SetupCmMarkerAcceptance.ps1 # Fixed marker command
    └── Test-SetupCmPreflight.ps1 # Configuration readiness check
```

## Scripts

```text
scripts/
├── Invoke-SetupCm.ps1                    # Guided/unattended entry point
├── Invoke-SetupCmClient.ps1              # Agent client-stage entry point
├── Invoke-SetupCmMarkerAcceptance.ps1    # Marker-only entry point
├── Test-MarkdownLinks.ps1                # Portable local-link gate
└── marker/                               # Reviewed install/detect/uninstall payload
```

## Tests

```text
tests/Unit/
├── Acquisition.Tests.ps1
├── AgentEntrypoint.Tests.ps1
├── Client.Tests.ps1
├── Configuration.Tests.ps1
├── Health.Tests.ps1
├── MarkdownLinks.Tests.ps1
├── MarkerAcceptance.Tests.ps1
├── MarkerApplication.Tests.ps1
├── Mecm.Tests.ps1
├── Media.Tests.ps1
├── Module.Tests.ps1
├── Sql.Tests.ps1
└── StageEngine.Tests.ps1

tests/Integration/
├── CoreStages.Windows.Tests.ps1
├── MarkerAcceptance.Provider.Tests.ps1
└── MarkerDetection.Windows.Tests.ps1
```

## Configuration

```text
config/
└── lab.example.yaml          # Complete, safe template with placeholders
```
