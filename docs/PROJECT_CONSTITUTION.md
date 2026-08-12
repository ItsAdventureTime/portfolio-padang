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
- `docs/phase-0` — Phase 0: repository bootstrap (current)
- `feat/*` — feature branches for implementation phases
- No direct commits to `main` without explicit approval

## Commit Convention

Conventional Commits style:
- `docs(product): define module requirements`
- `feat(billing): implement progress billing endpoint`
- `fix(auth): prevent JWT reuse after logout`
- `test(billing): add retention calculation tests`

## macOS Execution Policy

No application services run directly on macOS.
All runtime operations use `podman run --rm ...`.
See Section 6 of the full constitution.

## VPS Platform

Fedora CoreOS, rootless Podman, Podman Quadlets, SELinux enforcing.
See Section 7 of the full constitution.

## Secrets Policy

All sensitive values in Podman secrets only.
Never in Git, source files, `.env`, Quadlet `Environment=`, logs, or CLI args.
See Section 14–15 of the full constitution.
