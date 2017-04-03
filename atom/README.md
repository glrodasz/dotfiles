# Install

## keymap.cson
```bash
ln -fs ~/dotfiles/atom/keymap.cson ~/.atom/keymap.cson
```
## packages-list.txt

#### Backup packages list
```bash
apm list --installed --bare > ~/dotfiles/atom/packages-list.txt
```

#### Install packages list
```bash
apm install --packages-file ~/dotfiles/atom/packages-list.txt
```
