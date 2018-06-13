# Install

## Backup packages
```bash
brew leaves > ~/dotfiles/brew/packages
```

## Install packages
```bash
cat ~/dotfiles/brew/packages | xargs brew install
```
