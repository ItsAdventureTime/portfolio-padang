# Git and GitHub Workflow Rules

## Use `gh` CLI for all GitHub operations

The `gh` CLI is the only tool authorised for GitHub interaction on this project.
It is already authenticated via HTTPS — no SSH, no SSH keys, no passkeys ever.

### Remote configuration
- URL format: `https://github.com/ItsAdventureTime/bridge-padang.git` (HTTPS only)
- Never configure a remote with the SSH format `git@github.com:...`

### Command guidance
- `git add`, `git status`, `git log`, `git diff` — standard git, fine to use
- `git commit --no-gpg-sign` — always include `--no-gpg-sign`; 1Password is configured as the
  commit-signing provider on this machine and times out in non-interactive / background execution
- `git push` — works because `gh auth` configures the HTTPS credential helper automatically;
  alternatively use `gh repo sync` for syncing forks
- Repo creation, PRs, releases, issue management — always use `gh` commands
- Never use `git remote set-url` to switch to SSH

### 1Password signing issue
Running `git commit` without `--no-gpg-sign` in a background or automated context will fail with:
> 1Password: failed to write commit object

Always pass `--no-gpg-sign` to avoid blocking on the 1Password prompt.
