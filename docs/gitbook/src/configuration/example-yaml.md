# lab.example.yaml Annotated

The committed `config/lab.example.yaml` is a complete, safe template. Every value that must be replaced is marked `REPLACE_WITH_*` or uses a placeholder URL.

```yaml
topology: single-box
template: true
lab:
  name: lab
  domain: lab.local
safety:
  isolatedLab: true
  allowProductionTarget: false
evidenceRoot: C:\ProgramData\SetupCm\artifacts
cacheRoot: C:\ProgramData\SetupCm\cache
sources:
  sqlServer:
    uri: https://installer-vault.example.invalid/sql-server.iso
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    signatureRelativePath: setup.exe
    architectureRelativePath: x64\ScenarioEngine.exe
    version: "16.0.1000.6"
    architecture: x64
    sizeBytes: REPLACE_WITH_SIZE_BYTES
    licenseAccepted: false
    cacheFile: sql-server.iso
  mecm:
    uri: https://installer-vault.example.invalid/mecm.iso
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    signatureRelativePath: SMSSETUP\BIN\X64\setup.exe
    version: "5.00.9141.1002"
    architecture: x64
    sizeBytes: REPLACE_WITH_SIZE_BYTES
    licenseAccepted: false
    cacheFile: mecm-current-branch-2509.iso
  adk:
    uri: https://go.microsoft.com/fwlink/?linkid=2289980
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    version: "10.1.26100.2454"
    architecture: neutral
    sizeBytes: REPLACE_WITH_SIZE_BYTES
    licenseAccepted: false
    cacheFile: adksetup.exe
  adkWinPe:
    uri: https://go.microsoft.com/fwlink/?linkid=2289981
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    version: "10.1.26100.2454"
    architecture: neutral
    sizeBytes: REPLACE_WITH_SIZE_BYTES
    licenseAccepted: false
    cacheFile: adkwinpesetup.exe
  odbcDriver18:
    uri: https://installer-vault.example.invalid/msodbcsql18-x64.msi
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    version: "18.4.1.1"
    architecture: x64
    sizeBytes: REPLACE_WITH_SIZE_BYTES
    licenseAccepted: false
    cacheFile: msodbcsql18-x64.msi
  vcRedistX64:
    uri: https://aka.ms/vc14/vc_redist.x64.exe
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    version: "14.44.35211.0"
    architecture: x64
    architectureVerification: signedVersionResource
    sizeBytes: REPLACE_WITH_SIZE_BYTES
    licenseAccepted: false
    cacheFile: vc_redist.x64.exe
  vcRedistX86:
    uri: https://aka.ms/vc14/vc_redist.x86.exe
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    version: "14.44.35211.0"
    architecture: x86
    sizeBytes: REPLACE_WITH_SIZE_BYTES
    licenseAccepted: false
    cacheFile: vc_redist.x86.exe
  prerequisites: []
sql:
  instanceName: MSSQLSERVER
  serviceAccount: LAB\svc_sql
  sysAdminAccounts:
    - LAB\CMSetupAdmins
  installDirectory: D:\SQL
mecm:
  siteCode: LAB
  siteName: Lab Primary
  sqlServer: CM01.lab.local
  siteServerFqdn: CM01.lab.local
  productId: Eval
  smsInstallDir: D:\ConfigMgr
  prerequisitePath: D:\Sources\Redist
testClient:
  name: CMCLIENT01
  domain: lab.local
markerAcceptance:
  enabled: false
  labOnly: true
  siteCode: LAB
  siteServerFqdn: LABZ1-CM01.test.gell.one
  targetFqdn: RING0IVY24-01.test.gell.one
  targetResourceId: 16777219
```

## Key annotations

- `template: true` — keeps the committed example valid even with placeholders. Set to `false` or remove in a real configuration.
- `safety.isolatedLab: true` — required for the intended lab use case.
- `licenseAccepted: false` — you must explicitly set this to `true` after accepting the license terms for each installer.
- `REPLACE_WITH_SHA256` — must be replaced with the actual SHA-256 checksum of your approved media.
- `REPLACE_WITH_SIZE_BYTES` — must be replaced with the exact approved byte length.
- `evidenceRoot` and `cacheRoot` — should be on local, adequately sized storage outside the repository.
- `markerAcceptance.enabled: false` — the template cannot deploy the marker.
  Enabling it requires the fixed LabZ1 identities shown and a full source
  commit supplied at runtime.

## Version guidance

The example pins the following versions. Update them to match your approved media:

| Source | Example version | Notes |
| --- | --- | --- |
| SQL Server | `16.0.1000.6` | SQL Server 2022 RTM |
| MECM | `5.00.9141.1002` | Native `setup.exe` ProductVersion for the accepted Current Branch 2509 media |
| ADK / WinPE | `10.1.26100.2454` | Windows 11 24H2 ADK |
| ODBC Driver 18 | `18.4.1.1` | Microsoft ODBC Driver 18 for SQL Server |
| VC++ Redist | `14.44.35211.0` | VC++ v14 latest; minimum `14.34` required |
