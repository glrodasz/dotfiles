---
name: shell-aliases-social
description: >
  Regenerate a shareable shell-aliases JSON from the user's shell config — curated,
  universally-useful aliases and functions with usage frequency from shell history.
  Use when the user wants to refresh or update their shell aliases social media JSON.
---

# Regenerate shell-aliases-social.json

Read the user's shell config and history, curate the most interesting and universally-useful aliases and functions, and write them to a shareable JSON file.

## Inputs (defaults, overridable by invocation args)

- **Shell config**: `~/.zshrc` (or the actual config, e.g. `~/dotfiles/zsh/.zshrc` if symlinked), plus `~/.zshrc.local` if present
- **History**: `~/.zsh_history` — sample the top 100 most-used commands for frequency
- **Output**: `<dotfiles repo>/zsh/shell-aliases-social.json`; if no dotfiles repo, ask where to write
- **Author**: `git config user.name` (or GitHub handle) — never hardcode

## Curate entries

Include an alias/function if it meets at least one criterion:
- Used frequently (appears often in shell history)
- Universally useful (any developer could benefit, not project-specific)
- Creative or fun (worth sharing for inspiration)

**Always skip:**
- Anything referencing private/internal domains, project IDs, service accounts, hostnames, or credentials
- Simple one-word wrappers with no added value
- Internal helper functions prefixed with `_`

## Schema

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

## Verify & report

Confirm the output is valid JSON and no sensitive information leaked into the file — the output is typically committed to a public repo. Then report a summary of what changed (added, removed, updated entries) compared to the previous version.
