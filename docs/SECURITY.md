# SECURITY.md — Padang ERP Lite

## Standards Applied

- [OWASP ASVS 5.0.0](https://owasp.org/www-project-application-security-verification-standard/) (released May 2025)
- [OWASP Top 10:2025](https://owasp.org/Top10/2025/)
- OWASP Secrets Management Cheat Sheet
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) (UI accessibility, covered in UI_UX.md)
- [Go vulnerability management and govulncheck](https://go.dev/doc/security/vuln/)

These references were checked on 2026-08-14. The project applies the stable
published versions above; a later standard revision requires an explicit
architecture or security review before changing this baseline.

---

## Authentication

### Method: Email OTP (Passwordless) — Production

No passwords. Users authenticate by entering their registered email address and a one-time code delivered via email.

**OTP Flow:**
1. User enters registered email → `POST /api/v1/auth/request-otp`
2. Server generates a cryptographically secure 6-digit code
3. Code stored server-side (PostgreSQL `otp_codes` table) as bcrypt hash; linked to user email + expiry
4. Email sent via Resend with the 6-digit code
5. User enters code → `POST /api/v1/auth/verify-otp`
6. Server validates: code matches hash, not expired (10 min TTL), not already used, user is active
7. On success: OTP record marked used (single-use); access token + refresh token issued

**OTP Security Controls:**
- Code: 6 digits; cryptographically random (crypto/rand); bcrypt hash stored (not plaintext)
- TTL: 10 minutes from generation
- Single-use: marked used immediately on first successful verification
- Race safety: the `used_at IS NULL` conditional update makes concurrent
  verification attempts single-winner; a losing request receives the same
  invalid/expired response
- Rate limiting: 3 OTP requests per email per 15 minutes; 5 verify attempts per OTP before auto-invalidation
- Account enumeration prevention: identical response for unknown vs known email ("if your email is registered, a code has been sent")
- Email delivery: Resend with proper SPF/DKIM/DMARC records (avoids spam classification)
- OTP email body: clearly states context ("Use this code to log into Padang ERP Lite")

**Why Email OTP over Magic Links:**
- OTP codes are slightly more secure for ERP financial data — prevents link pre-fetching by enterprise email security scanners (which can inadvertently consume a magic link, invalidating the session before the user clicks)
- Consistent UX on all email clients (no click required; just copy/type the code)
- Trade-off: slightly more friction (copy/paste) vs. magic link (one-click) — acceptable for an internal tool

### JWT Tokens (issued after OTP verification)
- Algorithm: RS256 (asymmetric) — backend signs with the private key and
  validates tokens; clients treat access tokens as opaque credentials
- Access token lifetime: 15 minutes
- Refresh token lifetime: 7 days, rotating on each use
- Refresh token: stored server-side as bcrypt hash in `refresh_tokens` table
- Access token: stored in memory only (never localStorage, never sessionStorage)
- Refresh token delivery: HttpOnly, Secure, SameSite=Strict cookie (production)
- The Next.js 16 `frontend/proxy.ts` uses refresh-cookie presence only for an
  optimistic redirect at the `/padang` boundary; the client then verifies the
  session with `GET /api/v1/auth/me` before rendering production records.
- Refresh-cookie Path is `/` so the `/padang` route boundary and same-origin
  `/padang/api` refresh flow receive the same HttpOnly cookie.
- Token revocation: refresh token revoked on logout; explicit security reset
  revokes active refresh tokens

### Demo Mode
- No authentication enforced
- Requests receive a synthetic demo identity only when `APP_ENV=demo`
- `X-Demo-Role` is accepted only in demo and must match the canonical role enum;
  it is ignored in production
- The demo role selector stores only the selected canonical role in browser
  session storage; the API validates the header independently on every request.
- No OTP codes generated or emails sent in demo environment
- Demo reset is operator/systemd-only and fails closed unless `APP_ENV=demo`,
  `RUN_MODE=seed`, and `DB_NAME=padang_demo` all match

### Rate Limiting (OTP-specific)
- `/auth/request-otp`: 3 requests per email per 15 minutes per IP
- `/auth/verify-otp`: 5 failed attempts per OTP before the code is auto-invalidated; 10 attempts/min per IP
- OTP lockout notifications and rate-limit audit events are production-hardening
  follow-ups; failed attempts are bounded and persisted in the OTP record.

---

## Authorization (RBAC)

### Enforcement
- Role check in middleware (before handler is called)
- Resource ownership check in service layer (e.g., Project Manager can only
  edit own projects)
- No reliance on client-supplied role claims in production; role is read from
  the database per request

### Permission Matrix

| Action | administrator | general_manager | disbursing_check_signing_officer | project_manager | procurement_officer | fabrication_supervisor | finance_staff | billing_clerk | inventory_clerk | viewer |
|---|---|---|---|---|---|---|---|---|---|---|
| User management | ✓ | — | — | — | — | — | — | — | — | — |
| View all modules | ✓ | ✓ | partial | partial | partial | partial | partial | partial | partial | ✓ |
| Create projects | ✓ | — | — | ✓ | — | — | — | — | — | — |
| Approve (GM queue) | ✓ | ✓ | — | — | — | — | — | — | — | — |
| Execute payment (DCS) | ✓ | — | ✓ | — | — | — | — | — | — | — |
| Create procurement | ✓ | — | — | ✓ | ✓ | — | — | — | — | — |
| Create billing | ✓ | — | — | — | — | — | — | ✓ | — | — |
| Manage inventory | ✓ | — | — | — | ✓ | — | — | — | ✓ | — |
| View reports | ✓ | ✓ | — | partial | partial | partial | partial | partial | — | ✓ |
| Export data | ✓ | ✓ | — | partial | partial | partial | partial | partial | — | — |
| System settings | ✓ | — | — | — | — | — | — | — | — | — |

Partial = filtered to relevant scope (e.g., the Project Manager sees only their
projects).

---

## Secrets Management

### Policy
- All sensitive values in Podman secrets
- Mounted under `/run/secrets/<secret-name>` (file-based, not environment variables)
- Application reads secrets from files at startup
- No secret values in: Git, source files, `.env`, Quadlet `Environment=`, CLI args, logs

### Secret Inventory

| Podman Secret Name | Content | Shared Between |
|---|---|---|
| `bridge-ph-padang-demo-db-password` | Demo PostgreSQL app user password | API container (demo) |
| `bridge-ph-padang-demo-b2-key-id` | B2 application key ID (demo) | API container (demo) |
| `bridge-ph-padang-demo-b2-application-key` | B2 application key secret (demo) | API container (demo) |
| `bridge-ph-padang-prod-db-password` | Prod PostgreSQL app user password | API container (prod) |
| `bridge-ph-padang-prod-jwt-private-key` | RS256 private key (prod) | API container (prod) |
| `bridge-ph-padang-prod-jwt-public-key` | RS256 public key (prod) | API container (prod) |
| `bridge-ph-padang-prod-resend-api-key` | Resend API key (prod) | API container (prod) |
| `bridge-ph-padang-prod-b2-key-id` | B2 application key ID | API container, backup container (prod) |
| `bridge-ph-padang-prod-b2-application-key` | B2 application key secret | API container, backup container (prod) |
| `bridge-ph-padang-prod-backup-encryption-key` | Backup encryption passphrase | Backup container (prod) |

The backup utility image also receives these Backblaze application-key secrets
as mounted files. It creates only an ephemeral rclone configuration under
`/run` for the Backblaze S3-compatible upload process; the file is never
persisted or logged.

Backblaze keys must be restricted to the required bucket and file prefix. Use
`readFiles`, `writeFiles`, and `deleteFiles` for the application workflows. Do
not grant `listAllBucketNames` by default; add it only if a bucket-restricted
S3 client must call `ListBuckets` or `HeadBucket`, and record that exception in
the operations log.

### Generation
- Human-provided values are entered through the no-echo interactive script.
- JWT keys are generated with OpenSSL in a mode-0700 temporary directory, then
  imported into Podman secrets; values are never printed.
- Generated internal credentials should be piped directly to
  `podman secret create ... -` when automation is required.
- No `.env` files, secret values in repository files, or shell-history values.

See `scripts/secrets-setup.sh` for the interactive management script.

---

## Input Validation

- Request bodies are decoded with unknown-field rejection and explicit handler
  validation; module-specific schemas are added with each endpoint.
- SQL: all queries via sqlc (parameterized; no string concatenation)
- Attachment presigning validates filename/path, MIME/extension pairing, file
  size (1–50 MiB), category, entity ownership, and role before a B2 URL is
  issued. The server derives the storage key and signs the expected content
  type and length; upload-content inspection remains a required follow-up
  before unrestricted production file workflows.
- Amounts: validated as non-negative where required; precision enforced
- UUIDs: validated format before any database lookup
- Enum fields: validated against allowed value sets
- String lengths: max limits on all text fields

---

## Output Encoding

- All JSON responses: `Content-Type: application/json; charset=utf-8`
- No HTML rendering in API responses
- Frontend: React handles output encoding by default; no `dangerouslySetInnerHTML` usage
- CSP headers restrict scripts and styles to the documented Next.js launch
  policy; nonce-based CSP is a hardening follow-up

---

## CSRF Protection

- API is stateless; Bearer JWT in `Authorization` header (not cookie-based auth)
- CSRF attacks not applicable for Bearer token auth
- Exception: refresh token uses HttpOnly cookie → SameSite=Strict provides CSRF protection

---

## Session Management

- Stateless API; no server-side session state
- Refresh token invalidated on logout
- Refresh rotation is single-use under concurrent requests: the old row is
  conditionally revoked before a replacement token is issued
- All refresh tokens invalidated on OTP re-verification or explicit account
  security reset
- `refresh_tokens` table pruned of expired tokens periodically (scheduled job or on login)

### Future Mobile Clients

Mobile clients use the same API, token lifetimes, rotation, revocation, and
server-side hashing. They do not use browser cookies: refresh tokens are
stored only in iOS Keychain or Android Keystore-backed secure storage. Access
tokens remain memory-only. API authorization is always server-enforced and
never derived from a client-supplied role.

---

## Transport Security

- TLS enforced at Caddy (HTTPS only)
- HSTS with `max-age=31536000; includeSubDomains`
- Internal container-to-container communication on private Podman network (not encrypted; all within VPS)
- B2 API calls: HTTPS only
- Resend API calls: HTTPS only

---

## SSRF Prevention

- B2 upload: only application-initiated server-side uploads; no user-supplied URLs fetched
- No URL fetching based on user input
- Email templates: no user-controlled URLs in `<img>` or `<a>` tags that the server follows

---

## Rate Limiting

See `docs/API.md` for rate limit values.
Implemented in Go middleware using a process-local sliding window for OTP
request/verify and refresh endpoints. Application-wide per-user throttling is
still a production-readiness follow-up.

---

## Audit Logging

- Implemented state-changing C1 routes append to `audit_log` in the same
  transaction as the mutation, including workflow transitions, approvals,
  project/fabrication/procurement/billing/inventory writes, and attachment
  presign metadata.
- Approval actions log actor, timestamp, and before/after state.
- Attachment audit records include entity, filename, derived storage key,
  content type, size, actor, IP address, and user agent.
- Login-attempt, account-lockout, and export-event audit coverage remains a
  pre-production follow-up; this document does not claim those events are
  currently wired.
- `audit_log` is append-only; no UPDATE or DELETE in application code
- Log retention: indefinite (table-based; B2 backup covers it)

---

## Dependency Security

- Go modules: `go mod verify` in CI
- Go dependencies: run `govulncheck ./...` from the containerized Go toolchain
  when the scanner is available; review findings by reachable symbols
- npm: `npm audit --audit-level=high` in CI; no known high/critical
  vulnerabilities at release
- C1 scan on 2026-08-14: `govulncheck` reported zero reachable
  vulnerabilities after updating `github.com/jackc/pgx/v5` to v5.9.2 and
  `golang.org/x/text` to v0.39.0; it still reported unreachable module findings
  for review during future dependency updates.
- Container base images: use official images; specify digest in `docs/DEPENDENCIES.md`
- Podman auto-update is disabled for application Quadlets and the deployment
  wrapper fails closed if `podman-auto-update.timer` is active or enabled.

---

## Container Security

- Rootless Podman (no root escalation)
- SELinux enforcing; no `--security-opt label=disable`
- No privileged containers
- No `--cap-add` beyond what the application strictly requires
- Database and API ports NOT exposed to host; internal network only (proxy-network pattern)
- Frontend and API containers on proxy network (Caddy-reachable); DB on internal network only

---

## OWASP Controls Summary

| OWASP Top 10:2025 | Control |
|---|---|
| A01: Broken Access Control | RBAC middleware; ownership checks; no client role trust |
| A02: Cryptographic Failures | TLS; bcrypt OTP hash; RS256 JWT; OTP code via crypto/rand; secrets in Podman secrets |
| A03: Injection | sqlc parameterized queries; input validation; no eval |
| A04: Insecure Design | Email OTP eliminates password reuse risk; separation of concerns; least privilege |
| A05: Security Misconfiguration | Security headers; no debug endpoints in prod; no exposed ports |
| A06: Vulnerable Components | `go mod verify`; `npm audit`; manual image update review |
| A07: Auth Failures | Email OTP (no passwords); single-use codes; rate limiting; JWT rotation; no secret in logs |
| A08: Software Integrity | go.sum; package-lock.json; reviewed image pulls and recorded digests |
| A09: Logging Failures | Transactional state-change audit log; structured logging; no secret in logs; login/export events remain a pre-production gap |
| A10: SSRF | No user-supplied URL fetching; no internal service exposure |
