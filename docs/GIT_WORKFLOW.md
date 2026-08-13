# Git and GitHub Workflow — Padang ERP Lite

This guide is the repository workflow for local commits and GitHub updates.
The source repository is authoritative. C1 work stays on `feat/*` branches;
`main` is reserved for reviewed, stable code.

## Current remote policy

- Repository: `https://github.com/ItsAdventureTime/bridge-padang.git`
- Remote name: `origin`
- Git transport: HTTPS only
- GitHub authentication: the already-authenticated GitHub CLI (`gh`) as the
  Git credential helper
- SSH URLs, SSH keys, and passkey-based Git operations are not part of this
  workflow
- VPS deployment SSH is separate from GitHub: the demo updater connects to
  `jk@216.75.75.136:22`; GitHub updates still use the HTTPS `origin` above.

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
- the branch is not `main`;
- `origin` uses `https://github.com/...`, not an SSH URL; and
- `gh auth status` reports the intended authenticated account and HTTPS Git
  operations.

Run the checks in `docs/TESTING.md`. Application runtimes, package managers,
compilers, tests, and builds run inside Podman; Git and `gh` remain host-side
control-plane tools.

## Commit locally

Use a Conventional Commit subject:

```text
<type>[optional scope]: <description>
```

Examples:

```sh
git add docs/ backend/ frontend/ scripts/
git commit -m "fix(security): close C1 audit findings"
```

Do not stage unrelated work. Avoid `git reset --hard`, broad cleanups, or
history rewrites unless the user explicitly requests them.

## Update GitHub over HTTPS

The remote update sequence is:

```sh
gh auth status --hostname github.com
gh auth setup-git --hostname github.com
git remote set-url origin https://github.com/ItsAdventureTime/bridge-padang.git
git push origin HEAD
```

The `git push` uses the HTTPS `origin` URL and the credential helper installed
by `gh`; no SSH or alternate credential path is used. Never use `--force` on
the shared branch. If the branch is behind its remote, inspect and reconcile
the history before pushing.

Verify the remote tip through GitHub CLI without exposing credentials:

```sh
gh api repos/ItsAdventureTime/bridge-padang/branches/main \
  --jq '.name + " " + .commit.sha'
git status --short --branch
```

## Current branch consolidation

GitHub's canonical/default branch is now `main`. The histories from
`docs/phase-0` and `feat/c1-foundation` are both included in `main` at the
current release tip. Those source branches remain available for traceability;
they are not divergent from `main` and were not deleted.

For future work, commit on a `feat/*` or `docs/*` branch, review it, and merge
it into `main` before release. Confirm the result with:

```sh
gh repo view ItsAdventureTime/bridge-padang \
  --json defaultBranchRef --jq '.defaultBranchRef.name'
gh api repos/ItsAdventureTime/bridge-padang/branches/main \
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
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
