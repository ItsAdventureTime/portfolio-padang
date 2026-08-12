# ADR-007: Path-Based Routing for Demo vs Production

**Date:** 2026-08-11  
**Status:** Accepted — resolved after Caddyfile inspection  
**Deciders:** Google Antigravity (Architect)

## Context

Both demo and production are served from the same existing VPS with the same Caddy instance at `delegateops.business`.

Requirements:
- Production: `https://delegateops.business/padang`
- Demo: `https://delegateops.business/padang/demo`

The existing Caddyfile has been inspected. Key findings:
- PIMASCOR uses separate imported handler files (`pimascor-production.handlers.Caddyfile`)
- PIMASCOR API routing: `handle /path/api/*` + `uri strip_prefix` → direct `reverse_proxy` to API container
- PIMASCOR frontend: served as static files from a volume (React/Vite SPA)
- Caddy reaches containers via dedicated proxy networks (not `caddy.network`)

## Decision

**Path-based routing as specified. Separate handler Caddyfile files following PIMASCOR pattern.**

Files to create:
- `/home/jk/caddy/conf/padang-demo.handlers.Caddyfile`
- `/home/jk/caddy/conf/padang-production.handlers.Caddyfile`

Imported inside `delegateops.business { ... }` block before the `handle { }` fallback.

Routing:
```
/padang/demo/api/* → uri strip_prefix /padang/demo → bridge-ph-padang-demo-api:8080
/padang/demo/*     → reverse_proxy bridge-ph-padang-demo-frontend:3000 (full path kept)
/padang/api/*      → uri strip_prefix /padang       → bridge-ph-padang-api:8080
/padang/*          → reverse_proxy bridge-ph-padang-frontend:3000      (full path kept)
```

Networks Caddy joins (to be added to `caddy.container`):
- `bridge-ph-padang-demo-proxy.network`
- `bridge-ph-padang-proxy.network`

## Key Difference from PIMASCOR

PIMASCOR frontend = static files served by Caddy from a volume.
Padang frontend = **Next.js (live container)**; Caddy must `reverse_proxy` to it (not `file_server`).

This means:
- Full path is preserved when forwarding to Next.js (use `handle`, NOT `handle_path`)
- Next.js `basePath` config must match the path prefix (`/padang` or `/padang/demo`)

## CSP Requirement

The selected Next.js App Router release requires the documented CSP allowance
for its hydration/runtime behavior.
The existing `same_origin_web_csp` snippet would break Next.js.
A new `padang_nextjs_csp` snippet is defined (see `docs/DEPLOYMENT.md`).
Phase 2: implement nonce-based CSP via Next.js middleware to replace `'unsafe-inline'`.

## Consequences

- `caddy.container` must be updated to join the two proxy networks
- Caddy reload required: `systemctl --user daemon-reload && systemctl --user restart caddy.service`
- Each frontend artifact must set its build-time `basePath` to `/padang`
  (production) or `/padang/demo` (demo); one image cannot safely serve both
  paths without rebuilding (see ADR-010)
- Go API serves routes at `/api/v1/...`; after stripping `/padang` or `/padang/demo`, path matches correctly
- Handler import order matters: padang imports must appear before the `handle { }` fallback block
