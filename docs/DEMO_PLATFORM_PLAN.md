# Demo platform decision and implementation handoff

Date: 2026-09-24. Target: `https://padang.delegateops.business/`.
This is the current plan for the portfolio **demo only**. Production remains on
its existing architecture. The user will start the GPT-6 Luna (High)
implementation pass manually; GPT-6 Sol (Medium) will independently review and
validate each result. The user performs the final OrbStack and Cloudflare
dashboard deployment steps.

## Decision

Finish the existing OrbStack Docker Compose deployment and route it through the
already-running Cloudflare Tunnel. Do not rewrite this Go/PostgreSQL/Next.js
application for Workers just to host a portfolio demo. The tracked
`compose.yaml`, `gateway/default.conf`, and `docs/MACOS-DOCKER-COMPOSE.md`
already describe the intended topology and manual release procedure.

Cloudflare Workers Builds **can** build and deploy a connected Worker after a
GitHub push. Git connection is configured per Worker; a repository update does
not automatically turn these Docker Compose services into Workers. Workers
Builds also supports `wrangler deploy` for Workers with Containers, but that
would require new Worker routing, container definitions, and durable database
hosting. [Workers Builds][builds] and [build configuration][build-config]
describe those steps.

| Cloudflare service | Technically possible | Fit for this repository now |
| --- | --- | --- |
| R2 | Yes. Worker binding uses the R2 Workers API; S3-compatible access uses a separate endpoint and credentials. | Optional later for attachments. The Go adapter already presigns S3 requests, but has B2-specific defaults and needs R2 endpoint/region/CORS verification. Current demo has no attachment UI. |
| D1 | Yes, through a Worker binding. D1 uses SQLite semantics. | No direct replacement for the PostgreSQL migration, `pgx`, `sqlc`, sequences, numeric types, and transaction flows in this repo. Requires a database and backend rewrite. |
| Hyperdrive | Yes, Worker binding to an existing PostgreSQL database, including a private database through Cloudflare private connectivity. | Only useful after moving database callers into a Worker. Current Go API already reaches its private Compose database. Hyperdrive does not host PostgreSQL. Disable query caching for transaction-sensitive reads if ever used. |
| KV | Yes, Worker binding. | No need in current demo. Eventual consistency makes it unsuitable as the operational database or reset store. |
| Containers | Yes, on Workers Paid. Workers Builds can build/deploy container images. | Possible for Go/Next processes, but still needs a Worker front door and external durable PostgreSQL. More moving parts and usage charges than current Compose path. |

Sources: [R2 interfaces][r2-api], [D1 SQLite API][d1],
[Hyperdrive and private databases][hyperdrive], [Hyperdrive caching][hd-cache],
[KV consistency][kv], [Containers pricing][containers], and
[Containers deploy][container-deploy]. Plan entitlements and charges must be
checked in the user's own Cloudflare account before adopting a paid service.

## Repository findings

- `frontend/next.config.mjs` compiles `basePath`; the root-hosted demo needs an
  empty `NEXT_PUBLIC_BASE_PATH` and `NEXT_PUBLIC_APP_ENV=demo` at image build
  time. Runtime Compose variables cannot change that build output.
- `backend/internal/config/config.go` reads the database password from
  `/run/secrets/db-password`. Non-secret demo settings already live in
  `compose.yaml`; there is no Compose `.env` requirement.
- `compose.yaml` runs PostgreSQL, one-shot migration and seed profiles, Go API,
  Next.js frontend, and an nginx gateway. Only the gateway joins the external
  `cloudflared-network`. No service publishes a host port.
- `gateway/default.conf` sends `/api/*` to Go and all other paths to Next.js.
  `frontend/lib/api-client.ts` uses same-origin `/api/v1/*` when basePath is
  empty.
- `backend/internal/httpapi/router.go` exposes health and a limited set of
  live register/workflow endpoints. `frontend/components/module-workspace.tsx`
  labels read-only and preview surfaces. A healthy deployment alone does not
  prove the complete ERP workflows promised by `docs/PRODUCT.md`.
- `docs/MACOS-DOCKER-COMPOSE.md` currently uses a `0700` secret directory and
  a `0644` password file so non-root containers can read its bind mount. The
  private parent restricts host traversal. Luna must verify and implement the
  narrowest working file access before the public release; do not blindly set
  `0600` and break PostgreSQL/API startup.
