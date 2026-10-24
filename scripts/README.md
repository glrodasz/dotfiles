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
