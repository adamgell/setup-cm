# Single-Box SCCM Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a PowerShell 7+ project that acquires approved installation sources and deploys a verified single-box MECM primary site through reusable, testable stages.

**Architecture:** `setup-cm` is a PowerShell module and command-line entry point executed inside the Windows Server VM by the Autopilot Agent. A YAML configuration resolves named private-vault or vendor sources into a verified local cache, then a stage engine runs idempotent `Test`/`Apply`/`Verify` functions. Every run produces structured evidence; the MECM core is accepted only after Pester 6 and live health checks pass.

**Tech Stack:** PowerShell 7+, Pester 6, `powershell-yaml`, Windows Server, SQL Server, Microsoft Configuration Manager, Autopilot Agent source bundles, CodeRabbit.

## Global Constraints

- Require PowerShell 7 or newer; fail before performing any stage action on older hosts.
- Require Pester 6 for all test execution.
- Treat installer media and secrets as private-vault/cache content, never Git content.
- Verify each acquired artifact by its declared SHA-256 and, when declared, Authenticode publisher.
- Default to isolated-lab targets; reject production-target configuration unless `safety.allowProductionTarget` is explicitly `true`.
- Implement every stage as `Test`, `Apply`, and `Verify`; stop on unsafe partial state.
- Write all run evidence under `artifacts/<run-id>/`, which remains ignored by Git.
- Run CodeRabbit review after meaningful changes; approve each auto-fix independently and rerun affected Pester tests.

---

## File structure

| Path | Responsibility |
| --- | --- |
| `src/SetupCm/SetupCm.psd1` | Module manifest and exported command list. |
| `src/SetupCm/SetupCm.psm1` | Loads private and public module functions. |
| `src/SetupCm/Private/Configuration.ps1` | YAML parsing, schema validation, and safety checks. |
| `src/SetupCm/Private/Evidence.ps1` | Run-folder creation and structured stage-result writes. |
| `src/SetupCm/Private/Acquisition.ps1` | Private-vault/vendor download, hash, signature, and cache verification. |
| `src/SetupCm/Private/StageEngine.ps1` | Shared idempotent stage executor and resume decisions. |
| `src/SetupCm/Private/Sql.ps1` | SQL prerequisite and unattended SQL Server installation stage. |
| `src/SetupCm/Private/Mecm.ps1` | MECM prerequisite download, primary-site installation, and role configuration stage. |
| `src/SetupCm/Private/Health.ps1` | SQL, MECM, MP, DP, boundary, and client acceptance checks. |
| `src/SetupCm/Public/Invoke-SetupCm.ps1` | Guided/unattended command entry point. |
| `src/SetupCm/Public/Invoke-SetupCmAcquire.ps1` | Acquisition-only command for cache warming and diagnostics. |
| `config/lab.example.yaml` | Complete non-secret single-box configuration example. |
| `tests/Unit/*.Tests.ps1` | Pester 6 unit tests for every private contract. |
| `tests/Integration/SingleBox.Tests.ps1` | Pester 6 live-lab acceptance suite. |
| `scripts/Invoke-SetupCm.ps1` | Autopilot-Agent-compatible source-bundle entry script. |
| `docs/RUNBOOK.md` | Guided, unattended, reset, resume, and evidence procedures. |
| `.github/workflows/test.yml` | PowerShell 7/Pester 6 unit-test and lint gate. |

## Task 1: Scaffold the PowerShell 7 module and Pester 6 test harness

**Files:**
- Create: `src/SetupCm/SetupCm.psd1`
- Create: `src/SetupCm/SetupCm.psm1`
- Create: `src/SetupCm/Public/Invoke-SetupCm.ps1`
- Create: `src/SetupCm/Public/Invoke-SetupCmAcquire.ps1`
- Create: `tests/Unit/Module.Tests.ps1`
- Create: `.github/workflows/test.yml`

**Interfaces:**
- Produces: `Invoke-SetupCm -ConfigPath <string> -Mode Guided|Unattended -Stage <string[]>`.
- Produces: `Invoke-SetupCmAcquire -ConfigPath <string>`.
- Consumes: PowerShell 7 and Pester module major version 6.

