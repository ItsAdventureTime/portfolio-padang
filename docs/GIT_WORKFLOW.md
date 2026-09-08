# Git and GitHub Workflow — Padang ERP Lite

This guide is the repository workflow for every source, configuration, script,
UI/UX, and documentation revision. The source repository is authoritative.
Every completed change must update affected guides, pass the applicable
validation gates, receive a GitHub-verified commit, and synchronize through the
authenticated HTTPS GitHub workflow below.

## Normative post-change sequence

After every update, revision, or modification:

1. Update the affected documentation and guides. Update `docs/HANDOFF.md` when
   behavior, release status, branch state, or deployment guidance changes.
2. Run the applicable runtimes, package managers, builds, tests, and scanners
   through the deterministic Docker Sandbox with `jk-sbx-project exec` or
   `jk-sbx-project run`. Do not run local project workloads through Podman or
   directly on macOS.
3. Review `git diff --check`, the intended file list, and the current branch.
4. Verify GitHub authentication and an HTTPS `origin` before committing.
5. Create the reviewed commit through GitHub's `createCommitOnBranch` GraphQL
   mutation with the exact expected remote head; GitHub signs the commit when
   the account supports server-side signing.
6. Verify the remote commit and tree with `gh api`, then fetch and synchronize
   local refs through the authenticated HTTPS credential helper.

A documentation-only change still follows this sequence, with only the
validation gates relevant to documentation. Stop if GitHub authentication is
unavailable; do not create or print credentials.

## Current remote policy

- Repository: `https://github.com/ItsAdventureTime/portfolio-padang.git`
- Remote name: `origin`
- Git transport: HTTPS only
- GitHub authentication: the already-authenticated GitHub CLI (`gh`) as the
  Git credential helper
- Commit signatures: required; create commits through GitHub's
  `createCommitOnBranch` mutation and verify the resulting GitHub signature
- SSH URLs, SSH keys, and passkey-based Git operations are not part of this
  Git transport workflow
- VPS deployment SSH is separate from GitHub: the demo updater connects to
  `jk@216.75.75.136:22`; GitHub updates still use the HTTPS `origin` above.

## Deployment build boundary

> **Current demo override (2026-09-07):** The active demo is built/exported
> through `jk-sbx-project` and deployed manually with OrbStack Docker Compose.
> Follow `docs/MACOS-DOCKER-COMPOSE.md`; the VPS/Quadlet flow below remains
> production/reference guidance.

The Padang demo updater builds locally before it opens the VPS deployment
connection. `scripts/build-padang-demo-local.sh` runs through
`jk-sbx-project exec`, creates the ignored `build/padang-demo/` Linux/amd64
release, and writes a checksum-backed release manifest. The wrapper uploads
that artifact directory separately from the source tree. The VPS script only
validates/stages the release and activates its rootless Podman runtime; it does
not run Go or Node compilation. `scripts/update-padang-demo.sh --dry-run`
therefore exercises both local artifact generation and remote artifact
validation without changing runtime services.

GitHub supports HTTPS and SSH remote URLs. This project selects HTTPS, and
GitHub CLI's `gh auth setup-git --hostname github.com` configures Git to use
the CLI credential helper for the authenticated host. Do not print or copy
the token returned by any credential command.

## Before committing

```sh
git status --short --branch
git branch --show-current
git remote -v
gh auth status --hostname github.com
```

Confirm that:

- the worktree contains only intended changes;
- the branch is appropriate for the task; direct `main` updates require the
  explicit user-authorized maintenance workflow and a completed review;
- `origin` uses `https://github.com/...`, not an SSH URL; and
- `gh auth status` reports the intended authenticated account and HTTPS Git
  operations.

Run the checks in `docs/TESTING.md`. Application runtimes, package managers,
compilers, tests, and builds run inside the Docker Sandbox; Git, `gh`, and
sandbox lifecycle commands remain host-side control-plane tools. Podman is
reserved for the remote Fedora CoreOS deployment runtime.

