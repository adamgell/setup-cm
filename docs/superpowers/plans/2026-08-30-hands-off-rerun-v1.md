# Hands-Off Rerun and v1 Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use
> `superpowers:executing-plans` and implement each behavioral task test-first.

**Goal:** Make the accepted LabZ1 setup-cm deployment genuinely rerunnable,
productize the one-device marker acceptance, prove two consecutive live runs,
and publish an exact v1 release.

**Architecture:** Preserve the existing Test/Apply/Verify stage engine while
replacing hardcoded compliance with structured read-only probes. Repair only
owned missing components, fail closed on conflicts, and add a bounded Marker
stage. Tie sanitized evidence to one exact commit and independently compare
provider, SQL, client, controller, and Proxmox state.

**Tech stack:** PowerShell 7, Pester 6, Microsoft Configuration Manager current
branch provider/cmdlets, CIM/WMI, Microsoft ODBC Driver 18 through
`System.Data.Odbc`, mdBook, GitHub Actions and Releases.

## Global constraints

- Work only in the isolated branch/worktree created from accepted `main`.
- Preserve the primary checkout and its user-owned untracked handoff bytes.
- Use `LABZ1-CM01.test.gell.one`, site `LAB`, database `CM_LAB`, and only
  `RING0IVY24-01.test.gell.one` for live acceptance.
- Never use VNC as an acceptance dependency.
- Never commit private configuration, source URLs, credentials, media, raw
  policies, raw log bodies, or generated unattended files.
- Run focused red/green tests for every behavior, then the complete suite.
- Commit coherent milestones and keep one PR for the v1 work.

## Task 1: Reconcile current project status

**Files:**

- Modify: `README.md`
- Modify: `docs/LABZ1_DEPLOYMENT.md`
- Add: `docs/HANDOFF-2026-08-02-agent-mecm-client-install.md`
- Modify: `docs/PHASE0-2026-08-29-LAB-INVENTORY.md`
- Modify: `docs/PHASE1-2026-08-29-MARKER-DEPLOYMENT.md`
- Modify: `docs/superpowers/plans/2026-08-01-agent-mecm-client-install.md`
- Modify: `docs/gitbook/src/development/{design-documents,implementation-plans,handoffs}.md`
- Modify: relevant mdBook operations and navigation pages

- [x] Preserve the historical handoff and add a prominent superseded/current
      resolution notice.
- [x] Mark typed client-install Task 5 complete with Phase 0 evidence.
- [x] Replace current acceptance references to `LABZ1-CMCLIENT01` with
      `RING0IVY24-01` while retaining clearly labelled history.
- [x] State the accepted restart point, Phase 1 marker status, remaining v1
      work, and optional-integration non-goals consistently.
- [x] Check every local Markdown link and build mdBook.
- [x] Commit: `docs: reconcile accepted LabZ1 status`.

## Task 2: Pin evidence and compliance contracts

**Files:**

- Modify: `src/SetupCm/Private/Evidence.ps1`
- Modify: `src/SetupCm/Private/StageEngine.ps1`
- Modify: `src/SetupCm/Private/Configuration.ps1`
- Modify: `config/lab.example.yaml`
- Test: `tests/Unit/{Evidence,StageEngine,Configuration}.Tests.ps1`

- [x] Write failing tests for recursive redaction, omitted private source
      locations, source-commit validation, conflict handling, and verification
      after a successful Apply.
- [x] Add structured component evidence and exact source-commit metadata while
      preserving the public stage result schema.
- [x] Require non-template source `sizeBytes`, `version`, and `architecture`;
      require the fixed LabZ1 boundary only when marker acceptance is enabled.
- [x] Run focused suites and the full unit suite.
- [x] Commit: `feat: pin v1 evidence and compliance contracts`.

## Task 3: Make Acquire read-only before apply

**Files:**

- Modify: `src/SetupCm/Private/Acquisition.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCmAcquire.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`
- Test: `tests/Unit/Acquisition.Tests.ps1`

- [x] Write failing tests proving a complete cache skips Apply, one invalid
      artifact reacquires only itself, byte length/hash/license are required,
      version/architecture metadata are pinned, and no source location reaches
      evidence.