- [ ] **Step 1: Write the failing module-load test**

```powershell
Describe 'SetupCm module' {
    It 'requires PowerShell 7 or newer' {
        $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
    }

    It 'exports the two public commands' {
        Import-Module "$PSScriptRoot/../../src/SetupCm/SetupCm.psd1" -Force
        Get-Command Invoke-SetupCm, Invoke-SetupCmAcquire | Should -HaveCount 2
    }
}
```

- [ ] **Step 2: Run the test to confirm the missing module fails**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Module.Tests.ps1 -Output Detailed'`

Expected: FAIL because `SetupCm.psd1` does not exist.

- [ ] **Step 3: Create the manifest, module loader, and public-command stubs**

```powershell
# src/SetupCm/SetupCm.psm1
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'SetupCm requires PowerShell 7 or newer.' }
Get-ChildItem "$PSScriptRoot/Private/*.ps1" | ForEach-Object { . $_.FullName }
Get-ChildItem "$PSScriptRoot/Public/*.ps1" | ForEach-Object { . $_.FullName }
Export-ModuleMember -Function Invoke-SetupCm, Invoke-SetupCmAcquire
```

```powershell
# src/SetupCm/Public/Invoke-SetupCm.ps1
function Invoke-SetupCm {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ConfigPath,
          [ValidateSet('Guided','Unattended')][string]$Mode = 'Guided',
          [string[]]$Stage)
    throw 'Stage engine is not implemented yet.'
}
```

- [ ] **Step 4: Make Pester 6 explicit in the CI workflow**

```yaml
- shell: pwsh
  run: |
    Install-Module Pester -RequiredVersion 6.0.0 -Force -Scope CurrentUser
    Invoke-Pester ./tests/Unit -Output Detailed -CI
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Module.Tests.ps1 -Output Detailed'`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/SetupCm tests/Unit/Module.Tests.ps1 .github/workflows/test.yml
git commit -m "feat: scaffold PowerShell module and Pester tests"
```

## Task 2: Define and validate the non-secret YAML configuration contract

**Files:**
- Create: `config/lab.example.yaml`
- Create: `src/SetupCm/Private/Configuration.ps1`
- Create: `tests/Unit/Configuration.Tests.ps1`

**Interfaces:**
- Produces: `Read-SetupCmConfig -Path <string>` returning a `[hashtable]`.
- Produces: `Assert-SetupCmConfig -Config <hashtable>` returning the same configuration or throwing a precise message.
- Consumes: `topology`, `safety`, `sources`, `sql`, `mecm`, and `evidenceRoot` keys.

- [ ] **Step 1: Write failing configuration tests**

```powershell
Describe 'Assert-SetupCmConfig' {
    It 'rejects a production target without explicit approval' {
        { Assert-SetupCmConfig @{ safety = @{ isolatedLab = $false; allowProductionTarget = $false } } } |
            Should -Throw '*allowProductionTarget*'
    }

    It 'requires SQL and MECM source names' {
        { Assert-SetupCmConfig @{ safety = @{ isolatedLab = $true }; sources = @{} } } |
            Should -Throw '*sqlServer*'
    }
}
```

- [ ] **Step 2: Run the tests to confirm missing functions fail**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Configuration.Tests.ps1 -Output Detailed'`

Expected: FAIL because `Assert-SetupCmConfig` is undefined.

- [ ] **Step 3: Implement parsing and validation**

```powershell
function Assert-SetupCmConfig {
    param([Parameter(Mandatory)][hashtable]$Config)
    if (-not $Config.safety.isolatedLab -and -not $Config.safety.allowProductionTarget) {
        throw 'safety.allowProductionTarget must be true when safety.isolatedLab is false.'
    }
    foreach ($required in 'sqlServer','mecm') {
        if (-not $Config.sources.ContainsKey($required)) { throw "sources.$required is required." }
    }
    $Config
}
```

Include `sources.sqlServer`, `sources.mecm`, and `sources.prerequisites` entries with `uri`, `sha256`, `publisher`, `version`, `licenseAccepted`, and `cacheFile` fields. Make the example choose `topology: single-box` and `safety.isolatedLab: true`.

