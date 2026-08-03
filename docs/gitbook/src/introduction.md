# Introduction

> **Work in Progress**
> This documentation is actively being developed alongside `setup-cm`. Content may be incomplete, outdated, or change without notice. Verify critical commands and procedures against the repository source.

`setup-cm` automates a repeatable, evidence-backed Microsoft Configuration Manager (MECM, formerly SCCM) primary-site deployment for an **isolated lab**.

It installs and validates a single Windows Server that hosts SQL Server, a MECM primary site, Management Point, and Distribution Point. The baseline also verifies that a dedicated test client can use the site.

> **Warning**
> This repository is for lab automation, not production MECM deployment. Do not use its default topology, example configuration, or unattended workflow against production infrastructure.

## What this documentation covers

This book is the complete operator and developer reference for `setup-cm`:

- **Getting Started** — what the tool does, what you need, and how to run your first deployment.
- **Configuration** — the YAML contract, field-by-field reference, and safety guardrails.
- **Operations** — the runbook, stage lifecycle, evidence interpretation, and recovery procedures.
- **Architecture** — why the tool is designed the way it is, and how the pieces fit together.
- **Reference** — command syntax, configuration schema, and evidence format details.
- **Development** — design documents, implementation plans, testing strategy, and handoff notes.

## Where to start

If you are new to `setup-cm`, read the [Overview & Quick Start](./getting-started/overview.md) first, then the [Prerequisites](./getting-started/prerequisites.md), then the [Configuration Reference](./configuration/reference.md). Once your configuration is validated, follow the [Operator Runbook](./operations/runbook.md).

If you are contributing or extending the tool, start with [Why setup-cm Exists](./architecture/why.md) and [Design Principles](./architecture/design-principles.md), then review the [Implementation Plans](./development/implementation-plans.md).
