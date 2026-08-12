# ADR-010: Environment-Specific Next.js Build Artifacts

**Date:** 2026-08-12
**Status:** Accepted clarification
**Deciders:** Google Antigravity (Architect); Bridge-PH requirements

## Context

Demo is served at `/padang/demo`; production is served at `/padang`. Next.js
`basePath` is inlined into client bundles at build time, so one finished
frontend image cannot safely switch between those prefixes with a runtime
environment variable.

## Decision

Keep one frontend source tree and build two environment artifacts:

- demo: `NEXT_PUBLIC_BASE_PATH=/padang/demo`, image channel `demo-latest`;
- production: `NEXT_PUBLIC_BASE_PATH=/padang`, image channel `latest`.

Both artifacts must be built from the same approved source revision. Demo is
validated first. Production promotion rebuilds or promotes the identical
source revision with the production base path and never copies demo data or
demo reset functionality into production.

Upstream runtime images use floating official tags: `node:lts-alpine` for
Next.js and `golang:alpine` for Go builds. The package lockfile remains
committed; resolved image digests are recorded for audit and rollback.

## Consequences

- no duplicated business logic or frontend source;
- two frontend image builds and two mutable deployment channels;
- base-path changes require a new frontend image build;
- Caddy must preserve the frontend prefix and strip only the API prefix;
- deployment tests must verify both `/padang/demo` and `/padang` routing.
