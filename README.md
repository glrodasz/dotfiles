# dotfiles

## Install
1. Install Chrome, VS Code, iTerm
2. Install Logitech Options (Mouse drivers)
3. Install Aerial Screensaver from https://github.com/JohnCoates/Aerial
4. Install apps from App Store
5. Install `installed-apps.txt` from `~/dotfiles/apps`
5. Add SSH key and add it to the agent `shh-add -K ~/id_rsa_rioth`
6. Set Git identity
 ```bash
 git config --global user.name "Guillermo Rodas"
 git config --global user.email glrodasz@gmail.com
 ```
7. Clone dotfiles repository `git@github.com:glrodasz/dotfiles.git`
8. Install brew
```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
9. Install brew package from `~/dotfiles/brew`
9. Set ZSH shell as default with `chsh -s /bin/zsh`
10. Install Oh My Zsh
```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
```
11. Set ZSH, iTerm, Terminal, Vim config `~/dotfiles/zsh`, `~/dotfiles/iterm`, `~/dotfiles/terminal` and `~/dotfiles/vim`
12. Install nvm and then install LTS and lastest version.
14. Install Pure from `npm install --global pure-prompt`.
15. Install npm packages from ~/dotfiles/npm.
16. Install downloaded-apps-list.txt from ~/dotfiles/apps.
18. Install Adobe Illustrator, Photoshop.
19. Configure Macbook options from ~/dotfiles/mac.
20. Install miniconda3 (Optional).

## Backup
1. Follow the instructions inside each folder
3. Backup the .env files `find ~/Code -name .env -not -path */node_modules/**`
