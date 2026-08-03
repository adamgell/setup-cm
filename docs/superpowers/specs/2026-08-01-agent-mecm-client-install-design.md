# Agent-driven MECM Client Installation Design

## Purpose

Extend the verified LABZ1 single-box primary site with one safe, repeatable
client-management proof. The first target is the existing lab workstation
`RING0IVY24-01` in `test.gell.one`. Its Autopilot Agent, not WinRM, performs
the Windows-side install and reports non-secret evidence.

## Constraints

- The target is an isolated LABZ1 workstation. The flow rejects other domains.
- The existing target has no reachable WinRM listener; no side-channel remote
  execution is part of the design.
- The client is installed against the explicit initial site path:
  `LABZ1-CM01.test.gell.one`, site code `LAB`, HTTP port 80.
- No installer media, credential, product key, certificate private key, or
  generated credential is committed to Git or returned in work-item output.
- The existing `setup_cm_*` contract remains typed, hash-verified, and limited
  to approved Setup-CM roots.

## Chosen architecture

Add a dedicated `setup_cm_client_install` Agent work kind. It is distinct from
the server `Health` stage: installing a client is an action, while health only
evaluates an already configured topology.

The controller accepts a typed request with:

- `site_code`: exactly the configured three-character lab site code.
- `management_point_fqdn`: a `test.gell.one` host name.
- `module_archive_path` and SHA-256: an approved Setup-CM archive.
- `evidence_root`: an approved local Setup-CM path.

It does not accept arbitrary PowerShell, arbitrary UNC paths, product keys,
passwords, or a complete server configuration file. The Agent reconstructs a
minimal, non-secret client manifest beneath its own ProgramData work root,
copies the archive, verifies the SHA-256, and invokes the Setup-CM module's
new `Client` stage.

The Client stage obtains `ccmsetup.exe` only from the site-code-derived
client source share on the selected management point. It runs:

```text
ccmsetup.exe /mp:LABZ1-CM01.test.gell.one SMSSITECODE=LAB
```

The installer source and argument values are recorded only as sanitized
structured evidence; client logs remain local evidence and are not committed.

## Agent update path

`RING0IVY24-01` currently reports Autopilot Agent `0.1.2.0` and advertises no
Setup-CM capabilities. Before queueing the client work item, publish a signed
Agent release that includes the new work kind. The target consumes it through
the existing Agent self-update channel, validates the published artifact hash,
and reports the new version/capability through heartbeat telemetry. No client
work is queued until that capability is present.

## Idempotency and failures

`Test-SetupCmClientInstallation` is compliant only when the local client
service is running, the assigned site is `LAB`, and the active management
point matches the supplied FQDN. A compliant target produces a skipped result
with fresh verification evidence; it does not reinstall the client.

On an incomplete or failed install, the stage returns a concise error plus
sanitized tails from `ccmsetup.log` and `ClientIDManagerStartup.log`, preserves
the work directory, and leaves the Agent capable of retrying. It never removes
an existing client merely to retry. A failed Agent update prevents the client
work from being queued.

## Verification and acceptance evidence

Client-side verification requires all of the following:

1. `CcmExec` is running.
2. The client is assigned to site `LAB`.
3. The configured management point is
   `LABZ1-CM01.test.gell.one`.
4. The client version and site-assignment evidence are captured.

Server-side verification requires a discovered client record for
`RING0IVY24-01` after the client check-in window, with the site code `LAB`.
The final health artifact combines the existing SQL/MP/DP checks with this
client registration proof. The MP must retain its current successful local
availability checks before the client operation begins.

## Test plan

- Pester 6: client manifest validation, explicit endpoint arguments,
  compliant skip, install failure evidence, and redaction.
- Autopilot Agent contract tests: register and validate only the new work kind;
  reject arbitrary paths, unknown fields, invalid site codes, and non-lab FQDNs.
- Controller endpoint tests: typed request acceptance and rejection boundaries.
- Live acceptance: signed Agent update appears in target telemetry, typed work
  completes, client-side checks pass, and CM01 records the client in site
  `LAB`.

## Non-goals

- Client push installation, production clients, co-management enablement, or
  Patch My PC configuration.
- General remote-script execution through Autopilot Agent.
- Replacing AD discovery for later clients; this first proof deliberately pins
  the MP to make the initial single-box path deterministic.
