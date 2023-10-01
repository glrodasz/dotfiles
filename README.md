# ~dotfiles
<img src="iterm.png" alt="iterm" width="600">

## ⏰ Install steps in a new machine

### Install Fundamental Apps
1. Install **[Chrome](https://www.google.com/chrome/)**, **[Arc](https://arc.net/)**, **[1Password](https://1password.com/downloads/mac/)** and **[Warp](https://www.warp.dev/)**
1. Install **Elgato Camera Hub**, **Elgato Control Center** and **Elgato Stream Deck** [here](https://www.elgato.com/us/en/s/downloads)
1. Install **[Logitech Options+](https://www.logitech.com/en-us/software/logi-options-plus.html)**
1. Install **[Logitech G Hub](https://www.logitechg.com/en-us/innovation/g-hub.html)**
1. Install **Purchased Apps** from **App Store**
1. Install **Downloaded Apps** following `~/dotfiles/apps`
1. Install **Visual Studio Code** and **WebStorm**

### Configure Git
1. Install **Git** through Xcode Command Line Tools `xcode-select --install`
1. Add the **SSH Keys** to the `.ssh` folder and update permissions `chmod 400 id_rsa id_rsa.pub`
1. Add **SSH key** and add it to the agent `ssh-add -K ~/.ssh/id_rsa`.
1. Set **git name** `git config --global user.name "Guillermo Rodas"`.
1. Set **git email** `git config --global user.email <email>@gmail.com`.
1. Clone **dotfiles** repository `git@github.com:glrodasz/dotfiles.git`.

### Configure Brew
1. Install **brew** `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`.
2. Run the commands to make brew available in the path.
1. Install **brew packages** from `~/dotfiles/brew`.

### Configure ZSH
> **Linux:** _Install `sudo apt install zsh` and make default zsh shell `chsh -s $(which zsh)`
1. Install **Oh My Zsh** `sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"`
1. Install **ZSH config** from `~/dotfiles/zsh`

### Configure Development Environment
1. Install **nvm** following [these instructions](https://github.com/nvm-sh/nvm#install--update-script)
1. Install **Active LTS** `nvm install --lts` and **Current** version `nvm install node`
1. Install **npm packages** from `~/dotfiles/npm`

### Install Hack and JetBrains Mono fonts
1. Install *Hack Nerd Font* and *JetBrainsMono Nerd Font* fonts from https://www.nerdfonts.com/font-downloads.

### Configure Terminal
1. Set **terminal**, **vim** config from `~/dotfiles/terminal` and `~/dotfiles/vim`

### Configure Extra options
1. Configure **Macbook** options from `~/dotfiles/mac`
### Configure WebStorm
1. Set the theme to `One Dark theme`
2. Install the plugin `Atom Material Icons`
2. Set the Editor > Font to `JetBrainsMono Nerd Font Mono` and size `24`
3. Set the Editor > Color Scheme > Console Font to `Hack Nerd Font Mono` and size `28`
4. Set the Appearance & Behaviour > Appearance to font `Inter` and size `18`.
## 🍓 Raspberry Pi OS
Follow **Configure Git**, **Configure ZSH**, **Configure Development Environment**, and **Configure Terminal** instructions and `~/dotfiles/raspberry` instructions.

## ⏳ Backup for the future
1. Follow the instructions inside each folder
1. Backup the `.env` files `find ~/Code -name .env -not -path */node_modules/**` in a USB.
1. Backup the SSH Keys `./ssh` in a USB.
1. Commit lastest changes in `~/dotfiles` and push them.
