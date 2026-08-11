# ADR-005: Backblaze B2 for File Storage

**Date:** 2026-08-11  
**Status:** Accepted  
**Deciders:** Google Antigravity (Architect); confirmed by client (Bridge-PH)

## Context

The ERP stores user-uploaded files: contracts, drawings, permits, photos, inspection reports, receipts.
An external object storage is required.

## Decision

**Backblaze B2 via S3-compatible API, bucket `bridge-ph`, endpoint `s3.us-west-001.backblazeb2.com`.**

## Rationale

- Pre-approved by client (Bridge-PH); account and bucket already exist
- B2 is significantly cheaper than AWS S3 for storage + egress
- S3-compatible API allows use of AWS SDK v2 for Go — no proprietary SDK
- Existing key name: `bridge-ph-key`; credentials in Podman secrets
- Demo prefix: `bridge-ph/padang/demo/`; Production prefix: `bridge-ph/padang/`
- B2 supports: server-side encryption (SSE-B2), Object Lock, file versioning, lifecycle rules

## Consequences

- File storage is provider-specific (B2 endpoint); migration to S3 or Azure Blob would require config change (endpoint + credentials)
- Presigned URLs for download: generated server-side; 1-hour expiry
- File uploads are server-proxied (not direct client-to-B2 upload) for access control
- B2 Object Lock recommended for backup files (COMPLIANCE mode, 30 days)
- B2 file versioning recommended for the attachment prefix