## Prepare the reviewed tree

Use a Conventional Commit subject:

```text
<type>[optional scope]: <description>
```

Examples:

```sh
git diff --cached --check
```

The GraphQL input must contain the intended file additions, each with a
repository-relative path and base64-encoded contents, plus a Conventional
Commit headline and the exact remote `expectedHeadOid`. Do not include
unrelated work. Avoid `git reset --hard`, broad cleanups, or history rewrites
unless the user explicitly requests them.

Create the remote commit through the authenticated GitHub CLI:

```sh
gh api graphql --input /path/to/create-commit.json
```

The mutation uses `branch.repositoryNameWithOwner`, `branch.branchName`,
`expectedHeadOid`, `fileChanges.additions[].path`,
`fileChanges.additions[].contents`, and `message.headline`. Record the returned
commit OID and verify its signature and tree before synchronizing local refs.

```sh
gh api repos/ItsAdventureTime/portfolio-padang/commits/<oid> \
  --jq '.sha + " verified=" + (.commit.verification.verified|tostring)'
```

## Update GitHub over HTTPS

The remote update sequence is:

```sh
gh auth status --hostname github.com
gh auth setup-git --hostname github.com
git remote set-url origin https://github.com/ItsAdventureTime/portfolio-padang.git
git fetch origin main
```

The fetch uses the HTTPS `origin` URL and the credential helper installed by
`gh`; no SSH or alternate credential path is used. Advance only the local ref
with a compare-and-swap update that preserves existing staged and unstaged user
changes while reconciling index entries affected by the new commit. Never use
`--force` on the shared branch. If the branch changed after the exact head
check, stop and reconcile the history before creating another commit.

Verify the remote tip through GitHub CLI without exposing credentials:

```sh
gh api repos/ItsAdventureTime/portfolio-padang/branches/main \
  --jq '.name + " " + .commit.sha'
gh api repos/ItsAdventureTime/portfolio-padang/commits/HEAD \
  --jq '.sha + " verified=" + (.commit.verification.verified|tostring)'
git status --short --branch
```

The GitHub API verification result must report `verified=true` for a signed
commit. `gh auth setup-git` authenticates the HTTPS transport; it does not
create the commit, while `createCommitOnBranch` creates and signs it when
GitHub server-side signing is supported.

## Current branch consolidation

GitHub's canonical/default branch is now `main`. The histories from
`docs/phase-0` and `feat/c1-foundation` are both included in `main` at the
current release tip. Those source branches remain available for traceability;
they are not divergent from `main` and were not deleted.

For future work, commit on a `feat/*` or `docs/*` branch, review it, and merge
it into `main` before release. Confirm the result with:

```sh
gh repo view ItsAdventureTime/portfolio-padang \
  --json defaultBranchRef --jq '.defaultBranchRef.name'
gh api repos/ItsAdventureTime/portfolio-padang/branches/main \
  --jq '.name + " " + .commit.sha'
```

Create a pull request only when the review workflow calls for one:

```sh
gh pr create --base main --head feat/c1-foundation \
  --title "fix(security): close C1 audit findings" \
  --body-file /path/to/review-notes.md
```

Deployment is separate from a branch push and remains governed by
`docs/HANDOFF.md` and `docs/DEPLOYMENT.md`.

## References

- [GitHub CLI `gh auth setup-git`](https://cli.github.com/manual/gh_auth_setup-git)
- [GitHub remote repository and HTTPS URL guidance](https://docs.github.com/en/get-started/git-basics/about-remote-repositories)
- [GitHub GraphQL `createCommitOnBranch`](https://docs.github.com/en/graphql/reference/commits#createcommitonbranch)
- [GitHub GraphQL `CommittableBranch`](https://docs.github.com/en/graphql/reference/git#committablebranch)
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
