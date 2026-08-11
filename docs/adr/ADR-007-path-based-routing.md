# ADR-007: Path-Based Routing for Demo vs Production

**Date:** 2026-08-11  
**Status:** Accepted (pending Caddy config verification)  
**Deciders:** Google Antigravity (Architect); confirmed by client (Bridge-PH)

## Context

Both demo and production are served from the same existing VPS with the same Caddy instance.

Requirements:
- Production: `https://delegateops.business/padang`
- Demo: `https://delegateops.business/padang/demo`

Options:
1. Subdomain routing: `padang.delegateops.business` / `demo.padang.delegateops.business`
2. Path-based routing: `/padang` / `/padang/demo` (client's requirement)

## Decision

**Path-based routing as specified by client.**

Caddy: `handle_path /padang/demo/*` and `handle_path /padang/*`  
Next.js: `NEXT_PUBLIC_BASE_PATH=/padang` and `/padang/demo` respectively.

## Rationale

- Client explicitly specified the URLs: `https://delegateops.business/padang/demo` and `https://delegateops.business/padang`
- Path-based routing is fully supported by Caddy (`handle_path`) and Next.js (`basePath` config)
- No DNS changes required; runs under the existing `delegateops.business` domain
- Caddy's `handle_path` strips the path prefix before forwarding — requires Next.js to use `basePath`

## Known Risk

- Existing Caddy configuration must be inspected before implementation
- Path conflicts with other existing services on `delegateops.business` must be verified
- Next.js `basePath` must be set correctly or all asset links and API calls will fail
- API sub-path (`/padang/api/v1/`) routing must be handled carefully (could go through Next.js rewrites or direct Caddy rule)

## Action Required

ChatGPT Codex must:
1. SSH to VPS and `cat` the existing Caddy Caddyfile/config before adding any rules
2. Verify no conflicts with existing paths
3. Add `handle_path` blocks carefully

## Consequences

- Next.js `next.config.js` must set `basePath: '/padang'` (prod) or `basePath: '/padang/demo'` (demo)
- All internal links in Next.js use relative paths — `basePath` is prepended automatically
- API calls from Next.js must be configured to use the correct base path
- If Caddy uses JSON config instead of Caddyfile, the implementation approach may differ
