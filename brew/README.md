# Install

### Dependencies
```bash
brew install newt  # Required for whiptail (interactive selection)
```

### Manage Brew Packages
First, make the script executable:
```bash
chmod +x update-brew-packages.sh
```

Then run it:
```bash
./update-brew-packages.sh
```

This will open an interactive checklist where you can:
- Use arrow keys to navigate
- Space to select/deselect packages
- Enter to confirm your selection

After selecting the packages, the script will update the `packages` file with your selection.

### Install Packages
To install all packages from your backup:
```bash
cat ~/dotfiles/brew/packages | xargs brew install
```
