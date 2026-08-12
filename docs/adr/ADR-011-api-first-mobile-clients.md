# ADR-011: API-First Web and Mobile Client Strategy

**Date:** 2026-08-12
**Status:** Accepted clarification
**Deciders:** Google Antigravity (Architect); Bridge-PH requirements

## Context

The product must remain one system and support future iOS and Android clients.
Browser cookies are appropriate for the web refresh flow, but native clients
need OS-backed secure storage.

## Decision

The Go REST API and OpenAPI 3.1 contract are the shared product boundary.
Next.js remains the web client. Future mobile clients use TypeScript with
Expo/React Native and share generated API types, validation schemas, role
identifiers, error envelopes, and domain calculations through repository
packages.

The authentication protocol is shared but storage is platform-specific:

- web: in-memory access token plus HttpOnly, Secure, SameSite refresh cookie;
- mobile: in-memory access token plus Keychain/Keystore-backed refresh storage;
- both: rotating refresh tokens, revocation, expiry, and server-side hashing.

No mobile client trusts a client-supplied role. Authorization remains enforced
by the API.

## Consequences

- one backend and one business-rule implementation;
- shared contracts reduce web/mobile drift;
- web and native UI components remain platform-appropriate;
- mobile implementation is deferred until the web product is stable;
- mobile security review must include the current OWASP mobile/thick-client
  guidance when that work begins.
