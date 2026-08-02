# Agent-driven MECM Client Installation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install and verify the Configuration Manager client on `RING0IVY24-01` through a signed, typed Autopilot Agent work item.

**Architecture:** Keep the existing server-oriented `setup_cm_*` work contract intact. Add a constrained client-install work kind that derives the client source from a validated LAB site code and management-point FQDN, validates a SHA-256-pinned module archive, creates a local non-secret JSON manifest, and runs a Setup-CM client stage. The server verifies discovery after the client submits its local evidence.

**Tech Stack:** PowerShell 7+, Pester 6, .NET 8 AutopilotAgent, FastAPI/Pydantic, pytest, Microsoft Configuration Manager Current Branch.

## Global Constraints

- Target only `RING0IVY24-01` in `test.gell.one`; reject any other domain suffix.
- Use `LAB` and `LABZ1-CM01.test.gell.one` for this first deterministic path.
- Windows-side installation and evidence collection run only through Autopilot Agent.
- Preserve the existing `setup_cm_acquire`, `setup_cm_sql`, `setup_cm_mecm`, and `setup_cm_health` contracts.
- Accept only approved Setup-CM local/vault archive roots and a 64-character SHA-256.
- Never commit installers, passwords, tokens, product keys, private certificates, or generated credentials.
- Make reruns no-ops only when `CcmExec`, assigned site, and active MP all match the request.
- Publish a signed Agent MSI before queueing `setup_cm_client_install`; do not use a generic script work item.

---

## File structure

| Path | Responsibility |
| --- | --- |
| `src/SetupCm/Private/Client.ps1` | Client manifest validation, desired-state test, installer invocation, sanitized evidence. |
| `src/SetupCm/Public/Invoke-SetupCmClient.ps1` | Runs the Client Test/Apply/Verify stage through the existing stage engine. |
| `scripts/Invoke-SetupCmClient.ps1` | PowerShell 7 non-interactive Agent entry point. |
| `src/SetupCm/Private/Health.ps1` | Server-side ConfigMgr client-registration check and combined health artifact. |
| `tests/Unit/Client.Tests.ps1` | Pester contracts for manifest validation, install arguments, reruns, and redaction. |
| `tests/Unit/Health.Tests.ps1` | Pester contracts for the server registration gate. |
| `../ProxmoxVEAutopilot/autopilot-agent/src/AutopilotAgent/SetupCmWorkService.cs` | Typed client work validation, local manifest creation, and Client entry-point execution. |
| `../ProxmoxVEAutopilot/autopilot-proxmox/web/setup_cm_endpoints.py` | Typed controller request model and queue endpoint. |
| `../ProxmoxVEAutopilot/autopilot-agent/tests/AutopilotAgent.ContractTests/Program.cs` | C# contract tests for the new kind and its rejection boundaries. |
| `../ProxmoxVEAutopilot/autopilot-proxmox/tests/test_agent_v1_endpoints.py` | pytest coverage for controller validation and queued work shape. |

## Task 1: Setup-CM Client stage

**Files:**

- Create: `src/SetupCm/Private/Client.ps1`
- Create: `src/SetupCm/Public/Invoke-SetupCmClient.ps1`
- Create: `scripts/Invoke-SetupCmClient.ps1`
- Test: `tests/Unit/Client.Tests.ps1`

**Interfaces:**

- Consumes: JSON manifest `{ siteCode, managementPointFqdn, evidenceRoot }`.
- Produces: `Invoke-SetupCmClient -ManifestPath $manifestPath` and `stage-Client.json` evidence.
- Depends on: `Invoke-SetupCmStage` and `Write-SetupCmEvidenceJson`.

- [ ] **Step 1: Write failing Pester tests for the manifest boundary**

```powershell
Describe 'Read-SetupCmClientManifest' {
    It 'accepts LABZ1 client settings' {
        $manifest = Read-SetupCmClientManifest -Path $manifestPath
        $manifest.siteCode | Should -Be 'LAB'
        $manifest.managementPointFqdn | Should -Be 'LABZ1-CM01.test.gell.one'
    }

    It 'rejects a non-LABZ1 management point' {
        { Read-SetupCmClientManifest -Path $outsideDomainManifest } |
            Should -Throw '*test.gell.one*'
    }
}
```

