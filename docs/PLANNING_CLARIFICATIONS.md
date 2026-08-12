# Planning Clarifications — Padang ERP Lite

**Date:** 2026-08-12
**Scope:** Documentation and planning only; no application implementation.

This document resolves the implementation-intake questions recorded in the
previous handoff. It is part of the repository source of truth and should be
read with `docs/HANDOFF.md`, `docs/ARCHITECTURE.md`, and the ADRs.

## 1. Demo and production are different environments

The demo build is intentionally unauthenticated:

- no login screen;
- no OTP generation or email delivery;
- requests are accepted only by the demo deployment;
- `X-Demo-Role` selects one canonical demo role for UI and API simulation;
- the demo banner states that data resets every 30 minutes.

Production uses registered users, Email OTP, RS256 access tokens, rotating
refresh tokens, and the full RBAC policy. Demo authentication behavior must
never be enabled by a runtime flag in production or by a client-supplied
header in production.

The same source code may serve both environments, but the deployment
configuration and safety checks are different. Demo reset code is compiled
and packaged only with the demo reset image; production has no reset command.

## 2. Floating latest-LTS runtime policy

The upstream runtime policy is:

| Concern | Policy |
|---|---|
| Node.js build/runtime | Official `node:lts-alpine` floating tag |
| Go build image | Official `golang:alpine` floating tag; Go has no LTS channel |
| PostgreSQL | `postgres:alpine` floating official channel; major-version changes require migration and restore validation |
| Next.js | Latest supported release selected by the project package manifest; no major number in container tags |
| OS/base image digest | Inspect and record the resolved digest at release time; do not put a version-number tag in Quadlets |

“Floating” applies to upstream image tags. Dependency lockfiles remain
required for the application package graph because they record the exact
resolved graph used for a build and are required by the constitution.

PostgreSQL is different from Node.js: automatically moving a live database to
a new major can require migration or dump/restore validation. The selected
digest and detected major version must be recorded before each approved update.

## 3. Why demo and production need separate Next.js image builds

Next.js `basePath` is not a normal runtime setting. It is compiled into client
bundles when Next.js builds. A container environment variable added after the
image is built cannot reliably change it.

Analogy: the source repository is one architectural blueprint, but the web
application is printed with a street address on every sign. The demo signs
must say `/padang/demo`; production signs must say `/padang`. Printing both
addresses onto one finished sign does not work. We therefore print two images
from the same blueprint and same source commit:

| Artifact | Build-time base path | Mutable channel tag |
|---|---|---|
| Demo frontend | `/padang/demo` | `frontend:demo-latest` |
| Production frontend | `/padang` | `frontend:latest` |

The API remains path-neutral internally. Caddy strips the external prefix for
API requests, while the frontend receives and serves its matching full path.
The two images are not two codebases: they are two environment artifacts from
one source tree. Demo is built and validated first; the production artifact is
built from the same approved source revision with the production base path.

## 4. Complete module and data-model support

The first intake found that the original schema listed core tables but did not
fully represent every product workflow. The data model is expanded by
`ADR-012` and the coverage matrix in `docs/DATABASE.md`.

Analogy: the ERP is a construction site. Existing tables represented the
building frame, but not every room or utility. The revised model adds the
missing rooms—estimates, deliveries, cost postings, payments, tax profiles,
retention, reimbursements, liquidations, and export history—while keeping one
foundation: UUID records, soft deletes, audit events, and SQL migrations.

The proposed normalized model supports:

- clients and per-client EWT configuration;
- project budgets, revisions, cost postings, progress, VOs, and retention;
- fabrication estimates, jobs, deliveries, billings, and cost postings;
- PR/PO headers and line items, fund requests, supplier payments, and SOA;
- inventory items and immutable stock transactions, including direct-to-project;
- progress billings, billing lines, collections, and BIR Form 2307 references;
- reimbursements and liquidations;
- attachments and append-only audit logs;
- QBO export batches and record-level export metadata.

The implementation plan must create referenced parent tables before child
tables. In particular, `inventory_items` must exist before
`purchase_request_items` is created, even if the documentation presents the
business workflow in a different order.

## 5. Canonical roles and workflows

Only these role identifiers are valid everywhere:

`administrator`, `general_manager`, `disbursing_check_signing_officer`,
`project_manager`, `procurement_officer`, `fabrication_supervisor`,
`finance_staff`, `billing_clerk`, `inventory_clerk`, `viewer`.

Documentation may use human-readable labels, but API claims, database values,
RBAC checks, demo role headers, and tests use the identifiers above. The human
labels `Admin`, `GM`, and `DCS` are display labels only; the old short values
and module abbreviations are not valid role values.

Canonical workflow definitions:

- PR: Draft → Submitted → GM Approval → Approved → Fulfilled.
- PO: Draft → Submitted → GM Approval → Approved → Partial Received → Received.
- Fund request, reimbursement, liquidation: Draft → Submitted → GM Approval →
  DCS for Payment → Completed; rejection may occur from approval states.
