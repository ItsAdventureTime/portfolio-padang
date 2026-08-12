# ADR-002: Next.js App Router as Frontend Framework

**Date:** 2026-08-11  
**Status:** Accepted  
**Deciders:** Google Antigravity (Architect)

## Context

The ERP requires a data-dense dashboard with:
- Server-side rendered initial loads (fast FCP)
- Interactive client-side forms and data tables
- Role-based UI rendering
- Path-based routing (`/padang/demo` vs `/padang`)
- Modern animations (View Transitions, Scroll-driven)
- Future mobile-compatible API (handled by Go backend; frontend is web-only)

## Decision

**The latest supported Next.js App Router release with TypeScript, Tailwind
CSS, and shadcn/ui.** The selected release is determined by the committed
application manifest and lockfile; this ADR does not freeze a stale framework
number.

## Rationale

- **Hybrid rendering:** Server Components for shells and initial data; Client Components for interactive islands (forms, tables, modals)
- **shadcn/ui:** Full code ownership; built on Radix UI primitives; accessible; integrates perfectly with TanStack Table and React Hook Form
- **TanStack Query:** Industry-standard server state management; use the latest supported release and lock it in the application manifest
- **TypeScript + openapi-typescript:** Type safety across API boundary; compile-time contract validation
- **View Transitions API + Scroll-driven animations:** Native browser API support in 2025; no library needed
- **Next.js base path support:** `NEXT_PUBLIC_BASE_PATH` enables clean sub-path deployment (`/padang`, `/padang/demo`)

## Alternatives Considered

- **Vite + React SPA:** Simpler; no SSR; loses fast initial load; harder sub-path config
- **Remix:** Server-centric; strong alternative; less ecosystem support for data-heavy ERP patterns
- **Vue/Nuxt:** Smaller ecosystem for ERP-specific components; team unfamiliar

## Consequences

- The selected Next.js App Router release requires understanding of the Server
  vs Client component boundary
- Sub-path routing (`/padang/demo`) requires separate build artifacts because
  `basePath` is compiled into the client bundle (see ADR-007 and ADR-010)
- TypeScript type generation requires running `npm run generate:types` after backend API changes
- Tailwind v4 has breaking changes from v3; migration path is well-documented
