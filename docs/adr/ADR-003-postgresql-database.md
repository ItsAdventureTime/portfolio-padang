# ADR-003: PostgreSQL 17 as Database

**Date:** 2026-08-11  
**Status:** Accepted  
**Deciders:** Google Antigravity (Architect)

## Context

The ERP stores:
- Financial records (projects, billings, fund requests, collections)
- Relational data (projects → budget items → billings → collections)
- Audit logs (append-only)
- JSONB state snapshots (audit before/after)
- Multi-user concurrent access (≤ 20 users)

## Decision

**PostgreSQL 17 (current stable, released Oct 2024).**

## Rationale

- Relational model is the correct choice for financial ERP data
- NUMERIC(18,4) for monetary amounts: no floating-point precision errors
- JSONB for audit log before/after state: flexible without schema migration for every field
- Row-Level Security (RLS): available for future multi-tenancy
- Advisory locks: safe for application-level locking (e.g., billing number generation)
- `gen_random_uuid()` built-in: no extension needed for UUID PKs
- Generated columns: for computed fields (e.g., budget item totals)
- Excellent pgx v5 driver for Go: high performance, native protocol
- sqlc: generates type-safe Go code from SQL; PostgreSQL-native
- Supported until November 2029

## Alternatives Considered

- **MySQL 8.4:** Common; weaker JSONB, weaker analytical functions, less NUMERIC precision control
- **SQLite:** ❌ Not suitable for concurrent multi-user ERP
- **CockroachDB/distributed:** Overkill for ≤ 20 user ERP; adds operational complexity

## Consequences

- PostgreSQL major version upgrades require `pg_upgrade` or dump/restore
- Logical dump backups (`pg_dump -Fc`) are the standard; PITR available as future option
- sqlc requires re-generation when PostgreSQL-specific query syntax is used; keep sqlc and pgx versions aligned
