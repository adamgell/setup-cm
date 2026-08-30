# Handoff Notes

Handoff documents record the state of multi-session work, especially when it spans branches or worktrees. They live in `docs/`.

## Available handoffs

| Document | Date | Branch | Status |
| --- | --- | --- | --- |
| [HANDOFF-2026-08-02-agent-mecm-client-install.md](../development/handoffs.md#handoff-2026-08-02-agent-mecm-client-install) | 2026-08-02 | `codex/mecm-vc-redist` | Superseded; Task 5 accepted 2026-08-30 |

---

## HANDOFF-2026-08-02-agent-mecm-client-install

**Branch:** `codex/mecm-vc-redist`
**Worktree:** `.worktrees/codex-mecm-vc-redist`

### Current resolution

This handoff is preserved historical context and must not be used as the
current restart procedure. Task 5 completed through the signed typed Agent path
on `RING0IVY24-01`; the Phase 0 record contains the accepted work item, client
evidence, provider/SQL registration, and fresh Health proof.

| Task | Where | Status |
| --- | --- | --- |
| 1. Setup-CM Client stage | `codex/mecm-vc-redist` | Done, committed |
| 2. Server-side registration health gate | `codex/mecm-vc-redist` | Done, committed |
| 3. Typed Autopilot Agent client work | ProxmoxVEAutopilot `origin/main` | Done upstream |
| 4. Controller queue endpoint | ProxmoxVEAutopilot `origin/main` | Done upstream |
| 5. Verify, deploy, prove live path | Accepted LabZ1 | Done; see Phase 0 evidence |

### Key commits on `codex/mecm-vc-redist`

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

See `docs/HANDOFF-2026-08-02-agent-mecm-client-install.md` in the repository for
the full preserved handoff and its prominent superseded notice. Use
`docs/PHASE0-2026-08-29-LAB-INVENTORY.md` for current accepted state.