- [ ] **Step 2: Run the focused test and confirm it fails because the function is missing**

Run: `pwsh -NoProfile -Command "Invoke-Pester ./tests/Unit/Client.Tests.ps1 -Output Detailed"`

Expected: FAIL referencing `Read-SetupCmClientManifest`.

- [ ] **Step 3: Implement the minimal client stage**

Create `Client.ps1` with these public/private contracts:

```powershell
function Read-SetupCmClientManifest { param([string]$Path) }
function Test-SetupCmClientInstallation { param([hashtable]$Manifest) }
function Install-SetupCmClient { param([hashtable]$Manifest) }
function Get-SetupCmClientEvidence { param([hashtable]$Manifest) }
```

Require `siteCode` to match `^[A-Z0-9]{3}$`, require the FQDN to end in
`.test.gell.one`, derive the only permitted installer path as
`\\<managementPointFqdn>\SMS_<siteCode>\Client\ccmsetup.exe`, and invoke it
with `@("/mp:$($Manifest.managementPointFqdn)", "SMSSITECODE=$($Manifest.siteCode)")`.
Treat exit codes `0` and `3010` as successful launch results. Test compliance
from `CcmExec`, assigned site, and last valid MP. Store only redacted tails of
`C:\Windows\CCMSetup\Logs\ccmsetup.log` and
`C:\Windows\CCM\Logs\ClientIDManagerStartup.log`.

Create `Invoke-SetupCmClient.ps1` so it creates an evidence run and calls
`Invoke-SetupCmStage -Name Client` with the client Test, Apply, and Verify
functions. Create the script entry point with `-ManifestPath`, import the
module, and call `Invoke-SetupCmClient`.

- [ ] **Step 4: Complete the Pester contract and make it pass**

Add tests that inject file/service/registry/process providers and prove:

```powershell
Test-SetupCmClientInstallation -Manifest $matchingManifest | Should -Be 'Compliant'
Test-SetupCmClientInstallation -Manifest $wrongMpManifest | Should -Be 'NotCompliant'
```

Also assert the exact `ccmsetup.exe` path and arguments, no process launch on
a compliant target, failed installer output is sanitized, and no raw
`Password=` value reaches evidence.

Run: `pwsh -NoProfile -Command "Invoke-Pester ./tests/Unit/Client.Tests.ps1 -Output Detailed"`

Expected: PASS.

- [ ] **Step 5: Commit the Setup-CM client stage**

```bash
git add src/SetupCm/Private/Client.ps1 src/SetupCm/Public/Invoke-SetupCmClient.ps1 \
  scripts/Invoke-SetupCmClient.ps1 tests/Unit/Client.Tests.ps1
git commit -m "feat: add MECM client installation stage"
```

## Task 2: Server-side client registration health gate

**Files:**

- Modify: `src/SetupCm/Private/Health.ps1`
- Modify: `tests/Unit/Health.Tests.ps1`

**Interfaces:**

- Consumes: `siteCode`, client computer name, and SQL site database name.
- Produces: `Test-SetupCmClientRegistration` returning a Boolean and a health
  artifact that distinguishes installed-local from discovered-server state.

- [ ] **Step 1: Write the failing health test**

```powershell
It 'requires a discovered active client record for the selected site' {
    Test-SetupCmClientRegistration -SiteCode LAB -ComputerName RING0IVY24-01 `
        -SqlQuery { 'RING0IVY24-01|1|LAB' } | Should -BeTrue
}
```

Add a second case returning `RING0IVY24-01|0|LAB` and assert `False`.

- [ ] **Step 2: Run the test and confirm it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester ./tests/Unit/Health.Tests.ps1 -Output Detailed"`

Expected: FAIL referencing `Test-SetupCmClientRegistration`.

- [ ] **Step 3: Implement the registration query and wire it into health**

Implement `Test-SetupCmClientRegistration` with an injectable query provider.
The production provider runs `sqlcmd` against `CM_<siteCode>` and queries the
ConfigMgr client-discovery view for the exact computer name, active status,
and `LAB` site code. Add the server registration result to
`Test-SetupCmLabHealth`; retain SQL, MP, DP, and local client checks.

- [ ] **Step 4: Run the focused Pester suite**

Run: `pwsh -NoProfile -Command "Invoke-Pester ./tests/Unit/Health.Tests.ps1 -Output Detailed"`

