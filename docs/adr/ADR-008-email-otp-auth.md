# ADR-008: Email OTP as Production Authentication Method

**Date:** 2026-08-12  
**Status:** Accepted  
**Deciders:** Google Antigravity (Architect); client preference

## Context

The system requires authentication for the production environment. Demo is a
synthetic-data preview with no authentication and a guarded synthetic identity.

Original plan was email + password (bcrypt). The client reviewed and requested passwordless authentication.

Options evaluated:
1. Email + password (bcrypt) — original plan
2. Magic links — one-click email link
3. Email OTP (6-digit code) — enter email → receive code → enter code
4. TOTP (authenticator app) — requires device setup per user
5. Passkeys (FIDO2/WebAuthn) — best phishing resistance; requires modern device support

## Decision

**Email OTP (6-digit code, 10-minute TTL, single-use, rate-limited).**

No passwords stored anywhere. No `password_hash` column in the `users` table.

## Rationale

**Why OTP over Magic Links:**
- Magic links are vulnerable to enterprise email security scanners that pre-fetch URLs to check for malware. This can consume the magic link before the user clicks it, breaking the login flow.
- OTP codes require the user to copy/type the code — slightly more friction, but immune to link pre-fetching.
- For a small team (≤10 users) handling financial data, the slight UX friction is acceptable.

**Why OTP over Passkeys:**
- Passkey adoption requires per-device enrollment. For a team that may share devices or log in from multiple machines, this adds management overhead the client didn't want.
- Phase 2 option: add Passkey as a second factor for the DCS (CEO) role specifically.

**Why OTP over TOTP:**
- TOTP requires authenticator app setup per user — registration friction the client didn't want for Phase 1.
- Phase 2 option: add TOTP as an optional second factor.

**Why no passwords at all:**
- Eliminates the largest class of credential-based attacks (phishing, reuse, brute force).
- No password reset flow to implement, maintain, or secure.
- Simpler UX for a small internal team.

## Implementation Details

- **Code generation:** `crypto/rand` → 6-digit zero-padded string
- **Storage:** bcrypt hash in `otp_codes` table (not plaintext); deleted on first successful use
- **TTL:** 10 minutes from generation timestamp
- **Single-use:** code deleted from DB immediately after successful verification
- **Rate limiting:** 3 requests per email per 15 minutes; 5 failed verify attempts → code auto-invalidated
- **Account enumeration prevention:** identical HTTP response and timing for unknown vs known email
- **JWT issuance:** on successful OTP verification → RS256 access token (15 min) + rotating refresh token (7 days)
- **Demo:** no OTP sent and no authentication is performed; use a guarded
  synthetic identity and `X-Demo-Role` only for canonical demo role simulation

## API Endpoints

```
POST /api/v1/auth/request-otp   — body: { "email": "..." }
POST /api/v1/auth/verify-otp    — body: { "email": "...", "code": "123456" }
POST /api/v1/auth/refresh        — uses HttpOnly refresh token cookie
POST /api/v1/auth/logout         — revokes refresh token
```

## Consequences

- `users` table has no `password_hash` column
- New `otp_codes` table required (see DATABASE.md)
- Email delivery is a critical dependency for production logins — Resend must be configured and tested before go-live
- SPF/DKIM/DMARC records must be verified for the sending domain to prevent OTP emails landing in spam
- Phase 2 consideration: nonce-based CSP + optional TOTP second factor for high-privilege roles (Admin, DCS)
