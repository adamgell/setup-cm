# The ProxmoxVEAutopilot Journey

This section documents how Adam built and validated `setup-cm` in his own lab. It is not a generic tutorial — it is the specific path that worked, the constraints that shaped the design, and the lessons that inform the tool's future direction.

## The starting point

Adam needed a repeatable way to stand up a Microsoft Configuration Manager (MECM) lab for testing Intune co-management scenarios, client deployment behaviors, and troubleshooting workflows. Manual MECM installations were time-consuming and error-prone. Existing automation either assumed production infrastructure or lacked the evidence trail needed to diagnose failures in a disposable lab.

The lab already had:

- **Proxmox VE** as the hypervisor
- **ProxmoxVEAutopilot** — Adam's own automation layer for VM provisioning, OS deployment, and domain joining
- A private installer vault with licensed Microsoft media
- A need to tear down and rebuild the lab frequently

## Why ProxmoxVEAutopilot was the right foundation

ProxmoxVEAutopilot already solved the problems that `setup-cm` explicitly does not:

- Creating isolated networks and VMs
- Installing Windows Server and Windows client OS
- Joining machines to the lab domain
- Running typed, validated work items on Windows hosts

Rather than duplicate that capability, `setup-cm` was designed to plug into it. The boundary is clean: ProxmoxVEAutopilot owns the infrastructure lifecycle; `setup-cm` owns the MECM configuration and validation that happens after Windows is ready.

## The first working deployment

The first successful end-to-end run used this sequence:

1. **ProxmoxVEAutopilot OSDeploy Server** created a Windows Server 2022 VM with the `base` role
2. The server was verified as `base_ready` and `domain_joined=true`
3. A staged `setup-cm` source bundle and a non-template `lab.local.yaml` were placed on the server
4. Verified SQL Server, MECM current-branch, and prerequisite media were staged in the private vault
5. `Test-SetupCmPreflight` confirmed readiness
6. A separate Windows client VM was provisioned and domain-joined
7. `Invoke-SetupCm` ran the full `Acquire → Sql → Mecm → Health` sequence
8. The `Health` stage confirmed SQL, MP, DP, boundaries, and client registration

The evidence directory from that first `Health` success is the baseline proof that the design works.
This is historical bring-up order. The current release-candidate workflow adds
the bounded `Marker` stage and performs read-before-apply desired-state checks
for all five stages.

## What made it hard

Three problems consumed the most time:

**VC++ redistributable detection.** MECM setup fails cryptically when the x64 or x86 VC++ v14 runtime is missing or below 14.34. The registry keys are architecture-specific and the version strings are inconsistent. The fix required per-architecture registry probing and a hard gate before `Setupdl.exe` runs.

**Client installation trust.** Getting the MECM client onto a remote machine without WinRM or PSRemoting required a typed work contract in the Autopilot Agent, not a generic script. The client install work item validates the target FQDN, derives the only permitted `ccmsetup.exe` path, and captures sanitized evidence.

**Evidence that survives failure.** Early versions wrote logs but not structured state. When a stage failed halfway through, there was no machine-readable record of what had been verified. The stage engine now writes `stage-<name>.json` before returning or throwing, making resume decisions deterministic.

## Where this leads

The ProxmoxVEAutopilot path proved that typed, validated, evidence-producing automation works for MECM lab deployment. The next sections describe how the Autopilot Agent was built to execute that path, and how `setup-cm` will support both agent-driven and local-terminal execution going forward.
