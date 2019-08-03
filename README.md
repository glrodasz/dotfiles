# dotfiles

## Install
1. Install Chrome, VS Code, iTerm
2. Install Logitech Options (Mouse drivers)
3. Install Aerial Screensaver from https://github.com/JohnCoates/Aerial
4. Install apps from App Store
5. Install `installed-apps.txt` from `~/dotfiles/apps`
6. Add SSH key and add it to the agent `shh-add -K ~/id_rsa_rioth`
7. Set Git identity
 ```bash
 git config --global user.name "Guillermo Rodas"
 git config --global user.email glrodasz@gmail.com
 ```
8. Clone dotfiles repository `git@github.com:glrodasz/dotfiles.git`
9. Install brew
```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
10. Install brew package from `~/dotfiles/brew`
11. Set ZSH shell as default with `chsh -s /bin/zsh`
12. Install Oh My Zsh
```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
```
13. Set ZSH, iTerm, Terminal, Vim config from `~/dotfiles/zsh`, `~/dotfiles/iterm`, `~/dotfiles/terminal` and `~/dotfiles/vim`
14. Install nvm and then install LTS and lastest version.
15. Install Pure from `npm install --global pure-prompt`.
16. Install npm packages from ~/dotfiles/npm.
17. Install downloaded-apps-list.txt from ~/dotfiles/apps.
18. Install Adobe Illustrator, Photoshop.
19. Configure Macbook options from ~/dotfiles/mac.
20. Install miniconda3 (Optional).

## Backup
1. Follow the instructions inside each folder
2. Backup the .env files `find ~/Code -name .env -not -path */node_modules/**`
