# ADR-012: Complete Operational Data Model

**Date:** 2026-08-12
**Status:** Accepted clarification
**Deciders:** Google Antigravity (Architect); Bridge-PH requirements

## Context

The first schema outline covered projects, basic fabrication jobs,
procurement, inventory, project billing, collections, attachments, and audit
logs. It did not fully persist all workflows described in the product brief.

## Decision

Extend the migration specification with normalized records for:

- clients and tax profiles, including EWT enablement/rate;
- project budget revisions, cost postings, and retention transactions;
- fabrication estimates, delivery receipts, and fabrication billings;
- purchase-order line items and supplier payments/SOA inputs;
- reimbursements and liquidations;
- QBO export batches and record-level export status/timestamps;
- BIR Form 2307 references on collection records.

All state-changing records retain UUID identity, timestamps, actor identity,
soft-delete behavior where appropriate, and audit events. Derived reports use
these source records rather than duplicating mutable totals.

## Consequences

- TASK-001 migration scope expands before code generation begins;
- workflow tests can verify complete end-to-end records;
- report and QBO export queries have authoritative source tables;
- migration ordering must respect foreign-key dependencies;
- schema changes remain reviewable through SQL migrations and sqlc.