Expected: PASS with both registration states covered.

- [ ] **Step 5: Commit the server registration gate**

```bash
git add src/SetupCm/Private/Health.ps1 tests/Unit/Health.Tests.ps1
git commit -m "feat: verify MECM client server registration"
```

## Task 3: Typed Autopilot Agent client work

**Files:**

- Modify: `../ProxmoxVEAutopilot/autopilot-agent/src/AutopilotAgent/SetupCmWorkService.cs`
- Modify: `../ProxmoxVEAutopilot/autopilot-agent/tests/AutopilotAgent.ContractTests/Program.cs`

**Interfaces:**

- Consumes: `setup_cm_client_install` work with `site_code`,
  `management_point_fqdn`, `evidence_root`, archive path, and archive SHA-256.
- Produces: `client-manifest.json` under the SHA-derived Agent work root and
  a completed work item with bounded output.

- [ ] **Step 1: Add failing C# contract assertions**

```csharp
Assert(SetupCmWorkService.SupportedKinds.Contains("setup_cm_client_install"),
    "Setup-CM client work kind is not registered");
AssertThrows<InvalidOperationException>(
    () => SetupCmWorkService.ValidateRequest("setup_cm_client_install", invalidFqdn),
    "Client work accepted a non-LABZ1 management point");
```

Cover unknown request fields, a four-character site code, `server.example.com`,
an archive outside approved roots, and a malformed SHA-256.

- [ ] **Step 2: Run the contract test and confirm it fails**

Run: `dotnet run --project autopilot-agent/tests/AutopilotAgent.ContractTests/AutopilotAgent.ContractTests.csproj`

Expected: FAIL because `setup_cm_client_install` is unsupported.

- [ ] **Step 3: Implement a separate typed request path**

Add `setup_cm_client_install` to `SupportedKinds`. Keep existing request
validation unchanged for server stages. Add a client request record that
requires only the typed fields above, writes a JSON manifest into the Agent's
own work root, and invokes `scripts/Invoke-SetupCmClient.ps1 -ManifestPath`.
Do not add an arbitrary command, UNC path, or server YAML field. Keep the
archive copy, SHA validation, extraction validation, three-hour timeout, and
256 KiB output limit shared with current Setup-CM work.

- [ ] **Step 4: Run the contract test and make it pass**

Run: `dotnet run --project autopilot-agent/tests/AutopilotAgent.ContractTests/AutopilotAgent.ContractTests.csproj`

Expected: PASS, including all rejection cases and a manifest containing only
the non-secret client fields.

- [ ] **Step 5: Commit the Agent contract**

```bash
git -C ../ProxmoxVEAutopilot add autopilot-agent/src/AutopilotAgent/SetupCmWorkService.cs \
  autopilot-agent/tests/AutopilotAgent.ContractTests/Program.cs
git -C ../ProxmoxVEAutopilot commit -m "feat: add typed MECM client Agent work"
```

## Task 4: Controller queue endpoint

**Files:**

- Modify: `../ProxmoxVEAutopilot/autopilot-proxmox/web/setup_cm_endpoints.py`
- Modify: `../ProxmoxVEAutopilot/autopilot-proxmox/tests/test_agent_v1_endpoints.py`

**Interfaces:**

- Consumes: `POST /api/setup-cm/v1/agents/{agent_id}/client-install`.
- Produces: a `202` `setup_cm_client_install` work item with a fully typed,
  sanitized request body.

- [ ] **Step 1: Add failing pytest endpoint tests**

```python
response = agent_client.post(
    "/api/setup-cm/v1/agents/agent-client01/client-install",
    json={
        "site_code": "LAB",
        "management_point_fqdn": "LABZ1-CM01.test.gell.one",
        "evidence_root": r"C:\ProgramData\SetupCm\artifacts",
        "module_archive_path": r"\\LABZ1-DC02\SetupCm\Modules\setup-cm.zip",
        "module_archive_sha256": "a" * 64,
    },
)
assert response.status_code == 202
assert response.json()["kind"] == "setup_cm_client_install"
```

Add `422` tests for `LABZ1-CM01.example.com`, `LABZ`, a `product_key` field,
an unapproved archive path, and a malformed SHA-256.

- [ ] **Step 2: Run the focused pytest case and confirm it fails**

