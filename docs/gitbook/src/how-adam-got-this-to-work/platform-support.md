# Platform Support Roadmap

`setup-cm` was built and proven on Proxmox VE with ProxmoxVEAutopilot. The architecture is deliberately hypervisor-agnostic. This page outlines the planned platform support and what each platform needs to provide.

## Current: Proxmox VE + ProxmoxVEAutopilot

| Capability | Status |
| --- | --- |
| VM provisioning | ✅ ProxmoxVEAutopilot OSDeploy Server |
| OS deployment (Windows Server / Client) | ✅ `base` role with unattended answer files |
| Domain joining | ✅ Automated via ProxmoxVEAutopilot |
| `setup-cm` execution (Agent) | ✅ Autopilot Agent typed work items |
| `setup-cm` execution (local terminal) | ✅ PowerShell 7 on the VM |

This is the reference implementation. All design decisions were validated here first.

## Planned: Hyper-V

Hyper-V is the most natural next platform. The Windows Server host already runs Hyper-V for nested virtualization scenarios, and the management tooling is mature.

| Capability | What's needed |
| --- | --- |
| VM provisioning | PowerShell Direct or Hyper-V VM creation scripts |
| OS deployment | Existing WDS/MDT, or custom unattend.xml injection |
| Domain joining | Unattend.xml or post-deployment script |
| `setup-cm` execution (Agent) | Autopilot Agent already runs on any Windows host; controller endpoint is platform-agnostic |
| `setup-cm` execution (local terminal) | Native — RDP or console into the VM |

The Autopilot Agent does not depend on Proxmox VE. It is a Windows service that polls a FastAPI controller. Running the controller on a Hyper-V host or a separate management VM is straightforward.

## Planned: VMware Workstation

VMware Workstation is common for individual consultants and small labs. It lacks the API surface of vSphere but supports local automation through VMware PowerCLI and the vmrun CLI.

| Capability | What's needed |
| --- | --- |
| VM provisioning | PowerCLI `New-VM` or vmrun with template VMs |
| OS deployment | VMware Tools + unattended installation, or template clones |
| Domain joining | Unattend.xml or post-deployment script |
| `setup-cm` execution (Agent) | Same as Hyper-V — Agent is platform-agnostic |
| `setup-cm` execution (local terminal) | Native — VMware console or RDP |

For VMware Workstation, the local terminal model may be more practical initially, since Workstation is typically used interactively. The Agent model works if the controller is reachable from the Workstation VMs.

## What stays the same across platforms

- The `setup-cm` PowerShell module and stage engine
- The YAML configuration contract
- The evidence format and `stage-<name>.json` results
- The Autopilot Agent work kinds and validation rules
- The requirement for isolated-lab targets unless explicitly overridden

## What changes per platform

- The provisioning layer that creates VMs and installs Windows
- The mechanism for staging the `setup-cm` source bundle and configuration onto the target
- The network isolation approach (Proxmox VLANs, Hyper-V virtual switches, VMware host-only networks)

## Contributing a new platform

To add support for a new hypervisor or provisioning system:

1. Ensure the platform can create an isolated, domain-joined Windows Server and a separate test client
2. Stage the `setup-cm` source bundle and a non-template `lab.local.yaml` on the server
3. Run `Test-SetupCmPreflight` to validate the configuration
4. Choose your execution model: local terminal or Autopilot Agent
5. Run the stages and preserve the evidence

The `setup-cm` module itself does not need modification. The integration point is the provisioning layer and the staging mechanism.
