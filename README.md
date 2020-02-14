# dotfiles

## Install

1. Install **Chrome**, **Visual Studio Code**, **WebStorm** and **iTerm**.
2. Install **Logitech Options** `https://www.logitech.com/en-roeu/product/options`.
3. Install **Aerial Screensaver** from `https://github.com/JohnCoates/Aerial`.
4. Install **purchased apps** from **App Store**.
5. Install **downloaded apps** following `~/dotfiles/apps`.
6. Add **SSH key** and add it to the agent `shh-add -K ~/id_rsa`.
7. Set Git identity name `git config --global user.name "Guillermo Rodas"`.
8. Set Git identity email `git config --global user.email glrodasz@gmail.com`.
9. Clone **dotfiles** repository `git@github.com:glrodasz/dotfiles.git`.
10. Install **brew** `/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`.
11. Install **brew packages** from `~/dotfiles/brew`.
12. Set **zsh shell** as default with `chsh -s /bin/zsh`.
13. Install **Oh My Zsh** `sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"`
14. Install **nvm** `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash`
15. Install **LTS** and **current** versions
16. Add aliases `prev` for LTS and `curr` for current version.
17. Install **npm packages** from `~/dotfiles/npm`
18. Install **Pure** from `npm install --global pure-prompt`
19. Set **zsh**, **iTerm**, **terminal**, **vim** config from `~/dotfiles/zsh`, `~/dotfiles/iterm`, `~/dotfiles/terminal` and `~/dotfiles/vim`
20. Configure **Macbook** options from `~/dotfiles/mac`

## Backup

1. Follow the instructions inside each folder
2. Backup the .env files `find ~/Code -name .env -not -path */node_modules/**`
