# Future projects outside setup-cm v1

Every item below is intentionally outside the v1 release. None may be enabled
as a shortcut during rerun acceptance. Each requires its own design, explicit
target boundary, rollback plan, test suite, and independently verified live
acceptance before it can change the supported product scope.

| Future project | Separate design boundary | Minimum acceptance boundary |
| --- | --- | --- |
| Production deployment | Replace LabZ1-fixed assumptions with a reviewed production topology, identity, security, media, change, and support model. | Approved production change; least-privilege credentials; staged rollout; rollback; security and recovery evidence. |
| Co-management | Define tenant authority, workloads, enrollment, certificates, and failure recovery without coupling them to MECM bootstrap. | One explicitly approved pilot collection; no unexpected workload movement; client and tenant evidence agree. |
| Patch My PC | Define publisher service ownership, certificate lifecycle, catalog scope, update rings, and rollback. | Signed pilot update through one bounded collection with content, install, and rollback evidence. |
| Reporting expansion | Design reporting services, data access, retention, privacy, and availability independently of site installation. | Read-only least-privilege data path, bounded retention, report correctness, and no setup-cm regression. |
| Distributed MECM topology | Design additional providers, MPs, DPs, site systems, boundaries, content flow, and failure domains. | Exact role and boundary inventory, content validation at every DP, failover/recovery proof, and no broad accidental scope. |
| Alternate hypervisors | Define provisioning, isolation, source staging, remote execution, and lifecycle evidence for Hyper-V or VMware independently of the Proxmox reference path. | Reproducible isolated topology, exact host/guest inventory, non-visual execution, two-run setup-cm proof, and recoverable lifecycle operations. |
| Additional clients | Define enrollment, collections, policy, and acceptance for each new client class. | Every device has an approved identity and dedicated test boundary; existing one-device marker scope remains unchanged. |
| Broad device collections | Establish ownership, query review, incremental/full evaluation, limiting collections, and deployment safeguards. | Independent peer review, dry-run membership evidence, blast-radius approval, and rollback before any required deployment. |
| Tenant integrations | Define Entra, Intune, Graph, connector, credential, and data-flow boundaries separately. | Least-privilege app identity, secret rotation, tenant-safe test scope, auditable consent, and explicit disconnect path. |
| Client-wide security-policy changes | Treat execution policy, certificate trust, firewall, authentication, and endpoint-security changes as security projects. | Security-owner approval, exact policy diff, bounded pilot, negative tests, rollback, and no weakening to make marker detection pass. |
| VM rebuild or snapshot rollback | Keep VM lifecycle in the provisioning layer rather than using it as setup-cm recovery. | Separate authorization, preserved evidence, validated backup/snapshot identity, restore test, and post-restore controller/Agent reconciliation. |
| Historical-object deletion | Inventory lineage and dependencies before removing old applications, collections, assignments, packages, or content. | Proven zero active dependency, exported inventory, explicit deletion list, recoverable backup where supported, and post-delete provider verification. |

The v1 marker remains required only on `RING0IVY24-01`. A future project must
not reuse its application, collection, assignment, or evidence as a generic
deployment vehicle.
