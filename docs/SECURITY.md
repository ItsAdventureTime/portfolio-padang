# SECURITY.md — Padang ERP Lite

## Standards Applied

- OWASP ASVS 5.0.0 (Application Security Verification Standard)
- OWASP Top 10:2025
- OWASP Secrets Management Cheat Sheet
- WCAG 2.2 (UI accessibility, covered in UI_UX.md)

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
7. On success: OTP record deleted (single-use); access token + refresh token issued

**OTP Security Controls:**
- Code: 6 digits; cryptographically random (crypto/rand); bcrypt hash stored (not plaintext)
- TTL: 10 minutes from generation
- Single-use: deleted immediately on first successful verification
- Rate limiting: 3 OTP requests per email per 15 minutes; 5 verify attempts per OTP before auto-invalidation
- Account enumeration prevention: identical response for unknown vs known email ("if your email is registered, a code has been sent")
- Email delivery: Resend with proper SPF/DKIM/DMARC records (avoids spam classification)
- OTP email body: clearly states context ("Use this code to log into Padang ERP Lite")

**Why Email OTP over Magic Links:**
- OTP codes are slightly more secure for ERP financial data — prevents link pre-fetching by enterprise email security scanners (which can inadvertently consume a magic link, invalidating the session before the user clicks)
- Consistent UX on all email clients (no click required; just copy/type the code)
- Trade-off: slightly more friction (copy/paste) vs. magic link (one-click) — acceptable for an internal tool

### JWT Tokens (issued after OTP verification)
- Algorithm: RS256 (asymmetric) — backend signs with private key; frontend verifies with public key
- Access token lifetime: 15 minutes
- Refresh token lifetime: 7 days, rotating on each use
- Refresh token: stored server-side as bcrypt hash in `refresh_tokens` table
- Access token: stored in memory only (never localStorage, never sessionStorage)
- Refresh token delivery: HttpOnly, Secure, SameSite=Strict cookie (production)
- Token revocation: refresh token revoked on logout; all tokens invalidated on OTP re-verification

### Demo Mode
- No authentication enforced
- Requests receive a synthetic demo identity only when `APP_ENV=demo`
- `X-Demo-Role` is accepted only in demo and must match the canonical role enum;
  it is ignored in production
- No OTP codes generated or emails sent in demo environment
- Demo reset is operator/systemd-only and fails closed unless `APP_ENV=demo`,
  `RUN_MODE=seed`, and `DB_NAME=padang_demo` all match

### Rate Limiting (OTP-specific)
- `/auth/request-otp`: 3 requests per email per 15 minutes per IP
- `/auth/verify-otp`: 5 failed attempts per OTP before the code is auto-invalidated; 10 attempts/min per IP
- Lockout notification: email to registered address after 5 consecutive failed verifications
- All rate-limit events logged in `audit_log`

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
| `bridge-ph-padang-demo-jwt-private-key` | RS256 private key (demo) | API container (demo) |
| `bridge-ph-padang-demo-resend-key` | Resend API key (demo) | API container (demo) |
| `bridge-ph-padang-demo-b2-key-id` | B2 application key ID (demo) | API container (demo) |
| `bridge-ph-padang-demo-b2-app-key` | B2 application key secret (demo) | API container (demo) |
| `bridge-ph-padang-prod-db-password` | Prod PostgreSQL app user password | API container (prod) |
| `bridge-ph-padang-prod-jwt-private-key` | RS256 private key (prod) | API container (prod) |
| `bridge-ph-padang-prod-resend-key` | Resend API key (prod) | API container (prod) |
| `bridge-ph-padang-prod-b2-key-id` | B2 application key ID | API container, backup container (prod) |
| `bridge-ph-padang-prod-b2-app-key` | B2 application key secret | API container, backup container (prod) |

The backup utility image also receives these B2 secrets as mounted files. It
creates only an ephemeral in-container AWS credentials file under `/run` for
the upload process; the file is never persisted or logged.

### Generation
- Database passwords: `openssl rand -base64 32`
- JWT private key: `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096`
- All piped directly into `podman secret create ... -`
- No intermediate file; no shell history exposure

See `scripts/secrets-setup.sh` for the interactive management script.

---

## Input Validation

- All request bodies validated in handler layer using go-playground/validator v10
- SQL: all queries via sqlc (parameterized; no string concatenation)
- File uploads: MIME type validated server-side (not by Content-Type header alone); file header inspected
- File size enforced at API layer (50 MB max) before B2 upload
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
Implemented in Go middleware using token bucket algorithm.
Per-IP for auth endpoints; per-user for all others.

---

## Audit Logging

- All state changes append to `audit_log` table
- All approval actions (approve/reject) logged with actor, timestamp, before/after status
- All login attempts logged (success and failure)
- Account lockouts logged
- File uploads logged (who, what file, when, to which entity)
- Export actions logged (who exported what, when)
- `audit_log` is append-only; no UPDATE or DELETE in application code
- Log retention: indefinite (table-based; B2 backup covers it)

---

## Dependency Security

- Go modules: `go mod verify` in CI
- npm: `npm audit` in CI; no known high/critical vulnerabilities at release
- Container base images: use official images; specify digest in `docs/DEPENDENCIES.md`
- Podman auto-update managed manually per constitution §13

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
| A08: Software Integrity | go.sum; package-lock.json; image auto-update via podman (digest-based) |
| A09: Logging Failures | Audit log; OTP request/verify events; structured logging; no secret in logs |
| A10: SSRF | No user-supplied URL fetching; no internal service exposure |
