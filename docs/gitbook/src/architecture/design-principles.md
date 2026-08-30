# Design Principles

`setup-cm` is built around a small set of non-negotiable design principles. Understanding them makes the codebase easier to navigate and extend.

## 1. Desired-state stages, not scripts

Each stage is a `Test` / `Apply` / `Verify` triplet. The stage engine only runs
`Apply` when `Test` reports `NotCompliant`, and only runs `Verify` after Apply
succeeds. That engine contract makes a stage idempotent only when its Test is a
real state probe. Acquire, SQL, MECM, Marker, and Health now meet that standard;
the final live gate runs the same exact source twice to prove it. See
[Current LabZ1 Status](../operations/current-status.md).

## 2. Evidence is a first-class output

Every run writes structured JSON to a unique directory under `evidenceRoot`. Evidence is not an afterthought or a log file; it is the primary artifact that tells you what happened, when, and why. Both success and failure produce evidence.

## 3. Configuration is explicit and validated

The private YAML configuration declares operator-selectable deployment state.
The Marker feature adds a compiled fixed LabZ1 contract, and release-critical
evidence adds an exact source commit. Placeholder values are rejected when
`template` is `false`; target and safety guardrails are rechecked before any
provider action.

## 4. Media and secrets stay outside Git

The committed template contains only safe example metadata. Private source
locations, actual installers, product keys, credentials, certificates,
working configuration, and generated evidence never enter version control.

## 5. Lab-first, with explicit safety gates

The supported v1 topology is the single-box isolated LabZ1 environment. General
configuration validation has an explicit production acknowledgement, but the
Marker command and v1 acceptance remain fixed lab-only and do not support
production targeting.

## 6. Provisioning is a separate concern

`setup-cm` does not create VMs, install Windows, or join domains. It assumes those prerequisites are met and focuses exclusively on Windows-side MECM configuration and validation. This boundary keeps the tool focused and reusable.

## 7. Testability at every layer

Every private function has a corresponding Pester 6 unit test. Mocks isolate Windows-specific APIs (registry, services, processes) so tests run on any platform. Integration tests validate the live lab only after unit tests pass.

## 8. Small, composable modules

Private functions live in `src/SetupCm/Private/` and do one thing. Public entry points live in `src/SetupCm/Public/` and orchestrate stages. Scripts in `scripts/` are thin wrappers for agent execution. This separation keeps the module testable and the entry points predictable.
