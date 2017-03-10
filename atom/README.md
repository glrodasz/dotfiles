# Install

## keymap.cson
```bash
ln -fs ~/dotfiles/atom/keymap.cson ~/.atom/keymap.cson
```
## package-list.txt

#### Backup package list
```bash
apm list --installed --bare > ~/dotfiles/atom/package-list.txt
```

#### Install package list
```bash
apm install --packages-file ~/dotfiles/atom/package-list.txt
```