- [ ] **Step 4: Run unit tests**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Configuration.Tests.ps1 -Output Detailed'`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add config/lab.example.yaml src/SetupCm/Private/Configuration.ps1 tests/Unit/Configuration.Tests.ps1
git commit -m "feat: add validated lab configuration"
```

## Task 3: Implement verified acquisition from vendor sources and private installer vaults

**Files:**
- Create: `src/SetupCm/Private/Acquisition.ps1`
- Create: `src/SetupCm/Private/Evidence.ps1`
- Create: `tests/Unit/Acquisition.Tests.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCmAcquire.ps1`

**Interfaces:**
- Produces: `Get-SetupCmArtifact -Source <hashtable> -CacheRoot <string> -EvidenceRoot <string>` returning `{ Name, Path, Sha256, SourceUri, VerifiedAt }`.
- Produces: `New-SetupCmRunEvidence -Root <string>` returning a run folder path.
- Consumes: validated `sources` entries from `Read-SetupCmConfig`.

- [ ] **Step 1: Write failing cache and integrity tests**

```powershell
Describe 'Get-SetupCmArtifact' {
    It 'uses a matching cached artifact without downloading' {
        $result = Get-SetupCmArtifact -Source @{ name='sql'; cacheFile='sql.iso'; sha256=$script:KnownHash } -CacheRoot $TestDrive -EvidenceRoot $TestDrive
        $result.Path | Should -Be (Join-Path $TestDrive 'sql.iso')
    }

    It 'rejects a hash mismatch' {
        { Get-SetupCmArtifact -Source @{ name='mecm'; uri='https://example.invalid/mecm.iso'; sha256='00' } -CacheRoot $TestDrive -EvidenceRoot $TestDrive } |
            Should -Throw '*SHA-256*'
    }
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Acquisition.Tests.ps1 -Output Detailed'`

Expected: FAIL because `Get-SetupCmArtifact` is undefined.

- [ ] **Step 3: Implement cache-first acquisition and evidence**

```powershell
function Get-SetupCmArtifact {
    param([hashtable]$Source,[string]$CacheRoot,[string]$EvidenceRoot)
    $path = Join-Path $CacheRoot $Source.cacheFile
    if (-not (Test-Path $path)) { Invoke-WebRequest -Uri $Source.uri -OutFile $path }
    $actual = (Get-FileHash -Algorithm SHA256 -Path $path).Hash.ToLowerInvariant()
    if ($actual -ne $Source.sha256.ToLowerInvariant()) { throw "SHA-256 mismatch for $($Source.name)." }
    [pscustomobject]@{ Name=$Source.name; Path=$path; Sha256=$actual; SourceUri=$Source.uri; VerifiedAt=(Get-Date).ToUniversalTime() }
}
```

Write the returned metadata to `artifacts/<run-id>/acquisition.json`. Before retrieval, fail if `licenseAccepted` is not true. If `publisher` is non-empty, call `Get-AuthenticodeSignature` and require a valid signature with that subject string.

- [ ] **Step 4: Run unit tests**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Acquisition.Tests.ps1 -Output Detailed'`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/SetupCm/Private/Acquisition.ps1 src/SetupCm/Private/Evidence.ps1 src/SetupCm/Public/Invoke-SetupCmAcquire.ps1 tests/Unit/Acquisition.Tests.ps1
git commit -m "feat: acquire and verify installer sources"
```

## Task 4: Build the resumable stage engine and Autopilot Agent entry script

**Files:**
- Create: `src/SetupCm/Private/StageEngine.ps1`
- Create: `scripts/Invoke-SetupCm.ps1`
- Create: `tests/Unit/StageEngine.Tests.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`

**Interfaces:**
- Produces: `Invoke-SetupCmStage -Name <string> -Test <scriptblock> -Apply <scriptblock> -Verify <scriptblock> -EvidenceRoot <string>`.
- Produces: stage result JSON with `name`, `state`, `startedAt`, `finishedAt`, and `message`.
- Consumes: `Get-SetupCmArtifact` and later SQL/MECM stage functions.

- [ ] **Step 1: Write failing idempotency and failure tests**

```powershell
Describe 'Invoke-SetupCmStage' {
    It 'skips Apply when Test reports Compliant' {
        $applied = $false
        $result = Invoke-SetupCmStage -Name Sample -Test { 'Compliant' } -Apply { $applied = $true } -Verify { 'Compliant' } -EvidenceRoot $TestDrive
        $applied | Should -BeFalse
        $result.state | Should -Be 'Skipped'
    }

    It 'does not run Verify after Apply throws' {
        { Invoke-SetupCmStage -Name Sample -Test { 'NotCompliant' } -Apply { throw 'blocked' } -Verify { throw 'must not run' } -EvidenceRoot $TestDrive } |
            Should -Throw '*blocked*'
    }
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/StageEngine.Tests.ps1 -Output Detailed'`

Expected: FAIL because `Invoke-SetupCmStage` is undefined.

- [ ] **Step 3: Implement the stage state machine**

```powershell
function Invoke-SetupCmStage {
    param([string]$Name,[scriptblock]$Test,[scriptblock]$Apply,[scriptblock]$Verify,[string]$EvidenceRoot)
    if (& $Test -eq 'Compliant') { return [pscustomobject]@{ name=$Name; state='Skipped' } }
    & $Apply
    if (& $Verify -ne 'Compliant') { throw "$Name verification failed." }
    [pscustomobject]@{ name=$Name; state='Succeeded' }
}
```

Persist both successful and failed stage results before returning or throwing. Make `scripts/Invoke-SetupCm.ps1` import the module and invoke `Invoke-SetupCm -ConfigPath $env:SETUPCM_CONFIG -Mode Unattended`; this is the Autopilot Agent's source-bundle command contract.

- [ ] **Step 4: Run unit tests**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/StageEngine.Tests.ps1 -Output Detailed'`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/SetupCm/Private/StageEngine.ps1 src/SetupCm/Public/Invoke-SetupCm.ps1 scripts/Invoke-SetupCm.ps1 tests/Unit/StageEngine.Tests.ps1
git commit -m "feat: add resumable deployment stages"
```

## Task 5: Implement Windows prerequisites and the single-box SQL Server stage

**Files:**
- Create: `src/SetupCm/Private/Sql.ps1`
- Create: `tests/Unit/Sql.Tests.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`

**Interfaces:**
- Produces: `Test-SetupCmSql`, `Install-SetupCmWindowsPrerequisites`, `Install-SetupCmSql`, and `Verify-SetupCmSql`.
- Consumes: verified `sqlServer` artifact and configuration keys `sql.instanceName`, `sql.serviceAccount`, and `sql.installDirectory`.
- Produces: a single-box SQL instance ready for MECM setup.

- [ ] **Step 1: Write failing SQL-stage tests**

```powershell
Describe 'Test-SetupCmSql' {
    It 'returns Compliant when the configured SQL service exists' {
        Mock Get-Service { [pscustomobject]@{ Status = 'Running' } }
        Test-SetupCmSql -InstanceName 'MSSQLSERVER' | Should -Be 'Compliant'
    }
}
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Sql.Tests.ps1 -Output Detailed'`

Expected: FAIL because `Test-SetupCmSql` is undefined.

- [ ] **Step 3: Implement prerequisite and SQL functions**

```powershell
function Install-SetupCmSql {
    param([string]$MediaPath,[hashtable]$Sql)
    $arguments = @('/Q','/ACTION=Install','/FEATURES=SQLENGINE','/INSTANCENAME=' + $Sql.instanceName,
                   '/SQLSVCACCOUNT=' + $Sql.serviceAccount,'/IACCEPTSQLSERVERLICENSETERMS')
    Start-Process -FilePath (Join-Path $MediaPath 'setup.exe') -ArgumentList $arguments -Wait -NoNewWindow
}
```

Install required Windows features before SQL setup. Make all SQL directory, service-account, and collation values configuration-driven. Require a successful process exit code and a running configured SQL service during verification.

- [ ] **Step 4: Run unit tests**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Sql.Tests.ps1 -Output Detailed'`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/SetupCm/Private/Sql.ps1 tests/Unit/Sql.Tests.ps1 src/SetupCm/Public/Invoke-SetupCm.ps1
git commit -m "feat: add SQL Server prerequisite stage"
```

## Task 6: Implement MECM primary-site and core-role stages

**Files:**
- Create: `src/SetupCm/Private/Mecm.ps1`
- Create: `tests/Unit/Mecm.Tests.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`

**Interfaces:**
- Produces: `Install-SetupCmMecmPrerequisites`, `Install-SetupCmPrimarySite`, and `Test-SetupCmPrimarySite`.
- Consumes: verified MECM source, installed SQL stage, site code, site name, and server FQDN from configuration.
- Produces: a primary site with Management Point and Distribution Point on the same server.

- [ ] **Step 1: Write failing MECM command-construction tests**

```powershell
Describe 'New-SetupCmPrimarySiteArguments' {
    It 'uses the configured primary-site code and SQL server' {
        $args = New-SetupCmPrimarySiteArguments -Mecm @{ siteCode='LAB'; siteName='Lab Primary'; sqlServer='CM01.test.gell.one' }
        $args | Should -Contain '/sitecode=LAB'
        $args | Should -Contain '/sqlserver=CM01.test.gell.one'
    }
}
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Mecm.Tests.ps1 -Output Detailed'`

Expected: FAIL because `New-SetupCmPrimarySiteArguments` is undefined.

- [ ] **Step 3: Implement MECM preparation and installation**

```powershell
function New-SetupCmPrimarySiteArguments {
    param([hashtable]$Mecm)
    @('/script',"/sitecode=$($Mecm.siteCode)","/sitename=$($Mecm.siteName)","/sqlserver=$($Mecm.sqlServer)")
}
```

Implement prerequisite-download invocation, unattended setup answer-file generation, and setup execution from verified media. Do not hard-code site code, server names, or media paths. Verify MECM services and configured site presence before adding MP and DP roles; write setup and prerequisite logs to the run evidence folder.

- [ ] **Step 4: Run unit tests**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Mecm.Tests.ps1 -Output Detailed'`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/SetupCm/Private/Mecm.ps1 tests/Unit/Mecm.Tests.ps1 src/SetupCm/Public/Invoke-SetupCm.ps1
git commit -m "feat: add single-box MECM deployment stage"
```

## Task 7: Add live health validation, client proof, and CMTrace Open fixture curation

**Files:**
- Create: `src/SetupCm/Private/Health.ps1`
- Create: `tests/Unit/Health.Tests.ps1`
- Create: `tests/Integration/SingleBox.Tests.ps1`
- Create: `fixtures/README.md`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`

**Interfaces:**
- Produces: `Test-SetupCmLabHealth -Config <hashtable> -EvidenceRoot <string>` returning `Compliant` only when all core checks pass.
- Produces: `Export-SetupCmFixture -SourcePath <string> -FixtureRoot <string>`.
- Consumes: a completed SQL/MECM deployment and a test client defined in configuration.

- [ ] **Step 1: Write failing health aggregation tests**

```powershell
Describe 'Test-SetupCmLabHealth' {
    It 'returns NotCompliant when the Management Point check fails' {
        Mock Test-SetupCmManagementPoint { $false }
        Mock Test-SetupCmDistributionPoint { $true }
        Test-SetupCmLabHealth -Config @{} -EvidenceRoot $TestDrive | Should -Be 'NotCompliant'
    }
}
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Health.Tests.ps1 -Output Detailed'`

Expected: FAIL because `Test-SetupCmLabHealth` is undefined.

- [ ] **Step 3: Implement health checks and fixture export**

```powershell
function Test-SetupCmLabHealth {
    param([hashtable]$Config,[string]$EvidenceRoot)
    $checks = @(Test-SetupCmSql -InstanceName $Config.sql.instanceName,
                Test-SetupCmManagementPoint,
                Test-SetupCmDistributionPoint,
                Test-SetupCmClient -ComputerName $Config.testClient.name)
    if ($checks -contains $false) { return 'NotCompliant' }
    'Compliant'
}
```

The integration test must assert SQL reachability, site service health, MP and DP health, a configured boundary, and a reporting test client. Export only explicitly selected logs after applying the project's sanitizer; write fixture metadata containing source role, log name, capture time, and expected parser assertion.

- [ ] **Step 4: Run unit tests and the lab-only integration suite**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit -Output Detailed'`

Expected: PASS.

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Integration/SingleBox.Tests.ps1 -Output Detailed'`

Expected: PASS on the completed single-box lab; otherwise FAIL with a named health check.

- [ ] **Step 5: Commit**

```bash
git add src/SetupCm/Private/Health.ps1 tests/Unit/Health.Tests.ps1 tests/Integration/SingleBox.Tests.ps1 fixtures/README.md src/SetupCm/Public/Invoke-SetupCm.ps1
git commit -m "feat: validate single-box MECM health"
```

## Task 8: Document operator flows and complete the quality gate

**Files:**
- Create: `docs/RUNBOOK.md`
- Modify: `README.md`
- Modify: `.github/workflows/test.yml`

**Interfaces:**
- Consumes: public commands, configuration example, evidence path, and stage names implemented by Tasks 1-7.
- Produces: repeatable guided/unattended/reset/resume/module operator procedures.

- [ ] **Step 1: Write the documentation acceptance test**

```powershell
Describe 'operator documentation' {
    It 'names guided, unattended, reset, resume, and module workflows' {
        $runbook = Get-Content "$PSScriptRoot/../../docs/RUNBOOK.md" -Raw
        foreach ($heading in 'Guided','Unattended','Reset','Resume','Modules') { $runbook | Should -Match $heading }
    }
}
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit/Documentation.Tests.ps1 -Output Detailed'`

Expected: FAIL because `docs/RUNBOOK.md` does not exist.

- [ ] **Step 3: Write concise operator procedures**

Document exact commands for cache warming, guided stage selection, unattended execution through `scripts/Invoke-SetupCm.ps1`, lab reset through ProxmoxVEAutopilot, safe stage resume, evidence inspection, and future module enablement. Document the private-vault artifact manifest and SHA-256/signature requirements.

- [ ] **Step 4: Add quality commands to CI and README**

```yaml
- shell: pwsh
  run: Invoke-Pester ./tests/Unit -Output Detailed -CI
```

Add README commands:

```powershell
pwsh ./src/SetupCm/Public/Invoke-SetupCmAcquire.ps1 -ConfigPath ./config/lab.local.yaml
pwsh ./scripts/Invoke-SetupCm.ps1
```

- [ ] **Step 5: Run all unit tests and CodeRabbit review**

Run: `pwsh -NoProfile -Command 'Invoke-Pester ./tests/Unit -Output Detailed'`

Expected: PASS.

Run: `coderabbit review --agent -t uncommitted`

Expected: no Critical or Warning finding remains. Independently validate each finding before proposing any auto-fix.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/RUNBOOK.md .github/workflows/test.yml tests/Unit/Documentation.Tests.ps1
git commit -m "docs: add SCCM lab operator runbook"
```

## Spec coverage review

- Single-box MECM primary site with SQL, MP, and DP: Tasks 5-7.
- Guided and unattended execution: Tasks 1 and 4.
- Autopilot Agent guest-side entry contract: Task 4.
- PowerShell 7+ and Pester 6: Task 1 and global constraints.
- Verified vendor/private-vault acquisition: Task 3.
- Test/Apply/Verify, stop, evidence, and resume: Task 4.
- Core health and test-client proof: Task 7.
- CMTrace Open fixture curation: Task 7.
- Add-on boundary: configuration contract and runbook; each add-on receives its own later plan.
- CodeRabbit review and guarded auto-fix: Task 8 and global constraints.

## Plan self-review

No placeholder terms are present. Function names consumed by later tasks are defined by earlier tasks or explicitly created in the same task. The plan deliberately excludes add-on implementation because the approved design requires independently testable modules after the core site passes.
