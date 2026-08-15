# ADR-014: Docker Sandbox Local Release Artifacts

**Date:** 2026-08-16
**Status:** Accepted
**Deciders:** Google Antigravity (Architect); client preference

## Context

The project now has a configured Docker Sandbox as its local execution plane.
The VPS is a runtime host with rootless Podman Quadlets and should not perform
application compilation, dependency installation, or frontend assembly during a
routine demo deployment. The demo frontend also has a build-time
`/padang/demo` `basePath`, and the VPS is currently Linux/amd64.

## Decision

Build and validate the Padang demo release locally through
`jk-sbx-project exec`. The local builder uses Docker inside the sandbox, mounts
source read-only, runs the backend and frontend quality gates, cross-compiles
the API for Linux/amd64, and exports only an ignored release directory:

```text
build/padang-demo/
├── backend/padang-api
├── frontend/server.js
├── frontend/.next/static/
├── frontend/public/
└── release-manifest.txt
```

The manifest records the source revision, target OS/architecture, frontend base
path, and SHA-256 checksums for the API and standalone server. The local
deployment wrapper synchronizes source and artifacts separately. The VPS
deployment script validates the manifest/checksums and host architecture before
staging Quadlets, Caddy routing, secrets, migrations, and runtime services.

Rootless Podman remains the approved VPS runtime. It is not used for local
compilation or test execution. The previous general containerized-build
decision in ADR-009 remains historical for its time and is superseded for this
local release boundary by this ADR.

## Consequences

- A routine VPS deployment needs no Go toolchain, Node.js, npm registry access,
  or remote build container.
- The local sandbox is the reproducible release boundary and requires Docker
  image pulls for the Go and Node builder images.
- The release is currently architecture-specific (`linux/amd64`); changing VPS
  architecture requires an explicit target and runtime review.
- Artifact checksums and target metadata make the uploaded release auditable,
  while the source checkout remains the Git source of truth.
- Runtime service changes still require VPS Podman/systemd/Caddy health checks;
  a successful local build is not a public deployment proof.

## References

- [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)
- [Docker build best practices](https://docs.docker.com/build/building/best-practices/)
- [Next.js self-hosting](https://nextjs.org/docs/app/guides/self-hosting)
- [Go reproducible builds](https://go.dev/blog/rebuild)
