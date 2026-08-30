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
    architecture: x64 | x86 | neutral
    sizeBytes: integer
    licenseAccepted: boolean
    cacheFile: string
    signatureRelativePath: string   # required for ISO media
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
markerAcceptance:
  enabled: boolean
  labOnly: boolean
  siteCode: string
  siteServerFqdn: string
  targetFqdn: string
  targetResourceId: integer
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
- Every non-template source requires a positive `sizeBytes`, an expected
  publisher, a native product version, and an `x64`, `x86`, or `neutral`
  architecture. `sources.mecm.version` is the four-component `ProductVersion`
  of its signed `setup.exe`, not a Current Branch label.
- `mecm.siteCode` must match `^[A-Z0-9]{3}$`.
- `mecm.sqlServer` and `mecm.siteServerFqdn` must match the lab domain.
- `testClient.name` and `testClient.domain` must identify a separate, domain-joined client.
- Enabled marker acceptance requires `labOnly: true` and these exact values:
  `siteCode: LAB`, `siteServerFqdn: LABZ1-CM01.test.gell.one`,
  `targetFqdn: RING0IVY24-01.test.gell.one`, and
  `targetResourceId: 16777219`.

## Runtime-only inputs

The private YAML path and source provenance are supplied outside the schema:

| Input | Contract |
| --- | --- |
| `SETUPCM_CONFIG` or `-ConfigPath` | Path to the non-template YAML staged separately from source. |
| `SETUPCM_SOURCE_COMMIT` or `-SourceCommit` | Full 40-character commit used to create the staged source archive; mandatory for Marker. |

Neither value is copied into component evidence except the validated commit.
The private configuration body, source URIs, and vault locations are never
evidence fields.
