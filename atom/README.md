# Install

## keymap.cson
```bash
ln -fs ~/dotfiles/atom/keymap.cson ~/.atom/keymap.cson
```

## styles.less
```bash
ln -fs ~/dotfiles/atom/styles.less ~/.atom/styles.less
```

## packages.txt

#### Backup packages
```bash
apm list --installed --bare > ~/dotfiles/atom/packages.txt
```

#### Install packages
```bash
apm install --packages-file ~/dotfiles/atom/packages.txt
```
