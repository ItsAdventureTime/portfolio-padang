# ADR-002: Next.js 15 App Router as Frontend Framework

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

**Next.js 15 with App Router, TypeScript, Tailwind CSS v4, shadcn/ui.**

## Rationale

- **Hybrid rendering:** Server Components for shells and initial data; Client Components for interactive islands (forms, tables, modals)
- **shadcn/ui:** Full code ownership; built on Radix UI primitives; accessible; integrates perfectly with TanStack Table and React Hook Form
- **TanStack Query v5:** Industry-standard server state management; works well with RSC hydration pattern
- **TypeScript + openapi-typescript:** Type safety across API boundary; compile-time contract validation
- **View Transitions API + Scroll-driven animations:** Native browser API support in 2025; no library needed
- **Next.js base path support:** `NEXT_PUBLIC_BASE_PATH` enables clean sub-path deployment (`/padang`, `/padang/demo`)

## Alternatives Considered

- **Vite + React SPA:** Simpler; no SSR; loses fast initial load; harder sub-path config
- **Remix:** Server-centric; strong alternative; less ecosystem support for data-heavy ERP patterns
- **Vue/Nuxt:** Smaller ecosystem for ERP-specific components; team unfamiliar

## Consequences

- Next.js 15 App Router requires understanding of Server vs Client component boundary
- Sub-path routing (`/padang/demo`) requires careful Caddy `handle_path` configuration (see ADR-007)
- TypeScript type generation requires running `npm run generate:types` after backend API changes
- Tailwind v4 has breaking changes from v3; migration path is well-documented
