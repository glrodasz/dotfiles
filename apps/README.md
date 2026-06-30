# Apps

Installed applications backup from `~/dotfiles/apps`.

## Backup

Dependency (one-time):

```bash
brew install newt  # Required for whiptail (interactive selection)
```

```bash
make backup-apps
```

Opens an interactive checklist where you can:
- Use arrow keys to navigate
- Space to select/deselect applications
- Enter to confirm your selection

Updates `installed-apps.json` with your selection.
