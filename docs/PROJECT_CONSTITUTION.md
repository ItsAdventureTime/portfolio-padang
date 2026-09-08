# Project Constitution — Padang ERP Lite

This document is the shared engineering constitution for the Padang ERP Lite project.
It governs both the Google Antigravity (Architect) and ChatGPT Codex (Implementer) agents.

> **The full constitution text is maintained in AGENTS.md (passed as system context).**
> This file records the project-specific application of its rules.

---

## Role Assignments

| Agent | Role |
|---|---|
| Google Antigravity | Product Architect & Reviewer |
| ChatGPT Codex | Implementation Engineer |

## Source of Truth

The Git repository is the sole source of truth. Neither agent's chat history is authoritative.

## Authorization Protocol

`docs/HANDOFF.md` is the single source of go/no-go for each phase.

- If HANDOFF.md says a phase is **pre-authorized**, begin immediately — no keyword or phrase from the user is required.
- If HANDOFF.md says **approval required**, stop and wait for the user to confirm before writing any code.
- Any material deviation from the documented architecture must be flagged to Antigravity (Architect) before proceeding, regardless of authorization status.

## Branch Strategy

- `main` — stable, reviewed code only
- `docs/phase-0` — historical Phase 0 repository bootstrap reference
- `feat/*` — feature branches for implementation phases
- Direct commits to `main` are normally disallowed. The explicit user-directed
  maintenance workflow may update `main` after review, applicable validation,
  and a GitHub-verified commit.

## Commit Convention

Conventional Commits style:
- `docs(product): define module requirements`
- `feat(billing): implement progress billing endpoint`
- `fix(auth): prevent JWT reuse after logout`
- `test(billing): add retention calculation tests`

## macOS and Docker Sandbox Execution Policy

macOS is the control/edit plane. Run application runtimes, package managers,
builds, tests, linters, scanners, migrations, and code generation through the
repository's Docker Sandbox:

```sh
jk-sbx-project ensure
jk-sbx-project exec <command> [args...]
```

Do not run local project workloads directly on macOS or through local Podman.
Podman remains valid for the remote Fedora CoreOS production/runtime plane.
See `docs/TESTING.md` and `docs/GIT_WORKFLOW.md`.

## GitHub HTTPS and GitHub-Signed Commit Policy

GitHub changes use the authenticated `gh` CLI with an HTTPS `origin` only.
Before publishing, run `gh auth status --hostname github.com`, verify the
HTTPS `origin`, and create the reviewed commit through GitHub's
`createCommitOnBranch` GraphQL mutation with an exact `expectedHeadOid`.
Verify the resulting GitHub signature and tree with `gh api`, then synchronize
local refs through the authenticated HTTPS credential helper. SSH remotes, SSH
transport keys, passkeys, raw tokens, and force pushes are outside this
project workflow. VPS deployment SSH is a separate runtime transport and does
not change the GitHub rule.

## VPS Platform

Fedora CoreOS, rootless Podman, Podman Quadlets, SELinux enforcing.
See Section 7 of the full constitution.

## Secrets Policy

All sensitive values in Podman secrets only.
Never in Git, source files, `.env`, Quadlet `Environment=`, logs, or CLI args.
See Section 14–15 of the full constitution.

## Planning Clarifications

`docs/PLANNING_CLARIFICATIONS.md` records the resolved demo/production,
floating-runtime, mobile-client, complete-data-model, backup, light-theme,
and demo-reset decisions that govern implementation planning.
