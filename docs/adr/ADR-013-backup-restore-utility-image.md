# ADR-013: Dedicated Database and File Backup Utility

**Date:** 2026-08-12
**Status:** Accepted clarification
**Deciders:** Google Antigravity (Architect); Bridge-PH requirements

## Context

The previous backup example selected a PostgreSQL image but invoked a storage
client that was not present in the image. The PostgreSQL image provides
`pg_dump`; it does not provide the client needed for Backblaze B2's
S3-compatible endpoint.

## Decision

Build and publish a dedicated `ghcr.io/itsadventuretime/padang-erp-backup:latest`
utility image containing:

- PostgreSQL client tools compatible with the selected database major;
- rclone configured with the S3 backend's `provider=Other` and the explicit
  Backblaze B2 endpoint;
- the repository backup, checksum, manifest, retention, and restore helpers.

The one-shot production backup service mounts only Podman secrets and joins
only the production internal network. It streams the custom-format database
dump to Backblaze B2, copies attachment objects to the dated backup prefix,
writes checksums/manifests, and verifies the uploaded objects. No plaintext
secret or dump is committed to Git or written to a persistent local deployment
path.

The restore test always uses an isolated throwaway database/container and
never the production database.

## Consequences

- backup tools are versioned and tested together;
- the runtime API image remains minimal;
- a backup image build is added to TASK-009;
- B2 credentials require least privilege over production and backup prefixes;
- the backup/restore quality gate must include database rows and attachment
  object checksums.