Run: `pytest -q autopilot-proxmox/tests/test_agent_v1_endpoints.py -k client_install`

Expected: FAIL because the route and model do not exist.

- [ ] **Step 3: Implement `SetupCmClientInstallBody` and the queue route**

Use Pydantic `extra="forbid"`. Validate `site_code` with
`^[A-Z0-9]{3}$`, validate the FQDN suffix exactly as `.test.gell.one`, and
reuse `_is_inside` plus the existing approved archive roots. Create the work
item with kind `setup_cm_client_install`; never persist a complete server
configuration or secret.

- [ ] **Step 4: Run focused and neighboring endpoint tests**

Run: `pytest -q autopilot-proxmox/tests/test_agent_v1_endpoints.py -k "client_install or setup_cm_queue"`

Expected: PASS.

- [ ] **Step 5: Commit the controller contract**

```bash
git -C ../ProxmoxVEAutopilot add autopilot-proxmox/web/setup_cm_endpoints.py \
  autopilot-proxmox/tests/test_agent_v1_endpoints.py
git -C ../ProxmoxVEAutopilot commit -m "feat: queue typed MECM client install"
```

## Task 5: Verify, deploy, and prove the live client path

**Files:**

- Modify only if tests require it: `docs/RUNBOOK.md`
- Evidence only: `C:\ProgramData\SetupCm\artifacts\` on CM01 and the Agent
  work root on `RING0IVY24-01`.

**Interfaces:**

- Consumes: tested commits from Tasks 1-4 and signed Agent MSI release
  `2026.8.3`.
- Produces: an updated client Agent heartbeat, a completed typed work item,
  client-side evidence, and a server-side discovered client record.

- [ ] **Step 1: Run repository quality gates before deployment**

Run:

```bash
pwsh -NoProfile -Command "Invoke-Pester ./tests/Unit -Output Detailed"
dotnet run --project ../ProxmoxVEAutopilot/autopilot-agent/tests/AutopilotAgent.ContractTests/AutopilotAgent.ContractTests.csproj
pytest -q ../ProxmoxVEAutopilot/autopilot-proxmox/tests/test_agent_v1_endpoints.py -k "client_install or setup_cm_queue"
```

Expected: all selected Pester, contract, and pytest tests pass.

- [ ] **Step 2: Request and apply CodeRabbit review findings safely**

Run CodeRabbit against the committed diffs. For each finding, verify it
against the typed request and secret-handling contracts before changing code;
rerun the affected test after every accepted correction.

- [ ] **Step 3: Build, sign, and publish Agent version `2026.8.3`**

Use the existing build-host work path and
`autopilot-agent/scripts/Build-AutopilotAgent.ps1 -Version 2026.8.3`.
Verify Authenticode signature and SHA-256 before publishing through the
existing artifact publication flow. Do not print the signing identity,
certificate material, or update token.

- [ ] **Step 4: Verify the target Agent self-update before queueing work**

Wait for `agent-ring0ivy24-01` heartbeat telemetry to report version
`2026.8.3` and capability `setup_cm_client_install`. If the heartbeat does
not update, use the existing per-agent update/restart workflow; do not use
WinRM or an arbitrary remote script.

- [ ] **Step 5: Queue and verify the client install**

Compute the archive hash immediately before queueing and use that exact value
in the typed endpoint request:

```powershell
$archive = '\\LABZ1-DC02\SetupCm\Modules\setup-cm.zip'
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
```

Send `site_code=LAB`,
`management_point_fqdn=LABZ1-CM01.test.gell.one`,
`evidence_root=C:\ProgramData\SetupCm\artifacts`, `module_archive_path=$archive`,
and `module_archive_sha256=$archiveHash` to the controller endpoint for
`agent-ring0ivy24-01`. Refuse to queue if the value differs from the hash
recorded for the deployment archive.

Verify the completed work has no error; require `CcmExec` running, site `LAB`,
the explicit MP, sanitized local logs, a CM01 discovery record for
`RING0IVY24-01`, and a final server Health-stage artifact with every check
true.

- [ ] **Step 6: Commit operator documentation, if changed**

```bash
git add docs/RUNBOOK.md
git commit -m "docs: add Agent MECM client verification runbook"
```

Skip this commit only when the existing runbook already documents every live
command and evidence location used above.
