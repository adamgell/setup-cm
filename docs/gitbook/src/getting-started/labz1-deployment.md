# LabZ1 Deployment Target

This page records the current reference-lab inventory and provisioning order for LabZ1.

## New machines

- `LABZ1-CM01.test.gell.one`: Windows Server 2022, single-box SQL Server and MECM primary site.
- `LABZ1-CMCLIENT01.test.gell.one`: newly provisioned Windows client used for MECM client, boundary, policy, and log validation.

## Existing machines

The ten existing domain-joined Intune devices remain unchanged. They are available for later co-management testing only after a deliberate assignment decision.

## Provisioning order

1. Use ProxmoxVEAutopilot OSDeploy Server with the `base` role to create `LABZ1-CM01` and verify `base_ready` plus `domain_joined=true`.
2. Stage the `setup-cm` source bundle and a non-template `lab.local.yaml` on that server.
3. Put verified SQL Server, MECM current-branch, and prerequisite media in the private vault; run `Test-SetupCmPreflight`.
4. Provision `LABZ1-CMCLIENT01`, domain join it, and run `Invoke-SetupCm` against the server.
