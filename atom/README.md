# Install

## keymap.cson
```bash
ln -fs ~/Code/dotfiles/atom/keymap.cson ~/.atom/keymap.cson
```
## package-list.txt

### Backup package list
```bash
apm list --installed --bare > ~/Code/dotfiles/atom/package-list.txt
```

### Install package list
```bash
apm install --packages-file ~/Code/dotfiles/atom/package-list.txt
```
