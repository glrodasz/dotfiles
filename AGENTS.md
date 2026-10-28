# AGENTS.md

Personal macOS dotfiles. Configs live here and are symlinked into `$HOME` with
`make slink-*` (e.g. `~/.zshrc` → `zsh/.zshrc`). Run `make help` for targets.

## General

- Only add config for tools that are actually in use. Don't add setup for a
  tool just because an installer added it.
- Keep changes small and in the style of the surrounding file. No unrelated
  refactors or reformatting.
- Secrets and machine-specific settings go in `~/.zshrc.local`, which is never
  tracked.

## Zsh (`zsh/.zshrc`, `zsh/.zprofile`)

Fast shell startup comes first. Every process spawned at startup costs ~25ms
on this machine because endpoint security inspects each exec.

### Comments

- Sections use the banner format:
  ```zsh
  #====================
  # Section Name
  #====================
  ```
- A simple entry gets a short label, not a sentence: `# Go path`,
  `# Rust cargo path`, `# Android SDK path`.
- Write a longer comment only when the code is not obvious, and explain *why*
  (e.g. why a cache exists, why single quotes are required). Don't describe
  what the next line plainly does.
- Aliases are grouped under a category label (`# Git`, `# Python`); each
  function has a one-line comment saying what it does.

### Patterns

- **Tool paths** go in the deferred block under "Critical Path Configuration"
  with single quotes, so `$PATH` is read when the task runs:
  ```zsh
  # Foo path
  zsh-defer -mp -c 'export PATH="$HOME/.foo/bin:$PATH"'
  ```
- **Check that it exists** when a tool may not be installed:
  `[[ -d "$HOME/.foo/bin" ]] && zsh-defer ...`, `[[ -f file ]] && ...`.
- **Defer** anything not needed for the first prompt with `zsh-defer -mp`
  (plugins, `nvm.sh`, SDK scripts, `~/.zshrc.local`).
- **Don't run commands at startup** like `eval "$(tool init zsh)"`. If the
  tool must load immediately, cache its output and regenerate only when the
  binary or its config changes (see the starship block). If an env script only
  adds a PATH entry (e.g. `~/.cargo/env`), inline the PATH entry instead of
  sourcing it.
- **Installer-appended lines**: installers (rustup, etc.) append lines to the
  end of `.zshrc`. Move them into the matching section using the patterns
  above, or remove them if the tool isn't used.

### Verify

- Syntax: `zsh -n zsh/.zshrc`
- Startup time: `for i in $(seq 1 10); do /usr/bin/time zsh -i -c exit; done`
- `zsh -i -c '...'` exits before deferred tasks run, so check deferred PATH
  entries from a real interactive shell.
