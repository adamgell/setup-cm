# MECM VC++ Redistributable Dependency Design

## Goal

Make the Microsoft Visual C++ v14 Redistributables a first-class, repeatable
MECM prerequisite so the Configuration Manager 2509 OLE DB Driver installation
does not fail on a newly built Windows Server 2022 site server.

## Evidence and scope

The contained MECM setup attempt reached `msoledbsql.msi`, which exited 1603.
Its MSI log states that Microsoft Visual C++ Redistributable for Visual Studio
2022, x64 and x86, version 14.34 or later is required. This design adds only
that missing prerequisite; it does not retry MECM until the two runtime
architectures are installed and verified.

Microsoft's current v14 Redistributable permalinks are the source of truth:

- `https://aka.ms/vc14/vc_redist.x64.exe`
- `https://aka.ms/vc14/vc_redist.x86.exe`

Each private LABZ1 source record will be hash-pinned after an Agent download,
signature-validated as Microsoft Corporation, and marked license accepted under
the user's blanket software-license approval. No installer, hash manifest with
credentials, or generated local configuration is committed to Git.

## Design

`sources.vcRedistX64` and `sources.vcRedistX86` use the existing verified
acquisition contract. New MECM helpers will:

1. Read the x64 and x86 uninstall registry entries and require an installed
   `14.x` version at or above `14.34` for each architecture.
2. Acquire each source through `Get-SetupCmArtifact`, so cache reuse, SHA-256
   validation, Authenticode validation, and license enforcement remain shared.
3. Run each Microsoft installer quietly with `/install /quiet /norestart`,
   accepting exit codes 0 and 3010 only.
4. Verify both architectures before `Setupdl.exe` and `Setup.exe` are invoked.

The MECM stage fails with a precise missing-source or installer error and
never treats a failed prerequisite as successful Agent work. It is safe to
rerun: compliant architecture checks skip their installer, while absent or
outdated versions are repaired.

## Testing and verification

Pester 6 unit tests will pin:

- compliant and noncompliant version detection for each architecture;
- silent, verified x64 and x86 installation arguments and accepted reboot exit
  code;
- stage ordering: both runtime checks and repairs occur before the MECM
  prerequisite downloader.

On LABZ1-CM01, the Agent will bootstrap hashes privately, then install and
read back the two runtime versions. Only after both are compliant will the
Agent reattempt the MECM stage. The next MECM log must show the OLE DB Driver
installer proceeding past the former VC++-runtime error.
