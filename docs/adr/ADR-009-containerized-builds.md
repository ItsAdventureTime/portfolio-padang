# ADR-009: Containerized Build Strategy (Historical)

**Date:** 2026-08-12  
**Status:** Superseded by ADR-014 for local release builds
**Deciders:** Google Antigravity (Architect); client preference

> Historical note: this ADR records the earlier disposable-Podman build plan.
> The current local execution and release boundary is the Docker Sandbox and
> is defined by ADR-014. Rootless Podman remains the VPS runtime.

## Context

The VPS host (Fedora CoreOS, rootless Podman) should not have Go, Node.js, or any application build toolchain installed directly. The client requires that all compilation, transpilation, and build steps happen inside containers.

## Decision

**All builds, compilation, and code generation happen inside `podman run --rm` containers. The VPS host has no application build toolchain.**

## Build Image Strategy

| Task | Command pattern |
|---|---|
| Compile Go binary | `podman run --rm -v ./backend:/app:Z -w /app docker.io/library/golang:alpine go build -o dist/api ./cmd/api/` |
| Build Next.js | `podman run --rm -v ./frontend:/app:Z -w /app docker.io/library/node:lts-alpine sh -c "npm ci && npm run build"` |
| Run sqlc | `podman run --rm -v ./backend:/app:Z -w /app docker.io/sqlc/sqlc generate` |
| Run migrations (local) | `podman run --rm -v ./backend/migrations:/migrations:Z docker.io/library/postgres:17-alpine ... ` |
| Run tests (Go) | `podman run --rm -v ./backend:/app:Z -w /app docker.io/library/golang:alpine go test ./...` |

## OCI Image Approach for Deployable Images

Production images use **multi-stage Containerfiles**:

**Go API Containerfile:**
```dockerfile
# Stage 1: Build
FROM docker.io/library/golang:alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /api ./cmd/api/

# Stage 2: Runtime
FROM docker.io/library/alpine:latest
RUN adduser -D -u 1001 api
COPY --from=builder /api /usr/local/bin/api
USER api
ENTRYPOINT ["/usr/local/bin/api"]
```

**Next.js Frontend Containerfile:**
```dockerfile
# Stage 1: Dependencies
FROM docker.io/library/node:lts-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production

# Stage 2: Build
FROM docker.io/library/node:lts-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Stage 3: Runtime
FROM docker.io/library/node:lts-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -g 1001 nodejs && adduser -S nextjs -u 1001
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

## Image Tags in Containerfiles and Quadlets

Build and stateless runtime image tags are **mutable — no version numbers
pinned**. Persistent PostgreSQL is the explicit major-version exception:
- `golang:alpine` — latest stable Go with Alpine
- `node:lts-alpine` — latest active LTS Node.js with Alpine
- `alpine:latest` — latest Alpine for final runtime stage
- `postgres:17-alpine` for clean demo state; existing persistent state uses the
  matching supported `PG_VERSION` major and never changes major implicitly

Quadlet `.container` files intentionally omit `AutoUpdate=registry`. Image tags
remain floating, but the application update wrapper performs reviewed builds,
manual image refreshes, and controlled service restarts. The
`podman-auto-update.timer` must remain disabled.

## Benefits

- No build toolchain on VPS host — smaller host attack surface
- `--rm` flag: build containers cleaned up automatically after use; no `podman system prune` needed
- Multi-stage Containerfiles: final runtime images contain only the compiled artifact + Alpine base
- Reproducible: same build environment regardless of host OS state

## Consequences

- CI/CD (GitHub Actions) must also use the same containerized build approach
- Local development can use the same `podman run --rm` commands or native toolchain for iteration speed (developer choice)
- Build times slightly longer than native, but acceptable for a small team deploying infrequently
- Go binary must be built with `CGO_ENABLED=0` for Alpine compatibility (no glibc)