- [x] Implement `Get-SetupCmArtifactState` and `Test-SetupCmAcquire` as read-only
      probes plus affected-artifact-only acquisition.
- [x] Prove a second Acquire run invokes no download/copy operation.
- [x] Run focused and full unit suites.
- [x] Commit: `feat: make artifact acquisition idempotent`.

## Task 4: Implement SQL desired-state reconciliation

**Files:**

- Modify: `src/SetupCm/Private/Sql.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`
- Test: `tests/Unit/Sql.Tests.ps1`

- [x] Write failing component tests for Windows features, instance/service and
      startup state, network/listener/firewall, SQL query reachability, owned
      service/sysadmin configuration, VC++ x64/x86, conditional `CM_LAB`
      reachability, and conflicting identity.
- [x] Write orchestration tests proving exact compliance skips Apply, partial
      drift repairs one component, an absent instance installs once, a conflict
      never installs, and Verify failure fails the stage.
- [x] Implement a read-only SQL state probe and minimal repair dispatcher.
- [x] Replace the deprecated `System.Data.SqlClient` path with the supported
      ODBC Driver 18 provider, make it a SQL bootstrap prerequisite, and retain
      positional bounded parameters plus strict TLS/integrated authentication.
- [x] Run focused and full unit suites, plus the live CM01 read-only provider
      probe.
- [x] Commit: `feat: reconcile SQL desired state`.

## Task 5: Implement MECM and read-only Health probes

**Files:**

- Modify: `src/SetupCm/Private/Mecm.ps1`
- Modify: `src/SetupCm/Private/Health.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`
- Test: `tests/Unit/{Mecm,Health}.Tests.ps1`
- Add: `tests/Integration/CoreStages.Windows.Tests.ps1`

- [x] Write failing tests for exact site/provider/database/role identity,
      services, prerequisites, content library, and accepted active client.
- [x] Prove an exact site never opens MECM media, downloads prerequisites, or
      starts setup; a missing prerequisite repairs only itself; a conflicting
      site fails closed.
- [x] Make Health Test and Verify perform only read-only checks and always emit
      a fresh artifact.
- [x] Add Windows integration probes that exercise the real registry/service
      boundaries without installation.
- [x] Run focused, Windows, and full unit suites: 143 local unit tests passed;
      the Windows integration suite passed 3/3 against `LABZ1-CM01` using the
      real SQL, MECM, and Health read-only probes with installer/setup calls
      guarded by mocks.
- [x] Commit: `feat: make MECM reruns read-only`.

## Task 6: Productize the marker acceptance

**Files:**

- Add: `src/SetupCm/Private/MarkerApplication.ps1`
- Add: `src/SetupCm/Public/Invoke-SetupCmMarkerAcceptance.ps1`
- Add: `scripts/Invoke-SetupCmMarkerAcceptance.ps1`
- Modify: `src/SetupCm/Public/Invoke-SetupCm.ps1`
- Modify: `src/SetupCm/SetupCm.{psd1,psm1}`
- Test: `tests/Unit/MarkerAcceptance.Tests.ps1`
- Add: `tests/Integration/MarkerAcceptance.Provider.Tests.ps1`

- [x] Write failing safety tests for every fixed identity, one-member/direct-rule
      gate, assignment scope, same-name conflicts, and payload/detector hashes.
- [x] Write failing idempotency tests proving exact objects are reused, no
      unchanged redistribution/deployment/membership occurs, and partial owned
      drift invokes only its reconciler.
- [x] Implement provider adapters, bounded reconciliation, supported client
      policy/evaluation, and structured client/server evidence.
- [x] Keep the reviewed VBScript detector and safe uninstall contract exact.
- [x] Run focused unit tests, provider integration tests on CM01, Windows
      detector tests, and the full suite: 165/165 local unit tests and 8/8
      combined CM01 provider/detector/core tests passed; the live exact-state
      provider test also proved that every mutation adapter remained unused.
- [x] Commit: `feat: automate marker acceptance`.

## Task 7: Document and package the v1 operator workflow

**Files:**

- Modify: `README.md`, `docs/{CONFIGURATION,RUNBOOK}.md`
- Modify: `docs/gitbook/src/**` for configuration, operations, commands,
  evidence, testing, recovery, and navigation
