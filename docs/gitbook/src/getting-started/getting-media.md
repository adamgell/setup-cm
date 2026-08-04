# Getting Media

`setup-cm` does not download licensed Microsoft media automatically. The operator must obtain each installer, verify its integrity, and place it in the configured cache or private vault before the `Acquire` stage runs. This page walks through every required item.

## Media checklist

| Media | Source | Public URL? | License required? |
| --- | --- | --- | --- |
| SQL Server 2022 | VLSC / Visual Studio Subscription / Evaluation Center | No (evaluation available) | Yes |
| MECM Current Branch | VLSC / Visual Studio Subscription | No | Yes |
| Windows ADK | Microsoft Download Center | Yes | Accept EULA |
| Windows PE add-on | Microsoft Download Center | Yes | Accept EULA |
| ODBC Driver 18 | Microsoft Download Center | Yes | Accept EULA |
| VC++ Redistributable x64 | aka.ms | Yes | Accept EULA |
| VC++ Redistributable x86 | aka.ms | Yes | Accept EULA |

## Public downloads

These items can be downloaded directly without a subscription.

### Windows ADK and Windows PE add-on

The example pins version `10.1.26100.2454` (Windows 11 24H2 ADK).

```powershell
# ADK
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2289980" `
  -OutFile "adksetup.exe"

# Windows PE add-on
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2289981" `
  -OutFile "adkwinpesetup.exe"
```

> **Note:** The `fwlink` URLs above are Microsoft's stable download links. They redirect to the current ADK build. If Microsoft releases a newer ADK, the link may serve a different version than the example pins. Verify the product version after download and update `lab.local.yaml` if needed.

### ODBC Driver 18 for SQL Server

Download from the [Microsoft ODBC Driver 18 download page](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server). The example pins `18.4.1.1` (x64 MSI).

Direct link pattern:
```
https://go.microsoft.com/fwlink/?linkid=2242886
```

Save as `msodbcsql18-x64.msi`.

### VC++ Redistributables

Download both architectures from Microsoft's evergreen links:

```powershell
# x64
Invoke-WebRequest -Uri "https://aka.ms/vc14/vc_redist.x64.exe" `
  -OutFile "vc_redist.x64.exe"

# x86
Invoke-WebRequest -Uri "https://aka.ms/vc14/vc_redist.x86.exe" `
  -OutFile "vc_redist.x86.exe"
```

The example pins `14.44.35211.0`. The minimum required by `setup-cm` is `14.34`. The `aka.ms` links always serve the latest VC++ v14 build, so the version will advance over time. Record the actual version in your `lab.local.yaml`.

## Subscription / VLSC downloads

These items require a Microsoft Volume License Service Center (VLSC) account, Visual Studio Subscription, or evaluation download.

### SQL Server 2022

- **Evaluation:** [SQL Server 2022 Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2022) — 180-day trial, ISO download.
- **VLSC / Visual Studio Subscription:** Download the ISO from your subscriber portal.

The example pins `16.0.1000.6` (SQL Server 2022 RTM). Save as `sql-server.iso`.

> **Important:** The evaluation ISO is suitable for lab use. Do not use evaluation media for production.

### MECM Current Branch

- **Evaluation:** [Microsoft Configuration Manager Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-microsoft-endpoint-configuration-manager) — 180-day trial.
- **VLSC / Visual Studio Subscription:** Download from your subscriber portal.

The example pins `2503` (March 2025 Current Branch). Save as `mecm.iso`.

> **Important:** MECM evaluation media is lab-appropriate. The `productId: Eval` setting in the example configuration matches evaluation media.

## Verifying downloads

Every source entry in `lab.local.yaml` requires a SHA-256 checksum. Compute it after downloading.

### Windows (PowerShell)

```powershell
Get-FileHash -Path "C:\Downloads\sql-server.iso" -Algorithm SHA256
```

### macOS / Linux

```bash
shasum -a 256 sql-server.iso
```

Record the 64-character hexadecimal string in the `sha256` field. The `Acquire` stage will reject the file if the hash does not match exactly.

## Placing media

You have two options for each installer:

### Option A: Local cache (recommended for public downloads)

Place the file directly in the configured `cacheRoot` with the filename matching `cacheFile`:

```yaml
cacheRoot: C:\ProgramData\SetupCm\cache
sources:
  adk:
    cacheFile: adksetup.exe
    # ...
```

So the ADK installer goes to:
```
C:\ProgramData\SetupCm\cache\adksetup.exe
```

The `Acquire` stage finds the cached file, verifies its SHA-256, and skips the download.

### Option B: Private vault / file share (recommended for licensed media)

Place licensed ISOs on a secure file share or vault that the lab server can reach:

```yaml
sources:
  sqlServer:
    uri: \\LAB-FS01\Vault\SQLServer\sql-server.iso
    # or
    uri: https://installer-vault.internal/sql-server.iso
    # ...
```

The `Acquire` stage downloads from the URI to the local cache, then verifies integrity.

> **Security:** Never commit actual installer files, product keys, or internal vault paths to Git. The `lab.local.yaml` file is ignored by Git for this reason.

## License acceptance

Before the `Acquire` stage runs, every source must have `licenseAccepted: true` in `lab.local.yaml`. This is an explicit operator acknowledgement that you have accepted the applicable license terms.

```yaml
sources:
  sqlServer:
    licenseAccepted: true   # You accept the SQL Server license terms
  mecm:
    licenseAccepted: true   # You accept the MECM license terms
  # ... repeat for all sources
```

Preflight validation (`Test-SetupCmPreflight`) will report any source where `licenseAccepted` is still `false`.

## Complete acquisition checklist

Before running `Invoke-SetupCm`:

- [ ] SQL Server 2022 ISO downloaded, SHA-256 recorded, placed in cache/vault
- [ ] MECM Current Branch ISO downloaded, SHA-256 recorded, placed in cache/vault
- [ ] ADK downloaded, SHA-256 recorded, placed in cache
- [ ] Windows PE add-on downloaded, SHA-256 recorded, placed in cache
- [ ] ODBC Driver 18 MSI downloaded, SHA-256 recorded, placed in cache
- [ ] VC++ x64 downloaded, SHA-256 recorded, placed in cache
- [ ] VC++ x86 downloaded, SHA-256 recorded, placed in cache
- [ ] All `licenseAccepted` fields set to `true` in `lab.local.yaml`
- [ ] All `sha256` fields updated with actual computed hashes
- [ ] `Test-SetupCmPreflight` returns `Ready: True`
