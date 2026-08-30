# Handoff — Agent MECM client install

> [!IMPORTANT]
> **Superseded on 2026-08-30.** This file is preserved as the historical
> 2026-08-02 handoff and must not be used as current operating instructions.
> Typed client-install Task 5 is complete: the signed Agent ran the typed
> `setup_cm_client_install` work for `RING0IVY24-01`, and ConfigMgr provider,
> SQL inventory, client evidence, and a fresh Health run all agreed.
>
> Current accepted evidence:
>
> - [Phase 0 LabZ1 inventory and final acceptance](PHASE0-2026-08-29-LAB-INVENTORY.md)
> - [Phase 1 required marker application acceptance](PHASE1-2026-08-29-MARKER-DEPLOYMENT.md)
>
> The accepted client is `RING0IVY24-01.test.gell.one`;
> `LABZ1-CMCLIENT01` is obsolete for current acceptance. Everything below this
> notice is retained as a historical snapshot, including stale branch, version,
> status, and next-step statements.

## Historical snapshot

**Date:** 2026-08-02
**Branch:** `codex/mecm-vc-redist`
**Worktree:** `.worktrees/codex-mecm-vc-redist` (under the repository root)

This document lives on `main`. The work it describes does not — everything below
is in the worktree above, which is where you should `cd` before running any
command in this document unless it says otherwise.

The plan and design are **not on `main`**; they were added by this branch and are
readable only from the worktree:

- Plan: `.worktrees/codex-mecm-vc-redist/docs/superpowers/plans/2026-08-01-agent-mecm-client-install.md`
- Design: `.worktrees/codex-mecm-vc-redist/docs/superpowers/specs/2026-08-01-agent-mecm-client-install-design.md`

Or from the repository root, without switching branches:

```bash
git show \
  codex/mecm-vc-redist:docs/superpowers/plans/2026-08-01-agent-mecm-client-install.md
```

The sibling repo referenced throughout is `../ProxmoxVEAutopilot`.

## State

Tasks 1–4 of the plan are complete. Task 5 (deploy and prove the live client
path) has not been started and needs revision before it can be followed.

| Task | Where | Status |
| --- | --- | --- |
| 1. Setup-CM Client stage | `codex/mecm-vc-redist` | Done, committed |
| 2. Server-side registration health gate | `codex/mecm-vc-redist` | Done, committed |
| 3. Typed Autopilot Agent client work | ProxmoxVEAutopilot `origin/main` | Done upstream |
| 4. Controller queue endpoint | ProxmoxVEAutopilot `origin/main` | Done upstream |
| 5. Verify, deploy, prove live path | — | Not started; see *Task 5 needs revision* |

The plan's own checkboxes are all still unticked and do not reflect this. Treat
this document as the authoritative status, not the checkboxes.

## Repository state

### setup-cm

`codex/mecm-vc-redist` is rebased onto `main`: 9 commits ahead, 0 behind, clean
tree.

```
cef1a57 feat: install MECM VC++ prerequisites
d81d5a3 fix: acquire every configured dependency
365ba4d fix: detect x86 MECM VC++ runtime
9160598 docs: design agent MECM client install
ad156c2 docs: plan agent MECM client install
bc4a90c feat: add MECM client installation stage
457df07 feat: verify MECM client server registration
aecd918 fix: preserve empty client evidence logs
dd071e5 fix: wait for MECM client location readiness
```

The rebase hit one conflict, in `docs/RUNBOOK.md`: PR #1 (`af3c6e4`) rewrote the
runbook while this branch had edited the older prose. Resolved by keeping main's
structure and folding the VC++ / ADK / Windows PE / ODBC 18 detail into its
"Prepare the lab" step 4. Nothing was dropped, but that paragraph is worth a
read since it was hand-merged rather than taken from either side:

```bash
git diff main:docs/RUNBOOK.md \
  codex/mecm-vc-redist:docs/RUNBOOK.md
```

Verified after rebase, from the worktree: `Invoke-Pester ./tests/Unit` →
**52 passed, 0 failed**.

Four other `codex/*` branches (`agent-bundle-entrypoint`, `iso-media-validation`,
`mecm-prereq-downloader`, `sql-default-account`) plus `review-base` are fully
merged into `main` — 0 commits ahead. Their worktrees under `.worktrees/` are
dead and can be removed.

### ProxmoxVEAutopilot

**Local checkout is 40 commits behind `origin/main` and needs a fast-forward.**
This is the single most important thing to fix before doing any further work in
that repo. `git -C ../ProxmoxVEAutopilot pull` — it is a clean fast-forward.

Local `main` is at `d2f0c56` / VERSION `2026.08.2`. Upstream is at VERSION
`2026.08.16`.

## Tasks 3 and 4 were already implemented upstream

Both tasks exist on `origin/main` of ProxmoxVEAutopilot. Relevant commits:

