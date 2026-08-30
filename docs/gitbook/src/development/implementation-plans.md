# Implementation Plans

Implementation plans are step-by-step, checkbox-tracked task lists used by agentic workers to implement features. They live in `docs/superpowers/plans/`.

## Available plans

| Plan | Date | Status | Tasks |
| --- | --- | --- | --- |
| [2026-07-30 Single-Box SCCM Core](../development/implementation-plans.md#2026-07-30-single-box-sccm-core) | 2026-07-30 | Complete | 8 tasks |
| [2026-08-01 Agent MECM Client Install](../development/implementation-plans.md#2026-08-01-agent-mecm-client-install) | 2026-08-01 | Complete; live Task 5 accepted | 5 tasks |
| [2026-08-01 MECM VC++ Redist Dependency](../development/implementation-plans.md#2026-08-01-mecm-vc-redist-dependency) | 2026-08-01 | Complete; live x64/x86 baseline accepted | 3 tasks |
| [2026-08-30 Hands-Off Rerun and v1 Release](../development/implementation-plans.md#2026-08-30-hands-off-rerun-and-v1-release) | 2026-08-30 | Tasks 1–7 complete; Task 8 review in progress | 10 tasks |

---

## 2026-07-30 Single-Box SCCM Core

**Goal:** Build a PowerShell 7+ project that acquires approved installation sources and deploys a verified single-box MECM primary site through reusable, testable stages.

**Tasks:**
1. Scaffold the PowerShell 7 module and Pester 6 test harness.
2. Define and validate the non-secret YAML configuration contract.
3. Implement verified acquisition from vendor sources and private installer vaults.
4. Build the resumable stage engine and Autopilot Agent entry script.
5. Implement Windows prerequisites and the single-box SQL Server stage.
6. Implement MECM primary-site and core-role stages.
7. Add live health validation, client proof, and CMTrace Open fixture curation.
8. Document operator flows and complete the quality gate.

See `docs/superpowers/plans/2026-07-30-single-box-sccm-core.md` for the full plan with checkboxes.

## 2026-08-01 Agent MECM Client Install

**Goal:** Install and verify the Configuration Manager client on `RING0IVY24-01` through a signed, typed Autopilot Agent work item.

**Tasks:**
1. Setup-CM Client stage — **complete**.
2. Server-side registration health gate — **complete**.
3. Typed Autopilot Agent client work — **complete upstream**.
4. Controller queue endpoint — **complete upstream**.
5. Verify, deploy, and prove the live client path — **complete and accepted**.

See `docs/superpowers/plans/2026-08-01-agent-mecm-client-install.md` for the full plan with checkboxes.

Accepted evidence is in
`docs/PHASE0-2026-08-29-LAB-INVENTORY.md`. The signed Agent completed the typed
work on `RING0IVY24-01`; provider and SQL registration plus a fresh Health run
agreed.

## 2026-08-01 MECM VC++ Redist Dependency

**Goal:** Install and verify Microsoft VC++ v14 x64 and x86 runtimes before MECM downloads prerequisites or runs setup.

**Tasks:**
1. Pin runtime detection with Pester — **complete**.
2. Pin verified installation and stage order — **complete**.
3. Make the source contract reusable and validate the reference lab privately — **complete**.

See `docs/superpowers/plans/2026-08-01-mecm-vc-redist-dependency.md` for the full plan with checkboxes.

## 2026-08-30 Hands-Off Rerun and v1 Release

**Goal:** Replace hardcoded compliance with real probes, automate bounded
marker acceptance, prove two consecutive runs, and publish v1.

**Tasks:**
1. Reconcile current project status and historical handoffs — **complete**.
2. Pin evidence and compliance contracts — **complete**.
3. Make Acquire read-only before apply — **complete**.
4. Implement SQL desired-state reconciliation — **complete**.
5. Implement MECM and read-only Health probes — **complete**.
6. Productize marker acceptance — **complete**.
7. Document and package the v1 workflow — **complete**.
8. Complete branch CI and review — **in progress**.
9. Run Windows/provider integration and two live runs — **integration preflight complete; live runs pending**.
10. Record acceptance, merge, tag, release, publish docs, and clean up safely — **pending**.

See `docs/superpowers/plans/2026-08-30-hands-off-rerun-v1.md` for the complete
test-first execution plan.
