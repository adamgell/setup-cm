# Implementation Plans

Implementation plans are step-by-step, checkbox-tracked task lists used by agentic workers to implement features. They live in `docs/superpowers/plans/`.

## Available plans

| Plan | Date | Status | Tasks |
| --- | --- | --- | --- |
| [2026-07-30 Single-Box SCCM Core](../development/implementation-plans.md#2026-07-30-single-box-sccm-core) | 2026-07-30 | Complete | 8 tasks |
| [2026-08-01 Agent MECM Client Install](../development/implementation-plans.md#2026-08-01-agent-mecm-client-install) | 2026-08-01 | Tasks 1–4 complete; Task 5 pending | 5 tasks |
| [2026-08-01 MECM VC++ Redist Dependency](../development/implementation-plans.md#2026-08-01-mecm-vc-redist-dependency) | 2026-08-01 | Tasks 1–2 complete; Task 3 in progress | 3 tasks |

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
5. Verify, deploy, and prove the live client path — **not started; needs revision**.

See `docs/superpowers/plans/2026-08-01-agent-mecm-client-install.md` for the full plan with checkboxes.

## 2026-08-01 MECM VC++ Redist Dependency

**Goal:** Install and verify Microsoft VC++ v14 x64 and x86 runtimes before MECM downloads prerequisites or runs setup.

**Tasks:**
1. Pin runtime detection with Pester — **complete**.
2. Pin verified installation and stage order — **complete**.
3. Make the source contract reusable and validate LABZ1 privately — **in progress**.

See `docs/superpowers/plans/2026-08-01-mecm-vc-redist-dependency.md` for the full plan with checkboxes.
