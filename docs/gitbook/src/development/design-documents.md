# Design Documents

Design documents capture the architectural decisions and constraints before implementation begins. They live in `docs/superpowers/specs/`.

## Available designs

| Document | Date | Topic |
| --- | --- | --- |
| [2026-07-30 SCCM Lab Automation Design](../development/design-documents.md#2026-07-30-sccm-lab-automation-design) | 2026-07-30 | Original single-box lab automation design |
| [2026-08-01 Agent MECM Client Install Design](../development/design-documents.md#2026-08-01-agent-mecm-client-install-design) | 2026-08-01 | Typed client work contract and manifest design |
| [2026-08-01 MECM VC++ Redist Dependency Design](../development/design-documents.md#2026-08-01-mecm-vc-redist-dependency-design) | 2026-08-01 | VC++ runtime detection and gating design |
| [2026-08-30 Hands-Off Rerun and v1 Release Design](../development/design-documents.md#2026-08-30-hands-off-rerun-and-v1-release-design) | 2026-08-30 | Idempotent core stages, marker automation, two-run acceptance, and v1 release |
| [2026-08-30 Authenticated Marker Client Evidence Channel Design](../development/design-documents.md#2026-08-30-authenticated-marker-client-evidence-channel-design) | 2026-08-30 | Fail-closed client proof without inbound firewall changes |

---

## 2026-07-30 SCCM Lab Automation Design

**Goal:** Build a PowerShell 7+ project that acquires approved installation sources and deploys a verified single-box MECM primary site through reusable, testable stages.

**Key decisions:**
- YAML configuration as the single source of truth.
- Stage engine with `Test` / `Apply` / `Verify` for idempotency.
- Evidence directory per run for diagnosability.
- Media and secrets external to Git.
- Lab-first with explicit production-target guardrail.

See `docs/superpowers/specs/2026-07-30-sccm-lab-automation-design.md` in the repository for the full text.

## 2026-08-01 Agent MECM Client Install Design

**Goal:** Install and verify the Configuration Manager client on a target through a signed, typed Autopilot Agent work item.

**Key decisions:**
- Constrained client-install work kind with typed fields.
- SHA-256-pinned module archive validation.
- Local non-secret JSON manifest on the target.
- Server-side discovery verification after client evidence submission.

See `docs/superpowers/specs/2026-08-01-agent-mecm-client-install-design.md` in the repository for the full text.

## 2026-08-01 MECM VC++ Redist Dependency Design

**Goal:** Install and verify Microsoft VC++ v14 x64 and x86 runtimes before MECM downloads prerequisites or runs setup.

**Key decisions:**
- Per-architecture registry version checks.
- Generic verified installer runner.
- Gate `Setupdl.exe` until both architectures meet version 14.34.

See `docs/superpowers/specs/2026-08-01-mecm-vc-redist-dependency-design.md` in the repository for the full text.

## 2026-08-30 Hands-Off Rerun and v1 Release Design

**Goal:** Make the accepted LabZ1 deployment rerunnable without installer or
Configuration Manager churn, then publish an exact evidence-backed v1 release.

**Key decisions:**
- Read-only component probes before every Apply.
- Minimal owned-state reconciliation and fail-closed identity conflicts.
- A bounded, idempotent one-device marker stage.
- Sanitized evidence tied to an exact commit and two consecutive live runs.

See `docs/superpowers/specs/2026-08-30-hands-off-rerun-v1-design.md` in the
repository for the full text.

## 2026-08-30 Authenticated Marker Client Evidence Channel Design

**Goal:** Prove the exact marker bytes from `RING0IVY24-01` without opening
inbound client firewall rules or trusting a ConfigMgr server projection as
direct client evidence.

**Key decisions:**
- One setup-cm-owned hidden share grants bounded write access only to the exact
  client computer account.
- The VBScript detector publishes fixed-schema evidence only after the exact
  marker hash succeeds; detection remains independent of transport success.
- CM01 validates strict content, owner SID, receipt freshness, and matching
  ConfigMgr state before accepting the client proof.
- Only the exact known predecessor detector permits a one-time policy update;
  the immediate second run performs no mutation or evaluation request.

See
`docs/superpowers/specs/2026-08-30-marker-client-evidence-channel-design.md` in
the repository for the full text.