- The working tree had unrelated staged and unstaged changes on 2026-09-24.
  Preserve them. A clean, reviewed deployment diff is a separate deliverable.
  The public URL and live OrbStack state were not verified in this planning
  pass.

## Luna implementation pass

Use `docs/HANDOFF.md` for ownership and this file for acceptance. Use
`jk-sbx-project implement` for project builds/tests and normal edit tools for
source changes. Commit reviewed changes directly to `main`; do not create a
feature branch. Preserve the existing dirty worktree and do not discard or
commit unrelated edits.

1. Reconcile actual Compose inputs with the checkout. Keep the current
   `db`/`migrate`/`demo-seed`/`api`/`frontend`/`gateway` services and the two
   network boundary. Preserve the existing `padang_demo` data volume. Pin the
   PostgreSQL major to the schema's supported major (17) for fresh demo state;
   if a volume already exists, inspect its `PG_VERSION` before image change.
   Never auto-upgrade or wipe it.
2. Make secret handling meet the user's no-`.env` rule: non-secret values in
   `compose.yaml`; password and any later R2 keys only in external files under
   `~/docker/portfolio/padang/secrets/`. Verify host permissions and actual
   read access as the non-root API and PostgreSQL processes. Minimize file
   permission scope without breaking the runtime. No secret values in Git,
   Compose output, logs, or commands.
3. Keep manual image build/export in Docker Sandbox and image import in
   OrbStack. Update `docs/MACOS-DOCKER-COMPOSE.md` if commands or artifact
   names change. No host-side Go/Node builds; no silent fallback to host Docker.
   Keep root-host build args and the `cloudflared-network` gateway alias.
4. Close any actual startup or routing failure found by the sandbox checks.
   Tests must cover Compose structure, migration, seed, API health, root HTML,
   same-origin API data, and the blocked/unavailable behavior for unfinished
   controls. Do not label illustrative rows as live or claim complete ERP
   workflows merely because the page loads.
5. If the user's demo acceptance requires uploads, add R2 **via its S3 API**
   to the existing Go storage adapter, with bucket-scoped credentials in
   external secret files, correct endpoint/region, short-lived presigned URLs,
   and bucket CORS for this exact origin. Do not add a Worker solely to get an
   R2 binding. If uploads remain absent from the demo UI, leave R2 unbound and
   record that limitation.
6. Hand results back to Sol with changed-file list, exact commands/results,
   known gaps against `docs/PRODUCT.md`, and an updated `docs/HANDOFF.md`.
   Sol owns independent rendered/browser, security, and public route
   acceptance. User owns final live deployment and Cloudflare dashboard edits.

### Implementation stop conditions

- Existing Compose volume contains a PostgreSQL major other than the selected
  image: inspect and report; no automatic reset, downgrade, or reuse.
- Existing `cloudflared-network` or tunnel setup differs from the documented
  topology: inspect the actual network and update the plan before changing
  another homelab service.
- A secret permission change prevents required non-root processes from reading
  `/run/secrets/db-password`: restore the last working mode before proceeding.
- The intended diff includes unrelated staged/unstaged files: isolate it before
  commit or remote sync.

### Acceptance for this pass

- Sandbox checks: Compose config and `scripts/test-padang-demo-compose.py`
  pass; Go tests and frontend typecheck/lint/build pass for the root-hosted
  demo; migration and seed pass against disposable PostgreSQL 17 state.
- OrbStack checks after the user deploys: only gateway is reachable from the
  Cloudflared network; no Padang host ports; `db`, `api`, `frontend`, and
  `gateway` healthy/started; migration and seed each exit successfully once.
- Public checks after the user adds the tunnel route: `/api/v1/health` returns
  `status=ok` and `environment=demo`; `/` returns the demo shell; at least one
  live register shows seeded data; role switcher works; unfinished actions are
  visibly disabled or labeled. Full feature acceptance follows the product
  specs and is tracked separately until implemented.
- Failure behavior: a missing password, wrong database identity, absent
  network, failed migration, or failed health response stops release. Do not
  proceed to the next manual deployment step after a failed command.

### Overall demo completion gate

