# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# Performance profiling
#zmodload zsh/zprof

# Essential Configs
export ZSH="$HOME/.oh-my-zsh"
export NVM_DIR="$HOME/.nvm"

# Optimized HOMEBREW_PREFIX Setting
if [[ "$(uname -m)" == "arm64" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
else
    export HOMEBREW_PREFIX="/usr/local"
fi

# General System Paths including $HOME/.local/bin for user-specific scripts and tools
export PATH="/usr/local/bin:/usr/local/sbin:$HOME/.local/bin:$PATH"

# Python-related Paths (Pyenv)
export PATH="$HOME/.pyenv/bin:$PATH"

# Ruby-related Paths (RVM and additional Ruby binaries)
export PATH="$HOME/.rvm/bin:/usr/local/opt/ruby/bin:$PATH"

# MongoDB path
export PATH="$PATH:/usr/local/mongodb/bin"

# Performance and Compatibility Settings
DISABLE_AUTO_UPDATE="true"
ZSH_DISABLE_COMPFIX=true
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Plugins and source configurations
plugins=(git z poetry)
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
alias gaem="g commit --allow-empty -m"

# nvm aliases
alias nvmx="nvm use 16"
alias nvmy="nvm use 20"
alias nvmz="nvm use 22"

# npm, yarn and deno aliases
alias npmd="npm run dev"
alias npms="npm start"
alias yarnd="yarn dev"
alias yarns="yarn start"
alias denod="deno run dev"
alias denos="deno run start"

# node_modules aliases
alias rmnpmi="rm -rf node_modules && npm cache clean --force && npm i"
alias rmyarn="rm -rf node_modules && yarn cache clean && yarn --force"
alias rmmodules="find . -name node_modules -type d -prune -exec rm -rf '{}' +"

# pyenv aliases
alias py2="pyenv global 2"
alias py3="pyenv global 3"

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

# Load deno
. "/Users/$USER/.deno/env"

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

# Get a lucky message 
lucky() {
    local cow=$(cowsay -l | tail -n +2 | tr ' ' '\n' | shuf -n 1)
    fortune | cowsay -f $cow | lolcat --seed 0 --spread 1.0
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

#zprof

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
