# Brew

Homebrew package backup from `~/dotfiles/brew`.

## Install

```bash
make install-brew
```

Installs all packages listed in `packages`.

## Backup

Dependency (one-time):

```bash
brew install newt  # Required for whiptail (interactive selection)
```

```bash
make backup-brew
```

Opens an interactive checklist where you can:
- Use arrow keys to navigate
- Space to select/deselect packages
- Enter to confirm your selection

Updates `packages` with your selection.
