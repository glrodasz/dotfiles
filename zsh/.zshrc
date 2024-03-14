# Performance profiling
#zmodload zsh/zprof

# Fig pre block
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"

# Essential Configs
export ZSH="$HOME/.oh-my-zsh"
export NVM_DIR="$HOME/.nvm"

# Optimized HOMEBREW_PREFIX Setting
if [[ "$(uname -m)" == "arm64" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
else
    export HOMEBREW_PREFIX="/usr/local"
fi

# General System Paths
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

# Pyenv and RVM Paths
export PATH="$HOME/.pyenv/bin:$PATH"
export PATH="$HOME/.rvm/bin:$PATH"

# MongoDB and additional Ruby binaries
export PATH="$PATH:/usr/local/mongodb/bin:/usr/local/opt/ruby/bin"

# Android SDK Paths
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"

# Performance and Compatibility Settings
DISABLE_AUTO_UPDATE="true"
ZSH_DISABLE_COMPFIX=true
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Plugins and source configurations
plugins=(git z)
source $ZSH/oh-my-zsh.sh
source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# macOS Specific Configurations
[[ "$(uname -s)" == "Darwin" ]] && {
  export APPLE_SSH_ADD_BEHAVIOR=macos

  # Open SSL and Kafka hotfix
  export LDFLAGS="-L/opt/homebrew/opt/openssl/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/openssl/include"
  
  # C paths for python libs to access (confluent_kafka)
  export C_INCLUDE_PATH=$C_INCLUDE_PATH:$(brew --prefix)/include
  export LIBRARY_PATH=$LIBRARY_PATH:$(brew --prefix)/lib

  # Z plugin
  . `brew --prefix`/etc/profile.d/z.sh

  alias sshadd="ssh-add -K ~/.ssh/id_rsa"
}

# Linux/WSL Specific Configurations
[[ "$(uname -s)" == "Linux" ]] && {
  PURE_PROMPT_SYMBOL=">"
  alias sshadd="ssh-add ~/.ssh/id_rsa"
}

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
alias nvmz="nvm use 20"

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
alias pyg2="pyenv global 2"
alias pyg3="pyenv global 3"

# utils aliases
alias rmorig="rm -rf **/*.orig"
alias rm="trash"
alias cl="clear"
alias cafe="cat /dev/urandom | hexdump | grep \"ca fe\""
alias sagent="eval `ssh-agent`"
alias mostused='history | awk '\''{print $2}'\'' | sort | uniq -c | sort -nr | head -n 10'

# Improve compinit performance
autoload -Uz compinit

for dump in ~/.zcompdump(N.mh+24); do
  compinit
done

compinit -C

# nvm load without use (improves terminal load speed)
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use

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

# The next line updates PATH for the Google Cloud SDK.
if [ -f "/Users/$USER/google-cloud-sdk/path.zsh.inc" ]; then . "/Users/$USER/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "/Users/$USER/google-cloud-sdk/completion.zsh.inc" ]; then . "/Users/$USER/google-cloud-sdk/completion.zsh.inc"; fi

# Load starship
eval "$(starship init zsh)"

# Load pyenv & pyenv-virtualenv 
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

[[ -f ~/machine_aliases.zsh ]] && source ~/machine_aliases.zsh

# Fig post block.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"

#zprof
