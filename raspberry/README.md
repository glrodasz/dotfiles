# Install

## Install packages
`sudo apt install yarn nvm hub xscreensaver xfce4-terminal`

## Install Hack font
1. Download *Hack* fonts from https://sourcefoundry.org/hack/
1. Create a local fonts directory `mkdir -p ~/.local/share/fonts`
1. Copy fonts `cp ~/Downloads/ttf/*ttf ~/.local/share/fonts/`
1. Refresh fonts cache `fc-cache -f -v`

## Install pure-prompt
Follow the manual instructions:
```bash
mkdir -p "$HOME/.zsh"
git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
```

## Install zsh-z
Follow the oh-my-zsh instructions
`git clone https://github.com/agkozak/zsh-z $ZSH_CUSTOM/plugins/zsh-z`