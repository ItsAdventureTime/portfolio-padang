# ADR-001: Go + Chi as Backend Framework

**Date:** 2026-08-11  
**Status:** Accepted  
**Deciders:** Google Antigravity (Architect)

## Context

The ERP requires a stable, long-lived backend API. Key considerations:
- Operator preference: Go
- ERP complexity: many modules, approval workflows, financial calculations
- Future mobile clients (iOS/Android) require a stateless REST API
- Maintainability over decades, not months

## Decision

**Go (latest stable from the floating official `golang:alpine` channel) with
Chi router (v5).** Go has no LTS channel; supported-release validation happens
when the container channel is resolved.

## Rationale

- **Chi** is minimalist and stays close to Go's `net/http` standard library
- No framework lock-in; layered architecture (Handler → Service → Repository) is enforced by convention, not the framework
- Business logic remains framework-independent — swapping Chi for another router would not touch service or domain code
- Full compatibility with all standard-library-compliant middleware and security/observability tooling
- Compiles to a single static binary; simple container deployment
- Chi is actively maintained; suitable for long-lived enterprise systems

## Alternatives Considered

- **Echo**: Strong alternative; more batteries included; net/http compatible; considered but adds more convention than required
- **Gin**: Large community; net/http compatible; acceptable but similar trade-offs to Echo
- **Fiber**: Rejected — uses `fasthttp` (non-standard); ecosystem friction for standard Go middleware

## Consequences

- Developers must follow the layered architecture convention manually (Chi does not enforce it)
- OpenAPI spec must be maintained alongside code (no auto-generation from Chi; use swaggo or huma)
- Strong type safety from sqlc and Go's type system compensates for Chi's minimalism
