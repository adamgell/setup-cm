# Configuration Reference

Start with `config/lab.example.yaml` and save the working copy as
`config/lab.local.yaml`. The latter is ignored by Git. Keep the private file
outside any source archive used for review or acceptance, stage it separately
on the server, and restrict its file permissions. Do not commit a working
configuration that contains internal hostnames, vault paths, credentials,
product keys, or other environment-specific data.

## Top-level settings

| Setting | Purpose |
| --- | --- |
| `topology` | Deployment shape. The supplied template uses `single-box`. |
| `template` | Keeps placeholder values valid in the committed example. Remove it or set it to `false` in a real configuration. |
| `lab` | Identifies the lab name and domain. |
| `safety` | Records whether the target is isolated and whether production targeting was explicitly acknowledged. |
| `evidenceRoot` | Stores one sanitized directory per run; keep it outside the repository. |
| `cacheRoot` | Stores verified installer artifacts; keep it outside the repository. |
| `sources` | Declares each approved installer and its integrity metadata. |
| `sql` | Configures the SQL Server instance, service identity, administrators, and install directory. |
| `mecm` | Configures the primary-site identity, SQL endpoint, site server, product identifier, and install paths. |
| `testClient` | Identifies the client used by the health stage. |
| `markerAcceptance` | Enables the fixed, lab-only marker boundary; disabled in the template. |

## Safety

Set `safety.isolatedLab: true` for the intended use case. If it is `false`, `safety.allowProductionTarget` must be explicitly `true` or configuration validation stops the run. That explicit acknowledgement is a guardrail, not approval to use this project for production deployment.

`evidenceRoot` is where each execution creates a unique run directory. `cacheRoot` is where verified installer media is retained. Place both on storage with enough space and appropriate access control. They should not be inside the repository.

## Private inputs and source revision

The working YAML and installer sources are runtime inputs, not release
artifacts. Do not include them in `git archive`, commits, evidence bundles, or
PR output. Set only the private configuration path in the environment:

```powershell
$env:SETUPCM_CONFIG = 'C:\ProgramData\SetupCm\config\lab.local.yaml'
```

Any run containing `Marker` also requires the exact full commit used to build
the staged source archive:

```powershell
$env:SETUPCM_SOURCE_COMMIT = '<FULL_40_CHARACTER_GIT_COMMIT>'
```

Abbreviated or missing commits fail before evidence creation or provider
mutation. The validated lowercase value is recorded in `run.json` and
`marker-state.json`; it does not belong in the YAML.

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

For signed executables and ISO media, `version` is the native `ProductVersion`
of the file selected by `signatureRelativePath`. Human release labels are not
interchangeable with that value: the accepted Current Branch 2509 media uses
`5.00.9141.1002`, not `2509`.

Replace all `REPLACE_WITH_*` values and example URLs before a real run. Every
non-template source requires an exact SHA-256, positive `sizeBytes`, expected
publisher, native product version, architecture, and cache filename. SQL Server
and MECM must also have a usable approved URI or vault location when the cache
is absent. Source URIs and vault paths are never copied into evidence.

## Marker acceptance

`markerAcceptance.enabled` defaults to `false`. When enabled, configuration
validation requires `safety.isolatedLab: true`, `labOnly: true`, site `LAB`,
server `LABZ1-CM01.test.gell.one`, target
`RING0IVY24-01.test.gell.one`, and resource ID `16777219`. Any mismatch fails
before a provider mutation. The Marker stage adds the remaining object, hash,
collection, and assignment gates.

The fixed feature owns only `Setup-CM Phase 1 Marker`, deployment type
`Install Setup-CM Phase 1 Marker`, and collection
`Setup-CM Phase 1 Marker - RING0IVY24-01 Only`. The collection must contain one
direct member with resource ID `16777219`, no other rule, and no marker
assignment may target another collection. The payload marker SHA-256 is
`3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254`.
Conflicting same-name objects, broader membership, another assignment, or
payload/detector drift fails closed; the command does not delete historical
objects to resolve a conflict.

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
