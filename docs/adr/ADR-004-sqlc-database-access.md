# ADR-004: sqlc for Type-Safe Database Access

**Date:** 2026-08-11  
**Status:** Accepted  
**Deciders:** Google Antigravity (Architect)

## Context

The Go backend needs database access that is:
- Type-safe (financial data; bugs are costly)
- Auditable (plain SQL is readable and reviewable)
- Compile-time verified (not runtime errors on type mismatch)
- Performant (no N+1 query problems from ORM magic)

## Decision

**sqlc (v1.x, latest) for all database queries.**

## Rationale

- Write plain SQL queries in `.sql` files → sqlc generates Go structs and functions
- Compile-time type checking: if SQL and Go types don't match, `sqlc generate` fails
- Plain SQL is fully reviewable, portable, and debuggable (vs. ORM query builder)
- No runtime reflection; no "magic" that hides query structure
- Works natively with pgx v5 (PostgreSQL native driver)
- Transaction support is explicit and straightforward
- Avoids N+1 problems that ORMs often introduce (developer controls exact queries)

## Alternatives Considered

- **GORM:** Popular but ORM magic obscures queries; harder to audit financial data; N+1 risk
- **sqlx:** Good middle-ground; less type safety than sqlc; manual struct scanning
- **Bun:** Modern ORM; better than GORM but still adds abstraction over plain SQL

## Consequences

- All DB queries must be written in SQL files (`backend/sqlc/queries/*.sql`)
- Running `sqlc generate` is required after any query change
- Complex queries (e.g., report aggregations) are written as raw SQL — this is a feature, not a limitation
- Developers must know SQL; appropriate for an ERP project
