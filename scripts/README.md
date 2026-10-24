# Scripts

Standalone utility scripts from `~/dotfiles/scripts`.

## GitHub audit

Inventories every repo (public and private) of a GitHub user or org for a portfolio audit.

Dependencies:

```bash
brew install gh jq
gh auth login  # Needs access to private repos
```

```bash
./scripts/github-audit.sh [owner] [since]
```

- `owner` — GitHub user or org (defaults to the user logged in to `gh`)
- `since` — only repos pushed since this date get the detailed report (defaults to 5 years ago)

Writes to `scripts/github-audit/`:
- `repos.json` — metadata of all repos
- `details.md` — structure, latest commits and README of each non-fork repo active since `since`

> The output includes private repo data and is git-ignored. Do not commit it.

## Harden repos

Applies a baseline of safe contribution settings to your GitHub repos: a ruleset protecting the default branch, squash-only merging, Dependabot, a read-only `GITHUB_TOKEN` and more. The profile is picked per repo from its visibility.

Dependencies:

```bash
brew install gh jq
gh auth login  # As the repo owner
```

```bash
./scripts/harden-repos.sh [flags] [repo...]
```

- `--dry-run` — preview the changes without applying them
- `--private` / `--private=light` — also include private repos, with the light profile (for solo repos)
- `--private=strict` — also include private repos, with the full profile (for repos with collaborators)
- `--keep-classic` — don't delete the classic branch protection rule on the default branch
- `-h`, `--help` — show the full usage
- `repo...` — only these repos (defaults to every non-fork, non-archived repo of the owner)
- `OWNER` env var — GitHub user or org (defaults to `glrodasz`)

Without `--private`, private repos are skipped.

| Setting | public | strict | light |
|---|:-:|:-:|:-:|
| Ruleset: PR + 1 approval, code owners, conversation resolution, linear history (admins can bypass) | ✓ | ✓ | - |
| Ruleset: block force push + deletion | ✓ | ✓ | ✓ (no bypass) |
| Squash-only merging, auto-delete branches | ✓ | ✓ | - |
| Dependabot alerts + security updates | ✓ | ✓ | ✓ |
| Read-only `GITHUB_TOKEN`, Actions can't approve PRs | ✓ | ✓ | ✓ |
| Private vulnerability reporting | ✓ | - | - |
| Secret scanning + push protection | ✓ | - | - |
| Fork PR workflows need approval | ✓ | - | - |
| Delete classic rule on default branch | ✓ | ✓ | - |

```bash
./scripts/harden-repos.sh --dry-run                      # preview, public repos
./scripts/harden-repos.sh                                # apply to public repos
./scripts/harden-repos.sh --private=strict my-team-repo  # specific repos only
```

> The classic rule is deleted only after the ruleset applies successfully. Wildcard classic rules are reported, never deleted. Rulesets (and classic protection) on private repos need GitHub Pro (personal) or Team (org); on Free that step is skipped, the rest still applies, and the unprotected repos are listed at the end.
