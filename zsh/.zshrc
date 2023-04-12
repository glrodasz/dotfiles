# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"
# zmodload zsh/zprof

# Prompt Symbol for WSL
# [[ "$(uname -s)" == "Linux" ]] && PURE_PROMPT_SYMBOL=">"

# Disable auto update for performance
DISABLE_AUTO_UPDATE="true"

# Disable warnings
ZSH_DISABLE_COMPFIX=true

# Disable ssh-add warnings
export APPLE_SSH_ADD_BEHAVIOR=macos

# Oh My Zsh path
export ZSH=$HOME/.oh-my-zsh

# Plugins
plugins=(git zsh-z zsh-syntax-highlighting)

# Oh My Zsh load
source $ZSH/oh-my-zsh.sh

# Git aliases
alias gmasu="gcm && g fetch upstream && g reset --hard upstream/main && gfp"
alias gmaso="gcm && g fetch origin && g reset --hard origin/main"
alias gaem="g commit --allow-empty -m"
alias grmum='git rebase -i $(git merge-base HEAD upstream/main)'
alias grmom='git rebase -i $(git merge-base HEAD origin/main)'
alias grreb='git reset HEAD~1'

# nvm aliases
alias nvmu="nvm use"
alias nvmx="nvm use 16"
alias nvmy="nvm use 18"
alias nvmz="nvm use 19"

# npm and yarn aliases
alias npmd="npm run dev"
alias npms="npm start"
alias yarnd="yarn run dev"
alias yarns="yarn start"

# node_modules aliases
alias rmnpmi="rm -rf node_modules && npm cache clean --force && npm i"
alias rmyarn="rm -rf node_modules && yarn cache clean && yarn --force"
alias rmmodules="find . -name node_modules -type d -prune -exec rm -rf '{}' +"

# pyenv aliases
alias pyg2="pyenv global 2.7.18"
alias pyg3="pyenv global 3.11.3"

# utils aliases
alias rmorig="rm -rf **/*.orig"
alias rm="trash"
alias cl="clear"
alias cafe="cat /dev/urandom | hexdump | grep \"ca fe\""
[[ "$(uname -s)" == "Darwin" ]] && alias sshadd="ssh-add -K ~/.ssh/id_rsa" || alias sshadd="ssh-add ~/.ssh/id_rsa" 
alias sagent="eval `ssh-agent`"
alias nocors="open --new -a 'Google Chrome' --args --disable-web-security --allow-running-insecure-content --user-data-dir=/tmp/$USER --test-type"
alias simu="open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
alias mostused='history | awk '\''{print $2}'\'' | sort | uniq -c | sort -nr | head -n 10'

# Improve compinit performance
autoload -Uz compinit

for dump in ~/.zcompdump(N.mh+24); do
  compinit
done

compinit -C

# nvm path
export NVM_DIR="$HOME/.nvm"

# nvm load without use (improves terminal load speed)
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use

# Z plugin
[[ "$(uname -s)" == "Darwin" ]] && . `brew --prefix`/etc/profile.d/z.sh

# General path
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="/usr/local/bin:$PATH"
export PATH="$PATH:$HOME/.rvm/bin"
export PATH="$PATH:/usr/local/sbin"
export PATH="$PATH:/usr/local/mongodb/bin"
export PATH="$PATH:/usr/local/opt/ruby/bin"

# Android path
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/tools"
export PATH="$PATH:$ANDROID_HOME/tools/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

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
# fpath+=$HOME/.zsh/pure

# autoload -U promptinit; promptinit

# prompt pure

# The next line updates PATH for the Google Cloud SDK.
if [ -f "/Users/$USER/google-cloud-sdk/path.zsh.inc" ]; then . "/Users/$USER/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "/Users/$USER/google-cloud-sdk/completion.zsh.inc" ]; then . "/Users/$USER/google-cloud-sdk/completion.zsh.inc"; fi

# Open SSL and Kafka hotfix
[[ "$(uname -s)" == "Darwin" ]] && export LDFLAGS="-L/opt/homebrew/opt/openssl/lib"
[[ "$(uname -s)" == "Darwin" ]] && export CPPFLAGS="-I/opt/homebrew/opt/openssl/include"

# C paths for python libs to access (confluent_kafka)
[[ "$(uname -s)" == "Darwin" ]] && export C_INCLUDE_PATH=$C_INCLUDE_PATH:$(brew --prefix)/include
[[ "$(uname -s)" == "Darwin" ]] && export LIBRARY_PATH=$LIBRARY_PATH:$(brew --prefix)/lib

# grpcio 
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1

# Load starship
eval "$(starship init zsh)"

# zprof

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"
