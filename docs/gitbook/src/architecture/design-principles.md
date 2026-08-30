# Design Principles

`setup-cm` is built around a small set of non-negotiable design principles. Understanding them makes the codebase easier to navigate and extend.

## 1. Desired-state stages, not scripts

Each stage is a `Test` / `Apply` / `Verify` triplet. The stage engine only runs
`Apply` when `Test` reports `NotCompliant`, and only runs `Verify` after Apply
succeeds. That engine contract makes a stage idempotent only when its Test is a
real state probe. The accepted source has not yet met that standard for
Acquire and MECM; see [Current LabZ1 Status](../operations/current-status.md).

## 2. Evidence is a first-class output

Every run writes structured JSON to a unique directory under `evidenceRoot`. Evidence is not an afterthought or a log file; it is the primary artifact that tells you what happened, when, and why. Both success and failure produce evidence.

## 3. Configuration is explicit and validated

The YAML configuration is the single source of truth for a deployment. It is validated before any stage runs. Placeholder values are rejected when `template` is `false`. Safety guardrails (such as `isolatedLab` and `allowProductionTarget`) are enforced at validation time, not at runtime.

## 4. Media and secrets stay outside Git

The repository contains only metadata: URIs, SHA-256 checksums, versions, and license acknowledgements. Actual installers, product keys, credentials, certificates, and generated evidence never enter version control.

## 5. Lab-first, with explicit safety gates

The default topology is a single-box, isolated lab. The tool refuses to run against a non-isolated target unless the operator explicitly sets `allowProductionTarget: true`. This is a guardrail, not an endorsement of production use.

## 6. Provisioning is a separate concern

`setup-cm` does not create VMs, install Windows, or join domains. It assumes those prerequisites are met and focuses exclusively on Windows-side MECM configuration and validation. This boundary keeps the tool focused and reusable.

## 7. Testability at every layer

Every private function has a corresponding Pester 6 unit test. Mocks isolate Windows-specific APIs (registry, services, processes) so tests run on any platform. Integration tests validate the live lab only after unit tests pass.

## 8. Small, composable modules

Private functions live in `src/SetupCm/Private/` and do one thing. Public entry points live in `src/SetupCm/Public/` and orchestrate stages. Scripts in `scripts/` are thin wrappers for agent execution. This separation keeps the module testable and the entry points predictable.