- Project/fabrication billing: Draft → GM Approval → Issued to Client →
  Collection → Completed.

No payment or client issuance is valid before the required GM approval.

## 6. Backup architecture correction

The previous example used a PostgreSQL image but invoked a storage-upload
client that was not present in the image. That is like putting a plumber in a
truck without the pipe wrench: the image can run `pg_dump`, but it does not
provide the Backblaze upload command.

The plan now uses one dedicated backup image containing both PostgreSQL client
tools and rclone configured for Backblaze B2's S3-compatible API. It is built
from the project’s approved container workflow and published as
`backup:latest`. The one-shot service:

1. reads the database and B2 Podman secrets from `/run/secrets`;
2. streams `pg_dump -Fc` directly to Backblaze B2 with `rclone rcat`, without a
   plaintext dump file;
3. writes a checksum and manifest for the dump;
4. copies attachment objects to the dated backup prefix and records checksums;
5. applies retention and verifies the uploaded objects;
6. exits non-zero on any failure.

The backup image is not a runtime application image. The production Quadlet
uses `backup:latest`, while the database uses the floating official
`postgres:alpine` channel. Backblaze application-key credentials are mounted
as files and converted into an ephemeral rclone configuration under `/run`;
no secret value appears in an image, repository file, command argument, or
log.

The restore test downloads a selected dump and attachment manifest into an
isolated non-production target. Production is never used as a restore test
target.

## 7. One codebase with future iOS and Android clients

The Go API is the single source of truth. Web and mobile clients share the
OpenAPI contract, generated TypeScript types, domain validation rules, role
identifiers, error envelopes, pagination, and business workflows.

Analogy: the API is the kitchen and web/iOS/Android are three dining rooms.
They share the same recipes, inventory, and order rules, but each room needs
controls designed for its surface. Trying to make browser DOM components run
unchanged as native mobile controls would create avoidable coupling.

When mobile work begins, add an Expo/React Native client using TypeScript and
the current supported New Architecture. It may live in the same repository
and share packages for API types, auth protocol, formatting, and domain logic.
The web and mobile presentation components remain platform-appropriate.

Browser production auth uses an HttpOnly, Secure, SameSite cookie for the
refresh token. Mobile production auth uses the same rotating token protocol,
but stores the refresh token only in iOS Keychain or Android Keystore-backed
secure storage. Access tokens remain memory-only on both clients.

## 8. Light-only design system and CSP

The launch UI is light-only. Dark-mode tokens and dark glassmorphism examples
are removed from the design contract.

All surfaces, status badges, cards, tables, and navigation use the defined
light token set. Fonts are loaded through Next.js `next/font` or local assets,
which self-hosts them at build time. The browser therefore does not need
`fonts.googleapis.com` or `fonts.gstatic.com` in `connect-src`, `style-src`, or
`font-src`.

The CSP remains same-origin for scripts, styles, images, fonts, and API calls.
The current temporary Next.js hydration allowance is documented as a launch
constraint; nonce-based CSP remains a hardening follow-up.

## 9. Demo reset safety invariant

Reset is an operator/systemd action, never a public unauthenticated endpoint.
It fails closed unless all of these are true:

- `APP_ENV=demo`;
- `RUN_MODE=seed`;
- `DB_NAME=padang_demo`;
- the resolved database identity is the demo database;
- no configured host, database, or service identifier contains the production
  environment target.

The reset command must refuse to run when any guard is missing, contradictory,
or unreadable. Production images do not include the reset command.

## Research basis

- [Node.js release schedule](https://nodejs.org/en/about/previous-releases)
- [Next.js `basePath`](https://nextjs.org/docs/pages/api-reference/config/next-config-js/basePath)
- [Next.js self-hosting](https://nextjs.org/docs/app/guides/self-hosting)
- [Next.js font optimization](https://nextjs.org/docs/app/getting-started/fonts)
- [Caddy `route`](https://caddyserver.com/docs/caddyfile/directives/route)
- [Caddy `reverse_proxy`](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Podman auto-update](https://docs.podman.io/en/latest/markdown/podman-auto-update.1.html)
- [React Native TypeScript](https://reactnative.dev/docs/typescript)
- [Expo SDK reference](https://docs.expo.dev/versions/latest/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
- [Backblaze B2 S3-Compatible API](https://www.backblaze.com/docs/cloud-storage-s3-compatible-api)
- [Backblaze B2 integration guidance](https://www.backblaze.com/docs/en/cloud-storage-get-started-with-a-backblaze-integration)
- [rclone S3 backend](https://rclone.org/s3/)
- [rclone `rcat`](https://rclone.org/commands/rclone_rcat/)
- [rclone `check`](https://rclone.org/commands/rclone_check/)
