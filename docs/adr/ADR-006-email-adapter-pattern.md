# ADR-006: Provider-Neutral Email Adapter Pattern

**Date:** 2026-08-11  
**Status:** Accepted  
**Deciders:** Google Antigravity (Architect)

## Context

Current email provider: Resend.
Known future migration: Azure Communication Services Email.

The ERP must send transactional emails for:
- Approval requests
- Approval decisions (granted/rejected)
- Billing issued to client
- Payment received

Business logic must not be tightly coupled to Resend.

## Decision

**Provider-neutral `EmailService` interface with separate provider adapters.**

```
Application Business Logic
  └─ EmailService interface
       └─ Provider Adapter (selected via EMAIL_PROVIDER env var)
            ├─ ResendAdapter (current)
            └─ AzureAdapter (future)
```

## Rationale

- Migrating from Resend to Azure requires replacing the adapter only — no business logic changes
- Templates, recipient logic, retry policy, and event mapping stay in provider-neutral code
- Provider credentials are in Podman secrets (provider-specific)
- `EMAIL_PROVIDER` environment variable controls adapter selection (non-secret)
- Per project constitution §19

## Consequences

- Slightly more code than direct Resend SDK usage
- All email sends go through the interface — testable with a mock adapter
- Azure adapter must be built when migration is required (Phase 2+)
- Demo environment: email events are logged only; no actual sending (MockAdapter in demo)
