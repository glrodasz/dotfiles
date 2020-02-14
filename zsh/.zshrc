# zmodload zsh/zprof

# Oh My Zsh path
export ZSH=$HOME/.oh-my-zsh

# Plugins
plugins=(git)

# Oh My Zsh load
source $ZSH/oh-my-zsh.sh

# Git aliases
alias gmasu="gcm && g fetch upstream && g reset --hard upstream/master && ggpush -f"
alias gmaso="gcm && g fetch origin && g reset --hard origin/master"
alias gaem="g commit --allow-empty -m"

# nvm aliases
alias nvmix="nvm use 9"
alias nvmx="nvm use 10"

# npm and yarn aliases
alias npmd="npm run dev"
alias npms="npm start"
alias yarnd="yarn run dev"
alias yarns="yarn start"

# node_modules aliases
alias rmnpmi="rm -rf node_modules && npm cache clean --force && npm i"
alias rmyarn="rm -rf node_modules && yarn cache clean && yarn"
alias rmpack="rm -rf node_modules && rm -rf packages/**/node_modules && yarn --force"
alias yarncr="yarn clean-repo"

# utils aliases
alias rmorig="rm -rf **/*.orig"
alias rm="trash"
alias cl="clear"
alias cafe="cat /dev/urandom | hexdump | grep \"ca fe\""
alias sshadd="ssh-add -K ~/.ssh/id_rsa"
alias rundb="run-rs --mongod "$(which mongod)" --keep --dbpath ~/.data/mongodb"
alias nocors="open --new -a 'Google Chrome' --args --disable-web-security --allow-running-insecure-content --user-data-dir=/tmp/$USER --test-type"
alias simu="open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"

# nvm path
export NVM_DIR="$HOME/.nvm"

# nvm load without use (Improves terminal load speed)
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use

# Syntax Highlighting
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Z plugin
. `brew --prefix`/etc/profile.d/z.sh

# General path
export PATH="$PATH:`yarn global bin`"
export PATH="$PATH:$HOME/.pyenv/shims"
export PATH="$PATH:$HOME/.rvm/bin"
export PATH="$PATH:$HOME/miniconda3/bin"
export PATH="$PATH:/usr/local/sbin"
export PATH="$PATH:/usr/local/mongodb/bin"
export PATH="$PATH:/usr/local/opt/mysql@5.7/bin"
export PATH="$PATH:/usr/local/opt/ruby/bin"

# Android path
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/tools"
export PATH="$PATH:$ANDROID_HOME/tools/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

# pyenv load
eval "$(pyenv init -)"

# direnv load
eval "$(direnv hook $SHELL 2>/dev/null)" || exit 1

# Read markdown
markdown () {
   pandoc $1 | lynx -stdin
}

# Fix hub alias
git() { hub $@; }

# Fuzzy search branch
fbr() {
  git fetch
  local branches branch
  branches=$(git branch -a) &&
  branch=$(echo "$branches" | fzf +s +m -e) &&
  git checkout $(echo "$branch" | sed "s:.* remotes/origin/::" | sed "s:.* ::")
}

# Find a process given a port
findport() {
  sudo lsof -n -i :$1 | egrep "LISTEN|PID"
}

# Find a process given a name
findproc() {
  ps -fa | egrep "$1|PID"
}

# Load pure
autoload -U promptinit; promptinit
prompt pure

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/glrodasz/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/glrodasz/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/glrodasz/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/glrodasz/google-cloud-sdk/completion.zsh.inc'; fi

# zprof
