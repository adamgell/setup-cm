# v1 Hands-Off Rerun Acceptance

**Operator date:** 2026-08-30

**Status:** Accepted — the exact release-candidate implementation passed the
complete LabZ1 workflow twice without installation or ConfigMgr object change;
the first run refreshed only stale authenticated evidence and the immediate
second run was zero-action.

This record closes the live gate for the first `setup-cm` release. It records
only sanitized identities, hashes, test counts, and state results. It contains
no credentials, tokens, private URLs, generated configuration, raw policies,
or log bodies.

## Accepted scope

| Role | Accepted identity |
| --- | --- |
| MECM server, provider, MP, and DP | `LABZ1-CM01.test.gell.one` (VM 107) |
| Site and database | `LAB` / `CM_LAB` |
| Only accepted client | `RING0IVY24-01.test.gell.one` (VM 135) |
| Required application | `Setup-CM Phase 1 Marker` |
| Controller | `autopilot-docker` (CT 500) |

The marker remains a required deployment to one direct member only. No other
device or collection is an accepted v1 target. Production, additional clients,
distributed MECM, co-management, Patch My PC, reporting expansion, tenant
integrations, VM rebuilds, and client-wide security-policy changes remain
outside this release.

## Exact execution source

| Evidence | Accepted value |
| --- | --- |
| Pull request | [#5](https://github.com/adamgell/setup-cm/pull/5) |
| Branch | `codex/hands-off-rerun-v1` |
| Live-tested commit | `33535c6a0e47bb0bb0f838eb990b0e9e9cb2ac95` |
| Live-tested tree | `b0d1329b1fb7fa8479b0b0754cbe168f60fa702b` |
| Git archive size | 1,075,200 bytes |
| Git archive SHA-256 | `85c4efb0c36a3575227a078164e35a87e71f777e6bf913e560181779a7b65062` |
| Embedded archive commit | `33535c6a0e47bb0bb0f838eb990b0e9e9cb2ac95` |
| Extracted 96-file manifest SHA-256 | `5DCC6E72371F3797F2DF34E6CFAA978F70DBC46E8B80FC2B12D2C9B84354E8DD` |
| Read-only acquisition evidence SHA-256 | `10078B52E8002429CB6BAB35D5F4C6B2649A1606F0BE0F7E23CE11CE03A787C8` |
| Ordered pre-run boundary SHA-256 | `5149AFDC75348A4EE28A98F8EB242993BAA0FC62891B7750B1A7C1E06B378727` |

The archive was generated with `git archive`, transferred through a temporary
lab-only listener, checked by SHA-256 on both Windows targets, and checked on
CM01 with `git get-tar-commit-id` before extraction. The listener was stopped
after staging.

The acceptance-record commit is documentation-only relative to the live-tested
implementation. Before tagging, all non-documentation release paths must remain
identical to this commit. Any executable, configuration, workflow, or test-tree
difference requires renewed acceptance rather than a documentation exception.

## Quality gates

| Gate | Result |
| --- | --- |
| Portable Pester suite | 391 passed, 0 failed, 0 skipped |
| PowerShell parse | 45 files, 0 errors |
| PSScriptAnalyzer error severity | 0 findings |
| Markdown links | 47 files and 97 local links passed |
| mdBook and workflow lint | passed |
| Final focused CodeRabbit review | 0 findings |
| CM01 native Windows integration | 12 passed, 0 failed, 5 client-only skips |
| `RING0IVY24-01` native Windows integration | 10 passed, 0 failed, 0 skipped |
| ConfigMgr provider post-migration integration | 1 passed, 0 failed, no mutation |
| PR Pester CI | passed at the final PR head before merge |
| PR mdBook build | passed at the final PR head before merge |
| PR CodeRabbit status | passed at the final PR head before merge |

The native evidence-channel tests include a real Windows proof that a newly
created file inherits target-computer Modify rights. This test caught and
closed the earlier directory-only inheritance defect before formal acceptance.

## Bounded repair lineage

The lab entered the final acceptance window with all installation and fixed
ConfigMgr object state valid. The authenticated receipt is deliberately fresh
for only 30 minutes, so the pre-run boundary reported exactly
`Client/ClientEvidencePending`; SQL, MECM, acquisition, marker objects, content,
distribution, targeting, and server compliance were already compliant.

The first run therefore permitted only `RequestClientPolicy` and
`WaitForConvergence`. It requested the supported paired client evaluation and
waited for a new target-owned receipt. No acquisition, installer, SQL/MECM
repair, application/content/distribution, collection, membership, assignment,
or detector mutation was permitted or observed.

An earlier candidate closed the stage-output contract defect. Final review then
found that the signed bootstrapper architecture exception was broader than its
known x86-PE/x64-product case and that Health used an empty repair path before
failing. Commit `33535c6a0e47bb0bb0f838eb990b0e9e9cb2ac95` narrows that
exception and makes Health a single check-only evaluation with named failed
checks. Both changes have failing-before and passing-after regression proof.

## Exact marker and target identity

| Object | Accepted identity |
| --- | --- |
| Application CI / revision | `16777532` / `5` |
| Deployment type CI / revision | `16777533` / `4` |
| Package | `LAB00008` |
| Collection | `LAB00016` |
| Sole member resource | `16777219` (`RING0IVY24-01`) |
| Assignment / policy revision | `16777217` / `5` |
| Marker length | 78 bytes |
| Marker SHA-256 | `3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254` |
| Authenticated receipt length | 254 bytes |
| Authenticated receipt SHA-256 | `B21E6A787FBA6004D28C69094941F44FC123A835554F24971C565BA1615F1AB7` |
| Receipt owner | `TEST\RING0IVY24-01$` |

Final inspection found exactly one item in the bounded evidence directory: the
accepted `marker-evidence.json`. The application, deployment type, package,
distribution, collection, direct membership, and assignment identities did
not change across either formal run.

## Formal run one

| Evidence | Accepted value |
| --- | --- |
| Run ID | `20260830-203712-76f13d67` |
| Summary SHA-256 | `15D7C91447D18CA4A63D7A1F56774C8889DE9A211E192F1BAE164FBE6FBE7085` |
| Artifact count | 11 |
| Health SHA-256 | `2BA005D6D36572C1F864694B0227635F938C8AD7A27FB0EC4E8C2D50B9404593` |
| Stage states | Acquire, SQL, MECM, Health: `Skipped`; Marker: `Succeeded` |
| Allowed actions | `RequestClientPolicy`, `WaitForConvergence` |
| Object or installer mutations | 0 |
| Installer processes | 0 |

All six Health values were true: SQL, MECM, Management Point, Distribution
Point, client reachability, and active non-obsolete client registration.

## Formal run two

| Evidence | Accepted value |
| --- | --- |
| Run ID | `20260830-204052-d3c589a6` |
| Summary SHA-256 | `2938B54FAE5ED15B0AC720873F41AA48E434C05F2BD12AD64329DD59A332E66A` |
| Artifact count | 11 |
| Health SHA-256 | `2BA005D6D36572C1F864694B0227635F938C8AD7A27FB0EC4E8C2D50B9404593` |
| Stage states | Acquire, SQL, MECM, Marker, Health: `Skipped` |
| Mutation actions | 0 |
| Installer processes | 0 |

The second run used the same command and exact source revision. Mutation mocks
would have failed the run if acquisition, SQL repair, MECM repair, marker
repair, content distribution, collection membership, deployment, policy, or
installer paths had been invoked.

## Independent before/after snapshots

| Snapshot | SHA-256 |
| --- | --- |
| Server baseline | `C606C8DC3CF3B5C39F9B4C21DF0AA17BBA68CE01F2826F3257C1CD7DAA54860C` |
| Server after run one | `A7AC8CA3A172ED5D9B13CA4AD320F61EB1EDB147D087A4B1826D12DA5F740AC7` |
| Server after run two | `B8B7A291384EE813340FEE9E21FF005956E8D1CE1073B941DCDA0DA38D337D40` |
| Client baseline | `4B0D5C1782377A8D3DE48CC2EA1F640191E718EEF0184A92CCD17FAC32DC6591` |
| Client after run one | `9E277628CDDF43EEF4B6A9450C40298753AD702C4FDABF21C7EEEC17491B360E` |
| Client after run two | `955D56BC279AA6E5B9EE8B61F4FAB2C314D4D6062BE2C283CA2E066DAE061317` |

Snapshot hashes differ because each file includes its observation time. The
comparison gate separately normalized and compared the owned values. Server
application, deployment-type, distribution, collection, rule, membership, and
assignment properties were identical. Client marker, Agent, firewall,
execution-policy, trust-store, scheduled-task, and scoped service hashes were
identical.

The formal snapshots hash all Windows service definitions except OS-managed
BITS and record BITS separately. The stable 296-service scoped SHA-256 was
`682863423E9B331756C8025FDE4592A4E140F9480AA9587483FF105C975BEDB0`;
BITS was `Manual`/`Stopped` at baseline and `Auto`/`Running` after the
bounded policy-refresh window and second run. No setup-cm-owned service value,
service definition in the scoped hash, or other client configuration changed.

## Independent infrastructure and controller proof

- Proxmox node `pve2` reported the two-node cluster quorate.
- VMs 107, 111, 115, and 135 plus CT 500 were all running.
- Controller `/healthz` returned `{"ok":true}`.
- Controller release `2026.08.48` reported source `8ba1c80`.
- Accepted Agents `agent-labz1-cm01` / VM 107 and
  `agent-ring0ivy24-01` / VM 135 checked in currently at version
  `2026.8.48.0` and were not revoked.
- A stale historical `osd-fullos` controller identity also names CM01. It is
  not the accepted Agent and was left untouched because historical-object
  deletion is explicitly outside v1.

## Evidence hygiene and cleanup

- Both accepted run directories parsed as JSON and produced zero sensitive keys,
  credentials, bearer values, private URLs, or raw policy patterns.
- A stalled direct SFTP attempt created only two exact zero-byte staging
  placeholders. The two transfer-only SFTP processes were stopped and those
  empty placeholders were removed before the proven temporary lab-only
  listener was used; no source had been extracted from them.
- The temporary listener was stopped immediately after both archive hashes
  matched. The two verified staging archives and two generated
  `testResults.xml` files were removed after acceptance; both extracted source
  roots then matched the exact 96-file manifest again.
- Earlier acceptance work removed two exact target-owned failed-attempt `.tmp`
  receipts, one rejected source-stager helper, three superseded client helpers,
  and hash-only BITS diagnostic state only after identity checks. All were
  temporary and regenerable. No user document, ConfigMgr object, source media,
  accepted evidence, or unrelated lab file was deleted.

## Safe restart

Routine validation should stay read-only. From the accepted source root on
CM01, run:

```powershell
$commit = '33535c6a0e47bb0bb0f838eb990b0e9e9cb2ac95'
pwsh "C:\ProgramData\SetupCm\source\$commit\scripts\Invoke-SetupCm.ps1" `
  -ConfigPath 'C:\ProgramData\SetupCm\config\lab.local.yaml' `
  -Mode Unattended -Stage Health -SourceCommit $commit
```

Use the complete five-stage command only from an exact reviewed source when a
full no-op confirmation or a proven owned-component repair is required. Do not
replay bootstrap installers merely for newer timestamps, broaden the marker
collection, weaken client policy, or delete historical objects as recovery.

Once published, the `v1.0.0` tag and GitHub release will be the authoritative
publication identity for this accepted implementation. The release notes must
retain this topology, evidence boundary, test counts, limitations, and safe
restart rule.