```
20e66ed feat: add typed MECM client Agent work          <- Task 3
ca3742e feat: queue MECM client installation work       <- Task 4
700709b fix: restrict MECM client work to LAB
ef2476e feat: diagnose setup-cm source access through agent
50c9ac2 feat: remediate setup-cm client source access
643d2e9 feat: remediate LABZ1 content location
4392c7d fix: use supported CMSite drive parameters
```

During this session Task 3 was reimplemented from scratch against the stale
local checkout (contract tests written, confirmed red, implemented, confirmed
green) before the duplication was discovered. **That work was reverted** —
`SetupCmWorkService.cs` and `ContractTests/Program.cs` were restored with
`git checkout --` and nothing was committed. ProxmoxVEAutopilot's tree is clean.

Root cause of the wasted effort: the check for existing work grepped the local
working tree, which was 40 commits stale, rather than `origin/main`. **When
resuming, verify against the remote.**

### Upstream deviates from the plan, and is stricter

Upstream's implementation is not what the plan specifies. It is tighter, and it
is already released — prefer it, but know the difference:

| Aspect | Plan specifies | Upstream implements |
| --- | --- | --- |
| Validation entry point | Separate `ValidateClientRequest` | Branch inside `ValidateRequest` on kind |
| Site code | Any `^[A-Z0-9]{3}$` | Must equal `LAB` exactly |
| Management point | Any host under `.test.gell.one` | Must equal `LABZ1-CM01.test.gell.one` exactly |
| Request type | Separate `SetupCmClientWorkRequest` record | Nullable `SiteCode` / `ManagementPointFqdn` on `SetupCmWorkRequest` |
| Module validation | Separate client validator | `ValidateExtractedModule(sourceRoot, entryScript)` with a default arg |

Upstream hardcodes the single lab target instead of validating a pattern. That
is safer for this lab. No action needed unless a second site is ever added, at
which point `700709b`'s constraints are the thing to relax.

Note the client-side manifest contract in `src/SetupCm/Private/Client.ps1`
(`Assert-SetupCmClientManifest`) is *looser* than upstream's agent-side check —
it accepts any `^[A-Z0-9]{3}$` site code and any `.test.gell.one` suffix. The
agent is the narrower gate. That asymmetry is intentional-looking but was never
stated in the design; worth confirming.

## Task 5 needs revision before execution

Do not follow Task 5 as written. Two of its steps are stale:

- **Step 3** says build, sign, and publish Agent `2026.8.3`. Upstream already
  shipped `2026.08.16`. The client work kind is in that release. There is
  probably nothing to build — confirm the released MSI contains
  `setup_cm_client_install` and skip the build, or re-target the step to
  whatever the current version is.
- **Step 4** says wait for `agent-ring0ivy24-01` to report version `2026.8.3`.
  Re-target to the actual deployed version.

Steps 1, 2, 5, and 6 are still valid as written. Step 1's quality gates:

```bash
# in .worktrees/codex-mecm-vc-redist
pwsh -NoProfile -Command "Invoke-Pester ./tests/Unit -Output Detailed"
# in ProxmoxVEAutopilot, after fast-forwarding
dotnet run --project autopilot-agent/tests/AutopilotAgent.ContractTests/AutopilotAgent.ContractTests.csproj
pytest -q autopilot-proxmox/tests/test_agent_v1_endpoints.py -k "client_install or setup_cm_queue"
```

Step 5 remains the live proof: compute the archive SHA-256 immediately before
queueing, send the typed request for `agent-ring0ivy24-01`, then require
`CcmExec` running, site `LAB`, the explicit MP, sanitized local logs, a CM01
discovery record for `RING0IVY24-01`, and a Health-stage artifact with every
check true.

**Step 5 is outward-facing and hard to reverse** — it signs artifacts and queues
real work against a live host. Get explicit operator sign-off before running it.

## Known unrelated failure

`dotnet build autopilot-agent` fails with:

```
wix.targets(584,5): error MSB6006: "wix.exe" exited with code 1
  [autopilot-agent/installer/AutopilotAgent.Installer.wixproj]
```

This is pre-existing and environmental — WiX cannot build MSIs on macOS.
Confirmed by stashing all changes and reproducing on a clean tree. It does not
affect the library or the contract tests, which build and pass. Building the
signed MSI (Task 5 step 3) requires a Windows build host.

## Suggested next steps

1. `git -C ../ProxmoxVEAutopilot pull` to fast-forward the 40 commits.
2. Tick plan checkboxes for Tasks 1–4 and record the upstream deviation table
   above as an accepted design change.
3. Rewrite Task 5 steps 3–4 against the real current Agent version.
4. Open a PR for `codex/mecm-vc-redist` into `main` — it is rebased, green, and
   self-contained.
5. Remove the five stale worktrees and their merged branches.
6. Confirm the intentional looseness of the PowerShell-side manifest validation
   relative to the agent-side gate.
