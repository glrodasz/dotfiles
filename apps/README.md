# Install

### Dependencies
```bash
brew install newt  # Required for whiptail (interactive selection)
```

### installed-apps
First, make the script executable:
```bash
chmod +x update-installed-apps.sh
```
Then run it:
```bash
./update-installed-apps.sh
```

This will open an interactive checklist where you can:
- Use arrow keys to navigate
- Space to select/deselect applications
- Enter to confirm your selection

After selecting the applications, the script will update the `installed-apps` file with the selected applications.
