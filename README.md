# ~dotfiles
<img src="iterm.png" alt="iterm" width="600">

## ⏰ Install steps in a new machine

### Install Fundamental Apps
1. Install **[Chrome](https://www.google.com/chrome/)**, **[1Password](https://1password.com/downloads/mac/)**, and **[iTerm](https://iterm2.com/)**
1. Install **Elgato Camera Hub**, **Elgato Control Center**, **Elgato Stream Deck**, and **Game Capture HD** from [here](https://www.elgato.com/us/en/s/downloads)
1. Install **[Logitech Options+](https://www.logitech.com/en-us/software/logi-options-plus.html)**
1. Install **[Logitech G Hub](https://www.logitechg.com/en-us/innovation/g-hub.html)**
1. Install **Purchased Apps** from **App Store**
1. Install **Downloaded Apps** following `~/dotfiles/apps`
1. Install **[Visual Studio Code](https://code.visualstudio.com/Download)** and **[WebStorm](https://www.jetbrains.com/webstorm/download/#section=mac)**

### Configure Git
> (If not available) Install **Git** through Xcode Command Line Tools `xcode-select --install`
1. Add the **SSH Keys** to the `.ssh` folder and update permissions `chmod 400 id_rsa id_rsa.pub`
1. Add **SSH key** and add it to the agent `ssh-add -K ~/.ssh/id_rsa`.
1. Set **git name** `git config --global user.name "Guillermo Rodas"`.
1. Set **git email** `git config --global user.email "<email>@gmail.com"`.
1. Clone **dotfiles** repository `git@github.com:glrodasz/dotfiles.git`.

### Configure ZSH
> **Linux:** install `sudo apt install zsh` and make default zsh shell `chsh -s $(which zsh)`
1. Install **Oh My Zsh** `sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"`
1. Install **ZSH config** from `~/dotfiles/zsh`

### Configure Brew
1. Install **brew** `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`.
2. Run the commands to make brew available in the path.
1. Install **brew packages** from `~/dotfiles/brew`.

### Configure Development Environment
1. Install **nvm** following [these instructions](https://github.com/nvm-sh/nvm#install--update-script)
1. Install **Active LTS** `nvm install --lts` and **Current** version `nvm install node`
1. Install **npm packages** from `~/dotfiles/npm`

### Install Hack and JetBrains Mono fonts
1. Install **Hack Nerd Font** and **JetBrainsMono Nerd Font** fonts from https://www.nerdfonts.com/font-downloads.

### Configure Terminals and Vim
1. Set **terminals** config from `~/dotfiles/terminal/*`
2.  Set **vim** config from `~/dotfiles/vim`

### Configure Extra options
1. Configure **Macbook** options from `~/dotfiles/mac`

### Configure Editors
1. Configure **Visual Studio Code** from `~/dotfiles/editors/vscode`
2. Configure **WebStorm** from `~/dotfiles/editors/webstorm`

## 🍓 Raspberry Pi OS
Follow **Configure Git**, **Configure ZSH**, **Configure Development Environment**, and **Configure Terminal** instructions and `~/dotfiles/raspberry` instructions.

## ⏳ Backup for the future
1. Follow the instructions inside each folder
1. Backup the `.env` files `find ~/Code -name .env -not -path */node_modules/**` in a USB.
1. Backup the SSH Keys `./ssh` in a USB.
1. Commit lastest changes in `~/dotfiles` and push them.
