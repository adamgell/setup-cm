# Why setup-cm exists

## The problem

Installing MECM in a lab is more than launching two installers. It combines licensed and version-sensitive media, SQL Server setup, Windows prerequisites, MECM prerequisite downloads, site configuration, and client validation. A successful console installation does not prove that the Management Point, Distribution Point, boundaries, or client registration work.

Ad-hoc scripts and one-time setup notes make those dependencies easy to lose. They also leave little useful information when a deployment fails halfway through.

## The approach

`setup-cm` treats a lab deployment as a sequence of small desired-state stages:

1. Test whether a stage is already compliant.
2. Apply only the work required for that stage.
3. Verify the resulting state and save a structured result.

This provides three practical benefits:

- **Repeatability:** the YAML configuration and explicitly ordered stages make the same lab intent reviewable and rerunnable.
- **Diagnosability:** every run gets its own evidence directory, including a result for each completed or failed stage.
- **Safe recovery:** an operator can correct the reported prerequisite and rerun only the affected stage rather than restart blindly.

## Why media is external

MECM, SQL Server, and related installers can be licensed, authenticated, customer-specific, large, or subject to vendor distribution rules. The repository therefore stores only source metadata, integrity values, versions, and an explicit license acknowledgement. Operators keep actual media in an approved vendor location, private installer vault, or local cache.

The same separation applies to product keys, credentials, certificates, and generated evidence that may contain environment-specific information.

## Why it is lab-focused

The default model is a disposable, isolated single-box primary site. It keeps the baseline affordable to operate and makes failures easier to reset and understand. The configuration requires an explicit safety decision when the target is not isolated.

Production MECM requires organization-specific architecture, capacity planning, service accounts, security review, backup and recovery design, operational ownership, and change control. Those decisions cannot be safely generalized by this repository.

## Why provisioning is separate

`setup-cm` is not a VM or operating-system provisioning tool. A provisioning layer creates the isolated network and virtual machines, installs Windows, and joins the domain. `setup-cm` begins once those prerequisites exist and owns the Windows-side MECM work.

Keeping that boundary clear allows the MECM workflow to be rerun without redefining VM lifecycle, while the provisioning system can remain independent of MECM implementation details.

## What comes next

The core health stage is the gate for optional capabilities such as co-management, Patch My PC, reporting, and diagnostic fixture collection. Those capabilities should remain separate modules so their failures do not obscure whether the baseline MECM site is healthy.
