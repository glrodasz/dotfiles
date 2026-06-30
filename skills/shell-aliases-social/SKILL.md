---
name: shell-aliases-social
description: Regenerate ~/dotfiles/zsh/shell-aliases-social.json from the current ~/.zshrc — curated, universally-useful aliases and functions with usage frequency from shell history. Use when the user wants to refresh or update their shell aliases social media JSON.
---

# Regenerate shell-aliases-social.json

Read the current shell config and history, curate the most interesting and universally-useful aliases and functions, and overwrite `~/dotfiles/zsh/shell-aliases-social.json`.

## Steps

1. **Read sources**
   - `~/dotfiles/zsh/.zshrc` — main aliases and functions
   - `~/.zshrc.local` — any local additions
   - `~/.zsh_history` — for usage frequency (sample top 100 most-used commands)

2. **Curate entries** — include an alias/function if it meets at least one criterion:
   - Used frequently (appears often in shell history)
   - Universally useful (any developer could benefit, not project-specific)
   - Creative or fun (worth sharing for inspiration)

   **Always skip:**
   - Company-specific helpers (references to internal domains, project IDs, service accounts)
   - Simple one-word wrappers with no added value
   - Internal helper functions prefixed with `_`

3. **Write** `~/dotfiles/zsh/shell-aliases-social.json` using this schema:

```json
{
  "meta": {
    "author": "guillermo.rodas",
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

4. **Verify** — confirm the output is valid JSON and no sensitive information leaked into the file.

## Output

Overwrite `~/dotfiles/zsh/shell-aliases-social.json` and report a summary of what changed (added, removed, or updated entries) compared to the previous version.
