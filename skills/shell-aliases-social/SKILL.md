---
name: shell-aliases-social
description: >
  Regenerate a shareable shell-aliases JSON from the user's shell config — curated,
  universally-useful aliases and functions with usage frequency from shell history. Use
  when the user runs /shell-aliases-social, optionally with paths that override the
  defaults — to refresh, update, regenerate, share, or export their shell aliases as the
  shell aliases social media JSON (aliases JSON), a shareable list of their zsh aliases
  and functions.
disable-model-invocation: true
---

# Shell Aliases Social JSON

Read the user's shell config and history, curate the most interesting and
universally-useful aliases and functions, and write them to a shareable JSON file.
Nothing private (internal hosts, project IDs, credentials) reaches the file — it is
committed to a public repo.

## Inputs

Defaults; each is overridable by invocation args.

- **Shell config**: `~/.zshrc` (or the actual config, e.g. `~/dotfiles/zsh/.zshrc` if
  symlinked), plus `~/.zshrc.local` if present
- **History**: `~/.zsh_history` — rank the top 100 most-used commands for frequency.
  This strips zsh's extended-history prefix (`: <time>:<duration>;`):

  ```bash
  LC_ALL=C sed -E 's/^: [0-9]+:[0-9]+;//' ~/.zsh_history | awk '{print $1}' \
    | sort | uniq -c | sort -rn | head -100
  ```
- **Output**: `<dotfiles repo>/zsh/shell-aliases-social.json`; if no dotfiles repo, ask
  where to write
- **Author**: `git config user.name` (or GitHub handle) — never hardcode

## Phase 1 — Curate entries

Include an alias/function if it meets at least one criterion:
- Used frequently (appears often in shell history)
- Universally useful (any developer could benefit, not project-specific)
- Creative or fun (worth sharing for inspiration)

**Always skip:**
- Anything referencing private/internal domains, project IDs, service accounts,
  hostnames, or credentials
- Simple one-word wrappers with no added value
- Internal helper functions prefixed with `_`

## Phase 2 — Write the JSON

```json
{
  "meta": {
    "author": "<from git config>",
    "source": "~/.zshrc",
    "generated": "YYYY-MM-DD"
  },
  "entries": [
    {
      "name": "string",
      "type": "alias | function",
      "category": "git | dev | cleanup | utility | fun",
      "command": "string (actual shell definition, abbreviated if long)",
      "description": "short human-readable tagline",
      "usage_frequency": "high | medium | low"
    }
  ]
}
```

- `usage_frequency` comes from the history ranking: `high` = top 10, `medium` = ranks
  11–50, `low` = ranks 51–100 or not ranked but kept for being useful or fun.
- Sort `entries` by category in the order above (git, dev, cleanup, utility, fun), then
  by `name`, so regenerating gives a stable diff.

## Phase 3 — Verify

1. Valid JSON: `python3 -m json.tool <output> >/dev/null`.
2. No sensitive information leaked into the file — the output is typically committed to a
   public repo. Remove any leaked entry and re-check until both pass.

## Report

Compare against the committed version (`git -C <dotfiles repo> diff -- <output>`) and
print:

```
## Shell aliases social — <date>

### Added
- <entry name — why it qualified>

### Removed
- <entry name — why it was dropped>

### Updated
- <entry name — what changed: command, description, or frequency>
```
