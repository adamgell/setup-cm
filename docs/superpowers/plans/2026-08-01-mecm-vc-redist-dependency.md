# MECM VC++ Redistributable Dependency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Status (2026-08-30):** Complete. The safe source contract is on `main`,
> the private LabZ1 source metadata was pinned during accepted bootstrap, and a
> fresh read-only check confirms both runtime architectures exceed 14.34.

**Goal:** Install and verify Microsoft VC++ v14 x64 and x86 runtimes before MECM downloads prerequisites or runs setup.

**Architecture:** Extend the MECM prerequisite layer with per-architecture registry version checks and a generic verified installer runner. The MECM stage repairs only missing or outdated architectures, then blocks `Setupdl.exe` until both meet 14.34.

**Tech Stack:** PowerShell 7+, Pester 6, `Get-SetupCmArtifact`, Autopilot Agent.

## Global Constraints

- Use PowerShell 7+ and Pester 6.
- Route VM-side installation through the Autopilot Agent.
- Keep installers, LABZ1 hashes, local configuration, credentials, and keys out of Git.
- Require `sources.vcRedistX64` and `sources.vcRedistX86` with `licenseAccepted=true`.
- Require both Microsoft VC++ v14 architectures at 14.34 or newer.
- Allow only installer exit codes 0 and 3010.

---

### Task 1: Pin runtime detection with Pester

**Files:**
- Modify: `tests/Unit/Mecm.Tests.ps1`
- Modify: `src/SetupCm/Private/Mecm.ps1`

**Interfaces:**
- Produces: `Test-SetupCmMecmVcRedistArchitecture -Architecture <x64|x86> [-RegistryProvider <scriptblock>]` returning `Compliant` or `NotCompliant`.
- Produces: `Test-SetupCmMecmVcRedist [-RegistryProvider <scriptblock>]` returning `Compliant` only if both architectures comply.

- [x] **Step 1: Write failing version detection tests**

```powershell
It 'requires an installed VC++ v14 runtime at or above 14.34 for each architecture' {
    Test-SetupCmMecmVcRedistArchitecture -Architecture x64 -RegistryProvider {
        param($Architecture)
        @{ Installed = 1; Version = 'v14.34.31938.0' }
    } | Should -Be 'Compliant'
    Test-SetupCmMecmVcRedistArchitecture -Architecture x86 -RegistryProvider {
        param($Architecture)
        @{ Installed = 1; Version = '14.33.31629.0' }
    } | Should -Be 'NotCompliant'
}
It 'requires both VC++ runtime architectures before MECM is compliant' {
    Test-SetupCmMecmVcRedist -RegistryProvider {
        param($Architecture)
        if ($Architecture -eq 'x64') { @{ Installed = 1; Version = '14.44.35211.0' } }
        else { @{ Installed = 0; Version = '14.44.35211.0' } }
    } | Should -Be 'NotCompliant'
}
```

- [x] **Step 2: Verify red**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Mecm.Tests.ps1 -Output Detailed -CI'`

Expected: FAIL because `Test-SetupCmMecmVcRedistArchitecture` does not yet exist.

- [x] **Step 3: Implement minimal detection**

```powershell
function Test-SetupCmMecmVcRedistArchitecture {
    param(
        [Parameter(Mandatory)][ValidateSet('x64', 'x86')][string]$Architecture,
        [scriptblock]$RegistryProvider = {
            param($Architecture)
            Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$Architecture" -ErrorAction SilentlyContinue
        }
    )
    $runtime = & $RegistryProvider $Architecture
    if ($null -eq $runtime -or [int]$runtime.Installed -ne 1) { return 'NotCompliant' }
    try { $version = [version]([string]$runtime.Version).TrimStart('v') } catch { return 'NotCompliant' }
    if ($version -lt [version]'14.34') { return 'NotCompliant' }
    return 'Compliant'
}
function Test-SetupCmMecmVcRedist {
    param([scriptblock]$RegistryProvider)
    foreach ($architecture in 'x64', 'x86') {
        if ((Test-SetupCmMecmVcRedistArchitecture -Architecture $architecture -RegistryProvider $RegistryProvider) -ne 'Compliant') { return 'NotCompliant' }
    }
    return 'Compliant'
}
```

- [x] **Step 4: Verify green**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Mecm.Tests.ps1 -Output Detailed -CI'`

Expected: PASS, including both VC++ detection tests.

### Task 2: Pin verified installation and stage order

**Files:**
- Modify: `tests/Unit/Mecm.Tests.ps1`
- Modify: `src/SetupCm/Private/Mecm.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`

**Interfaces:**
- Produces: `Install-SetupCmMecmVcRedist -Source <hashtable> -CacheRoot <string> -EvidenceRoot <string>`.
- Consumes: `Get-SetupCmArtifact` and the detection functions from Task 1.

- [x] **Step 1: Write failing silent-install and ordering tests**

