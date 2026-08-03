# Configuration Schema

The YAML configuration has the following top-level structure.

```yaml
topology: string
template: boolean
lab:
  name: string
  domain: string
safety:
  isolatedLab: boolean
  allowProductionTarget: boolean
evidenceRoot: string
cacheRoot: string
sources:
  <source-name>:
    uri: string
    sha256: string
    publisher: string
    version: string
    licenseAccepted: boolean
    cacheFile: string
    signatureRelativePath: string   # optional, for ISO media
sql:
  instanceName: string
  serviceAccount: string
  sysAdminAccounts: string[]
  installDirectory: string
mecm:
  siteCode: string
  siteName: string
  sqlServer: string
  siteServerFqdn: string
  productId: string
  smsInstallDir: string
  prerequisitePath: string
testClient:
  name: string
  domain: string
```

## Required source names

The following source names are required for a full run:

- `sqlServer`
- `mecm`
- `adk`
- `adkWinPe`
- `odbcDriver18`
- `vcRedistX64`
- `vcRedistX86`

## Validation rules

- `safety.isolatedLab` must be `true`, or `safety.allowProductionTarget` must be explicitly `true`.
- `template: true` allows placeholder values; `template: false` (or omitted) requires real values.
- `licenseAccepted` must be `true` for every source before acquisition runs.
- `sha256` must be a 64-character hexadecimal string.
- `mecm.siteCode` must match `^[A-Z0-9]{3}$`.
- `mecm.sqlServer` and `mecm.siteServerFqdn` must match the lab domain.
- `testClient.name` and `testClient.domain` must identify a separate, domain-joined client.
