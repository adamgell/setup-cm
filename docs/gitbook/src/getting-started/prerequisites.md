# Prerequisites

Before running `setup-cm`, ensure the following are in place.

## Environment

- An **isolated, domain-joined lab** with a Windows Server host and a separate test client.
- **PowerShell 7.0** or later on the server for SetupCm operations.
- **PowerShell 7.4** or later on hosts that run the Pester 6 test suite.
- **Git for Windows** with `git.exe` on `PATH`, used to verify the commit
  embedded in the reviewed source archive before extraction.
- The `powershell-yaml` module to read the YAML configuration.
- Approved SQL Server, MECM, Windows ADK, Windows PE add-on, ODBC Driver 18,
  and VC++ x64/x86 media, checksums, and accepted licenses.
- Sufficient local disk space for the configured cache, SQL installation directory, MECM installation directory, and evidence.

## Install dependencies locally

Run these test-dependency commands from PowerShell 7.4 or later. Pester 6 also
supports Windows PowerShell 5.1, but this repository's module requires
PowerShell 7.

```powershell
Install-Module Pester -RequiredVersion 6.0.0 -Scope CurrentUser
Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser
```

## Media and licensing

MECM, SQL Server, and related installers can be licensed, authenticated, customer-specific, large, or subject to vendor distribution rules. The repository stores only source metadata, integrity values, versions, and an explicit license acknowledgement. Operators keep actual media in an approved vendor location, private installer vault, or local cache.

The same separation applies to product keys, credentials, certificates, and generated evidence that may contain environment-specific information.

## Safety guardrail

Set `safety.isolatedLab: true` for the intended use case. If it is `false`, `safety.allowProductionTarget` must be explicitly `true` or configuration validation stops the run. That explicit acknowledgement is a guardrail, not approval to use this project for production deployment.
