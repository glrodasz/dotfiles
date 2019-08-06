# dotfiles

## Install

1. Install **Chrome**, **Visual Studio Code**, and **iTerm**.
2. Install Logitech Options `https://www.logitech.com/en-roeu/product/options`.
3. Install **Aerial Screensaver** from `https://github.com/JohnCoates/Aerial`.
5. Install **purchased apps** from **App Store**.
6. Install **downloaded apps** following `~/dotfiles/apps`.
7. Add **SSH key** and add it to the agent `shh-add -K ~/id_rsa`.
8. Set Git identity name `git config --global user.name "Guillermo Rodas"`.
9. Set Git identity email `git config --global user.email glrodasz@gmail.com`.
10. Clone **dotfiles** repository `git@github.com:glrodasz/dotfiles.git`.
11. Install **brew** `/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`.
12. Install **brew packages** from `~/dotfiles/brew`.
13. Set **zsh shell** as default with `chsh -s /bin/zsh`.
14. Install **Oh My Zsh** `sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"`
15. Install **nvm** `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash`
16. Install **LTS** and **current** versions
17. Add aliases `prev` for LTS and `curr` for current version.
18. Install **npm packages** from `~/dotfiles/npm`
19. Install **Pure** from `npm install --global pure-prompt`
20. Set **zsh**, **iTerm**, **terminal**, **vim** config from `~/dotfiles/zsh`, `~/dotfiles/iterm`, `~/dotfiles/terminal` and `~/dotfiles/vim`
21. Install **Adobe Illustrator**, and **Adobe Photoshop** `https://www.adobe.com/creativecloud/desktop-app.html`
22. Configure **Macbook** options from `~/dotfiles/mac`

## Backup

1. Follow the instructions inside each folder
2. Backup the .env files `find ~/Code -name .env -not -path */node_modules/**`