- Add: `docs/FUTURE-PROJECTS.md`
- Modify: `.github/workflows/test.yml` as needed for all portable suites

- [x] Document the exact full-run/restart command, stage no-op semantics,
      marker boundary, evidence schema, and private-config/source-commit inputs.
- [x] Record every optional integration as a separate future project.
- [x] Add a deterministic local-link checker if one is not already available.
- [x] Run all portable tests, link checks, mdBook, and diff/secret scans: 170/170
      unit tests passed, 43 Markdown files and 85 local links resolved, mdBook
      and actionlint passed, and parser/PSScriptAnalyzer reported zero errors.
- [x] Commit: `docs: define the v1 operator workflow`.

## Task 8: Review the implementation before live mutation

- [ ] Push the branch and open one PR against `main`.
- [ ] Require Pester CI and mdBook/local documentation gates to pass.
- [ ] Review the complete diff for targeting, evidence leakage, installer skip
      logic, object duplication, and unsupported repair paths.
- [ ] Reproduce each actionable reviewer finding, fix test-first, and rerun
      affected plus full suites.
- [ ] Fix the exact source revision for live acceptance.

## Task 9: Run Windows/provider integration and two live runs

The marker client-proof blocker is resolved by the test-first implementation
and live sequence in
[`2026-08-30-marker-client-evidence-channel.md`](2026-08-30-marker-client-evidence-channel.md).
Complete that plan before continuing the remaining Task 9 gates.

- [ ] Reconfirm Proxmox owner/running state, controller health and Agent
      identity, CM01/site/provider/database, client resource identity, and the
      one-device marker deployment before staging source.
- [ ] Stage a `git archive` of the exact branch commit on CM01; verify byte hash
      and update only the ignored private configuration metadata required by
      the new source contract.
- [ ] Run Windows-only detector/core-stage/provider integration tests.
- [ ] Run `Acquire,Sql,Mecm,Marker,Health` once. Permit only bounded missing-state
      repair; independently verify all resulting state and evidence.
- [ ] Snapshot installer logs/process evidence and ConfigMgr object identities.
- [ ] Run the identical command again from the identical commit.
- [ ] Instrument every mutation or side-effect adapter during the second run
      and require exactly zero calls for existing-object updates,
      acquisition/download/copy, SQL repair/bootstrap, MECM
      prerequisite/site/content mutation, and Marker
      application/deployment/membership repair. Preserve the skipped/already
      compliant stage checks as evidence rather than omitting them.
- [ ] Verify both bundles are sanitized, fresh, hash them, and remove temporary
      staging/query files.

## Task 10: Record acceptance, merge, and publish v1

**Files:**

- Add: `docs/V1-ACCEPTANCE-2026-08-30.md`
- Update: README, mdBook current status, plan checkboxes, and release notes

- [ ] Commit the sanitized two-run record with exact commit, evidence IDs and
      hashes, provider/client agreement, and safe restart command.
- [ ] Push, rerun final PR CI/review, and merge only when clean and approved.
- [ ] Verify local main, origin/main, PR head, and merge ancestry.
- [ ] Run release-critical tests and read-only live Health at the exact merge
      commit. For marker state, run the fail-on-mutation exact-state provider
      test `tests/Integration/MarkerAcceptance.Provider.Tests.ps1`; it reads the
      existing deployment and supplies mutation adapters that throw if called.
- [ ] Compare the tree IDs of the live-tested commit and the merge commit. If
      they differ, rerun the complete two-run live acceptance at the merge
      commit and treat that merge commit as the accepted live revision before
      tagging.
- [ ] Confirm `refs/tags/v1.0.0` does not exist locally or on `origin`, create
      the repository's first annotated tag `v1.0.0` at the accepted merge
      commit, and verify the dereferenced tag points to that exact commit.
- [ ] Push the tag and publish GitHub release notes with scope, topology, gates,
      limitations, boundary, and evidence hashes.
- [ ] Confirm Pages deployment succeeds and published docs match tagged source.
- [ ] Remove branches/worktrees only after reachability, cleanliness, untracked
      data, and active-reference checks all pass; otherwise document them.