```powershell
It 'installs a verified VC++ redistributable silently' {
    $script:IsWindows = $true
    Mock Get-SetupCmArtifact { [pscustomobject]@{ Path = 'C:\SetupCm\cache\vc_redist.x64.exe' } }
    Mock Start-Process { [pscustomobject]@{ ExitCode = 3010 } }
    Install-SetupCmMecmVcRedist -Source @{ name = 'vcRedistX64'; licenseAccepted = $true } -CacheRoot 'C:\SetupCm\cache' -EvidenceRoot $TestDrive
    Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
        $FilePath -eq 'C:\SetupCm\cache\vc_redist.x64.exe' -and
        $ArgumentList -contains '/install' -and $ArgumentList -contains '/quiet' -and $ArgumentList -contains '/norestart'
    }
}
```

Add `vcRedistX64` and `vcRedistX86` to the stage test configuration. Mock each architecture as noncompliant and assert two install calls occur before `Get-SetupCmMecmPrerequisites`.

- [x] **Step 2: Verify red**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Mecm.Tests.ps1 -Output Detailed -CI'`

Expected: FAIL because `Install-SetupCmMecmVcRedist` does not yet exist.

- [x] **Step 3: Implement verified installation and gate MECM**

```powershell
function Install-SetupCmMecmVcRedist {
    param(
        [Parameter(Mandatory)][hashtable]$Source,
        [Parameter(Mandatory)][string]$CacheRoot,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )
    if (-not $IsWindows) { throw 'Microsoft Visual C++ Redistributable installation can only run on Windows Server.' }
    $artifact = Get-SetupCmArtifact -Source $Source -CacheRoot $CacheRoot -EvidenceRoot $EvidenceRoot
    $process = Start-Process -FilePath $artifact.Path -ArgumentList @('/install', '/quiet', '/norestart') -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -notin 0, 3010) { throw "Microsoft Visual C++ Redistributable installation failed with exit code $($process.ExitCode)." }
}
```

Require both source entries in `Invoke-SetupCm`. Test `x64` and `x86` separately; run the matching installer only if the architecture is noncompliant. Recheck `Test-SetupCmMecmVcRedist` and throw before `Get-SetupCmMecmPrerequisites` if it is not compliant.

- [x] **Step 4: Verify green**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit -Output Detailed -CI'`

Expected: PASS with no failures.

### Task 3: Make the source contract reusable and validate LABZ1 privately

**Files:**
- Modify: `config/lab.example.yaml`
- Modify: `docs/RUNBOOK.md`
- Do not commit: `C:\ProgramData\SetupCm\labz1.local.yaml`

**Interfaces:**
- Consumes: `sources.vcRedistX64` and `sources.vcRedistX86` in the existing acquisition schema.

- [x] **Step 1: Add safe example sources and runbook guidance**

```yaml
  vcRedistX64:
    uri: https://aka.ms/vc14/vc_redist.x64.exe
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    version: REPLACE_WITH_VERSION
    licenseAccepted: false
    cacheFile: vc_redist.x64.exe
  vcRedistX86:
    uri: https://aka.ms/vc14/vc_redist.x86.exe
    sha256: REPLACE_WITH_SHA256
    publisher: Microsoft Corporation
    version: REPLACE_WITH_VERSION
    licenseAccepted: false
    cacheFile: vc_redist.x86.exe
```

Document that the Agent validates and installs both runtime architectures before MECM prerequisite download.

- [x] **Step 2: Bootstrap and pin LABZ1 hashes privately**

Queue the MECM stage once with placeholder hashes. Read each cache file's SHA-256, Microsoft Authenticode status, publisher, and product version. Update only `C:\ProgramData\SetupCm\labz1.local.yaml` with validated values.

- [x] **Step 3: Prove the dependency baseline live**

Queue the Agent MECM stage. Confirm both registry runtime keys report `Installed=1` and version 14.34 or later before a new MECM attempt.

- [x] **Step 4: Commit only safe automation artifacts**

```bash
git add src/SetupCm/Private/Mecm.ps1 src/SetupCm/Public/Invoke-SetupCm.ps1 tests/Unit/Mecm.Tests.ps1 config/lab.example.yaml docs/RUNBOOK.md docs/superpowers/plans/2026-08-01-mecm-vc-redist-dependency.md
git commit -m "feat: install MECM VC++ prerequisites"
```

Accepted private validation retained no source hashes in Git. At Phase 0 the
MECM site and prerequisites passed their live gates. A 2026-08-30 read-only
registry refresh reported x64 `v14.51.36247.00` and x86 `v14.44.35211.00`, both
installed and above the required 14.34 floor. The reusable detection,
installation, source template, tests, and runbook guidance are reachable from
`main`.

## Plan self-review

- Spec coverage: Task 1 establishes the 14.34 x64/x86 contract; Task 2 installs and gates MECM; Task 3 documents sources and validates LABZ1 privately.
- Placeholder scan: `REPLACE_WITH_SHA256` and `REPLACE_WITH_VERSION` exist only in the safe template, where the existing runnable-config test rejects them.
- Type consistency: checks return `Compliant` or `NotCompliant`; installation accepts the existing source hashtable and acquisition result.
