# Configuration Reference

Start with `config/lab.example.yaml` and save the working copy as `config/lab.local.yaml`. The latter is ignored by Git. Do not commit a working configuration that contains internal hostnames, vault paths, credentials, product keys, or other environment-specific data.

## Top-level settings

| Setting | Purpose |
| --- | --- |
| `topology` | Deployment shape. The supplied template uses `single-box`. |
| `template` | Keeps placeholder values valid in the committed example. Remove it or set it to `false` in a real configuration. |
| `lab` | Identifies the lab name and domain. |
| `safety` | Records whether the target is isolated and where evidence and cached media are stored. |
| `sources` | Declares each approved installer and its integrity metadata. |
| `sql` | Configures the SQL Server instance, service identity, administrators, and install directory. |
| `mecm` | Configures the primary-site identity, SQL endpoint, site server, product identifier, and install paths. |
| `testClient` | Identifies the client used by the health stage. |
| `markerAcceptance` | Enables the fixed, lab-only marker boundary; disabled in the template. |

## Safety

Set `safety.isolatedLab: true` for the intended use case. If it is `false`, `safety.allowProductionTarget` must be explicitly `true` or configuration validation stops the run. That explicit acknowledgement is a guardrail, not approval to use this project for production deployment.

`evidenceRoot` is where each execution creates a unique run directory. `cacheRoot` is where verified installer media is retained. Place both on storage with enough space and appropriate access control. They should not be inside the repository.

## Installer sources

The template includes `sqlServer`, `mecm`, `adk`, `adkWinPe`, `odbcDriver18`, `vcRedistX64`, and `vcRedistX86`. For each source, provide:

| Field | Purpose |
| --- | --- |
| `uri` | Approved vendor or private-vault location for the installer or media. |
| `sha256` | Expected SHA-256 checksum for the downloaded artifact. |
| `publisher` | Expected publisher for signature validation where applicable. |
| `version` | The approved installer version. |
| `architecture` | Approved target architecture: `x64`, `x86`, or `neutral`. |
| `sizeBytes` | Exact approved artifact length in bytes. |
| `licenseAccepted` | An explicit acknowledgement that the operator has accepted the applicable license. |
| `cacheFile` | Filename used under `cacheRoot`. |
| `signatureRelativePath` | Executable inside ISO media whose signature can be checked; used by the SQL Server and MECM entries. |

Replace all `REPLACE_WITH_*` values and example URLs before a real run. Every
non-template source requires an exact SHA-256, positive `sizeBytes`, version,
architecture, and cache filename. SQL Server and MECM must also have a usable
approved URI or vault location when the cache is absent. Source URIs and vault
paths are never copied into evidence.

## Marker acceptance

`markerAcceptance.enabled` defaults to `false`. When enabled, configuration
validation requires `safety.isolatedLab: true`, `labOnly: true`, site `LAB`,
server `LABZ1-CM01.test.gell.one`, target
`RING0IVY24-01.test.gell.one`, and resource ID `16777219`. Any mismatch fails
before a provider mutation. The Marker stage adds the remaining object, hash,
collection, and assignment gates.

## SQL and MECM settings

Use Windows identities for `sql.sysAdminAccounts`; at least one is required. Confirm that `sql.installDirectory`, `mecm.smsInstallDir`, and `mecm.prerequisitePath` exist on adequately sized storage before starting.

Set `mecm.siteCode`, `mecm.siteName`, `mecm.sqlServer`, and `mecm.siteServerFqdn` to match the isolated lab. The `testClient` name and domain must identify a separate client that can be used to validate the completed site.

## Validate before installing

After saving the local configuration, run:

```powershell
Import-Module ./src/SetupCm/SetupCm.psd1 -Force
Test-SetupCmPreflight -ConfigPath ./config/lab.local.yaml
```

Resolve every item in `Missing` before proceeding. Preflight confirms the required SQL Server and MECM license acknowledgements and that each has a configured URI, vault location, or cached file. The full MECM stage also requires the ADK, Windows PE add-on, ODBC Driver 18, and both VC++ redistributable entries.