Deployment acceptance above is the first slice, not the end of the user's
request. The present dashboard and registers are largely read-only. After the
hosting slice, Luna must work through the relevant `docs/PRODUCT.md` and
`docs/HANDOFF.md` module tasks in reviewable slices, returning each slice to
Sol for independent validation. The final public demo must support a
synthetic-data walkthrough across project/fabrication, procurement/inventory,
approval/payment, billing/collection, reporting/export, and document upload
where those controls are shown. Every shown action must either work and
persist or be plainly marked outside demo scope; no live-looking mock action.
The document-upload slice uses R2 through the Go S3 adapter if files are part
of the walkthrough. Before claiming the demo complete, Sol tests the full
walkthrough at the public URL on desktop and mobile, tests failure/retry and
role boundaries, and records the exact remaining exclusions. If one Luna pass
cannot finish a slice, its handoff names the next concrete blocker and leaves
the overall completion gate open.

## Manual operator deployment after Luna's reviewed pass

Use the exact release commands in [the Compose runbook](MACOS-DOCKER-COMPOSE.md)
after Sol accepts Luna's changes. These are the ordered operator actions; no
automatic deployment is configured for this Compose path.

1. In OrbStack, verify Docker context `orbstack` and inspect the existing
   `cloudflared-network`. Confirm the existing `cloudflared` container is on
   it. Keep Linkwarden, Vaultwarden, and Docuseal unchanged.
2. Copy the reviewed `compose.yaml`, migrations, seed SQL, and nginx config to
   `~/docker/portfolio/padang/` using runbook Section 1. Create the external
   password file once with `umask 077`; preserve it on updates. Check directory
   and file modes plus container readability as documented by Luna. Do not
   create an `.env` file or commit the runtime directory.
3. Build/export the demo API and root-host frontend images through
   `jk-sbx-project implement`; validate Compose in the sandbox. Load both
   image archives into `docker --context orbstack` and inspect image names.
4. From the external runtime directory, run `docker --context orbstack
   compose config`, pull supporting images, start only `db`, wait for health,
   run the one-shot `migrate` profile, then run the one-shot `demo-seed`
   profile. Start `api frontend gateway` only after both jobs succeed.
5. Check `docker --context orbstack compose ps`, gateway-to-API health, and
   gateway-to-frontend root response before exposing a public hostname.
6. In Cloudflare Zero Trust, open **Networking > Tunnels**, select the
   existing healthy tunnel, add a **Published application** route for
   `padang.delegateops.business`, service URL
   `http://padang-demo-gateway:80`, with no path restriction. The dashboard
   route creates its DNS record. Do not create a second tunnel or alter the
   other homelab routes. Set a Cache Rule for this hostname to bypass cache
   for the dynamic demo. [Tunnel dashboard procedure][tunnel].
7. Run the runbook's public `curl` checks and use a browser for root, seeded
   registers, role switching, mobile layout, and API failure behavior. If a
   check fails, inspect the affected Compose service and tunnel route before
   editing DNS or resetting data. Do not run `docker compose down -v`.
8. On upgrades, take the runbook database backup and archive old images,
   then import reviewed images, run migration once, recreate app services,
   and repeat health/browser checks. Keep the old data volume and images until
   acceptance. Database rollback requires a matching backup; code rollback
   alone does not reverse schema changes.

## Optional Cloudflare-native path, if hosting requirements change

This is a migration project, not a dashboard binding exercise. First port and
check the Next.js app on the current Cloudflare-recommended vinext path; it is
still beta and needs a compatibility audit. Put the Go API in a Cloudflare
Container or rewrite it as a Worker. Keep PostgreSQL externally hosted and
connect a Worker through Hyperdrive/private connectivity, or port the schema
and repository layer to D1. Add R2 only for working uploads. Connect the
configured Worker to GitHub under **Workers & Pages > Settings > Builds**,
choose production branch and project root, verify build/deploy commands, set
runtime bindings and build-time variables separately, then test a preview
before changing the public hostname. [Next.js guide][nextjs], [Builds][builds],
and [Containers][containers] are the starting references. No part of that path
is implemented by the current `compose.yaml`.

[builds]: https://developers.cloudflare.com/workers/ci-cd/builds/
[build-config]: https://developers.cloudflare.com/workers/ci-cd/builds/configuration/
[r2-api]: https://developers.cloudflare.com/r2/api/
[d1]: https://developers.cloudflare.com/d1/worker-api/
[hyperdrive]: https://developers.cloudflare.com/hyperdrive/configuration/connect-to-private-database/
[hd-cache]: https://developers.cloudflare.com/hyperdrive/concepts/query-caching/
[kv]: https://developers.cloudflare.com/kv/concepts/how-kv-works/
[containers]: https://developers.cloudflare.com/containers/platform/pricing/
[container-deploy]: https://developers.cloudflare.com/containers/get-started/
[tunnel]: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/
[nextjs]: https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/
