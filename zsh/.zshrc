#====================
# Initialization
#====================

# How to profile zsh
# for i in $(seq 1 10); do /usr/bin/time zsh -i -c exit; done

# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

source ~/.zsh-defer/zsh-defer.plugin.zsh

#====================
# Core Environment & Prompt
#====================
export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
export NVM_DIR="$HOME/.nvm"

# Performance and Compatibility Settings
DISABLE_AUTO_UPDATE="true"
ZSH_DISABLE_COMPFIX=true
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Dynamic Python Version for Google Cloud SDK
CLOUDSDK_PYTHON=$(pyenv which python3 2>/dev/null)

# Prompt initialization (needs to be immediate)
eval "$(starship init zsh)"

#====================
# Critical Path Configuration
#====================
# System Paths (including $HOME/.local/bin for user-specific scripts) (needed immediately)
export PATH="/usr/local/bin:/usr/local/sbin:$HOME/.local/bin:$PATH"

# Python-related Paths (Pyenv)
zsh-defer export PATH="$HOME/.pyenv/bin:$PATH"

# Ruby-related Paths (RVM and additional Ruby binaries)
zsh-defer export PATH="$HOME/.rvm/bin:/usr/local/opt/ruby/bin:$PATH"

# MongoDB path
zsh-defer export PATH="$PATH:/usr/local/mongodb/bin"

# Android SDK path
zsh-defer export ANDROID_HOME=$HOME/Library/Android/sdk
zsh-defer export PATH="$PATH:$ANDROID_HOME/emulator"
zsh-defer export PATH="$PATH:$ANDROID_HOME/platform-tools"

# Java OpenJDK path
zsh-defer export PATH="/opt/homebrew/bin/java:$PATH"
zsh-defer export JAVA_HOME="/opt/homebrew/opt/openjdk@21"

# Antigravity path
zsh-defer export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

#====================
# OS-Specific Config
#====================
# Optimized HOMEBREW_PREFIX Setting | checks for ARM vs Intel
if [[ "$(uname -m)" == "arm64" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
else
    export HOMEBREW_PREFIX="/usr/local"
fi

# macOS
[[ "$(uname -s)" == "Darwin" ]] && {
    export APPLE_SSH_ADD_BEHAVIOR=macos

    # Open SSL and Kafka hotfix
    zsh-defer export LDFLAGS="-L/opt/homebrew/opt/openssl/lib"
    zsh-defer export CPPFLAGS="-I/opt/homebrew/opt/openssl/include"

    # C paths for python libs to access (confluent_kafka)
    zsh-defer export C_INCLUDE_PATH=$C_INCLUDE_PATH:$HOMEBREW_PREFIX/include
    zsh-defer export LIBRARY_PATH=$LIBRARY_PATH:$HOMEBREW_PREFIX/lib

    # Z plugin
    zsh-defer . $HOMEBREW_PREFIX/etc/profile.d/z.sh
    
    # SSH Agent alias (Including loading resident keys from FIDO authenticator)
    [[ -f ~/.ssh/id_rsa ]] && ID_RSA_OPT="-K ~/.ssh/id_rsa"
    [[ -f ~/.ssh/id_ed25519 ]] && ID_ED25519_OPT="-K ~/.ssh/id_ed25519"
    alias sshadd="ssh-add ${ID_RSA_OPT:-} ${ID_ED25519_OPT:-}"
}

# Linux/WSL
[[ "$(uname -s)" == "Linux" ]] && {
    PURE_PROMPT_SYMBOL=">"
    
    # SSH Agent alias
    [[ -f ~/.ssh/id_rsa ]] && ID_RSA_OPT="~/.ssh/id_rsa"
    [[ -f ~/.ssh/id_ed25519 ]] && ID_ED25519_OPT="~/.ssh/id_ed25519"
    alias sshadd="ssh-add ${ID_RSA_OPT:-} ${ID_ED25519_OPT:-}"
}

# Load Oh My Zsh custom plugins with defer
load_omz_plugins_with_defer() {
    local plugin
    for plugin in "$@"; do
        zsh-defer source "$ZSH_CUSTOM/plugins/$plugin/$plugin.plugin.zsh"
    done
}

#====================
# Plugins & Shell
#====================
# Essential plugins and evalcache for immediate eval commands
plugins=(git evalcache)
source $ZSH/oh-my-zsh.sh

# Defer additional plugins
load_omz_plugins_with_defer z poetry
zsh-defer source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#====================
# Aliases
#====================
# Git
alias gaem="g commit --allow-empty -m"
alias gwip='g commit --all -m "chore: work in progress" -n'
alias gwin='g add -A && g commit -m "chore: commit changes"'
alias greb='git rebase -i $(git merge-base HEAD origin/main)'

# Node Version Manager
alias nvmu="nvm use"
alias nvmx="nvm use 16"
alias nvmy="nvm use 20"
alias nvmz="nvm use 22"

# Package Managers
alias npmd="npm run dev"
alias npms="npm start"
alias yarnd="yarn dev"
alias yarns="yarn start"
alias pnpmd="pnpm run dev"
alias pnpms="pnpm start"
alias denod="deno run dev"
alias denos="deno run start"

# Cleanup
alias rmnpmi="rm -rf node_modules && npm cache clean --force && npm i"
alias rmyarn="rm -rf node_modules && yarn cache clean && yarn --force"
alias rmmodules="find . -name node_modules -type d -prune -exec rm -rf '{}' +"

# Python
alias py2="pyenv global 2"
alias py3="pyenv global 3"

# System Utils
alias rmorig="rm -rf **/*.orig"
alias rm="trash"
alias cl="clear"
alias cafe="cat /dev/urandom | hexdump | grep \"ca fe\""
alias sagent="eval `ssh-agent`"
alias mostused='history | awk '\''{print $2}'\'' | sort | uniq -c | sort -nr | head -n 10'

#====================
# Functions
#====================
# Git branch fuzzy finder
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

# List GitHub repository tags
_github_tags() {
    local repo=$1
    local count=${2:-5}
    local per_page=$((count > 100 ? 100 : count))
    local page=1
    local results=""
    local result_count=0
    
    while [ $result_count -lt $count ]; do
        local page_results=$(curl -s "https://api.github.com/repos/$repo/tags?per_page=$per_page&page=$page" \
          | jq -r "map(select(.name)) | .[].name")
        
        if [ -z "$page_results" ]; then
            break
        fi
        
        local lines=$(echo "$page_results" | wc -l | tr -d ' ')
        if [ $lines -eq 0 ]; then
            break
        fi
        
        results="$results$page_results"$'\n'
        result_count=$((result_count + lines))
        page=$((page + 1))
        
        if [ $page -gt 10 ]; then
            break
        fi
    done
    
    echo "$results" | head -n $count
}

# List Python versions
pythonver() {
    _github_tags "python/cpython" "$@"
}

# List Node versions
nodever() {
    _github_tags "nodejs/node" "$@"
}

# Get a lucky message
lucky() {
    local cow=$(cowsay -l | tail -n +2 | tr ' ' '\n' | shuf -n 1)
    fortune | cowsay -f $cow | lolcat --seed 0 --spread 1.0
}

# Testing packages installation :)
busy() {
    while true; do
        if [ -f package.json ]; then
            packages=($(jq -r 'to_entries[] | select(.key | test("dependencies|devDependencies")) | .value | to_entries[] | .key' package.json))
        else
            packages=("react" "react-dom" "styled-components" "react-router-dom" "formik" "date-fns" "eslint" "prettier" "webpack" "babel" "typescript")
        fi

        for pkg in "${packages[@]}"; do
            echo -e "\033[1;32m> \033[0m \033[1mInstalling\033[0m $pkg..."
            sleep 0.$((RANDOM % 5))${RANDOM:0:1}
            echo -e "\033[1;34m> \033[0m \033[1mDownloading metadata for $pkg..."
            sleep 1.$((RANDOM % 5))

            progress=0
            while [ $progress -lt 100 ]; do
                increment=$((RANDOM % 20 + 5))
                progress=$((progress + increment))
                if [ $progress -gt 100 ]; then progress=100; fi
                bar_length=20
                filled=$((progress * bar_length / 100))
                bar=$(printf "%0.s=" $(seq 1 $filled))
                echo -ne "\033[1;36mProgress: [${bar}] ${progress}%\033[0m\033[K\r"
                sleep 0.$((RANDOM % 3))
            done

            echo -e ""
            echo -e "\033[1;33m> \033[0m \033[1mBuilding\033[0m $pkg..."
            sleep 0.$((RANDOM % 9))
        done
    done
}

#====================
# Deferred Initializations
#====================
# Development Tools
zsh-defer . "$NVM_DIR/nvm.sh" --no-use
zsh-defer . "$HOME/.deno/env"

# Combine defer + evalcache for expensive operations
zsh-defer _evalcache pyenv init -
zsh-defer _evalcache pyenv virtualenv-init -

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then 
    zsh-defer _evalcache source "$HOME/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
    zsh-defer _evalcache source "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

# Docker CLI completions
if [ -d "$HOME/.docker/completions" ]; then
    zsh-defer eval 'fpath=($HOME/.docker/completions $fpath); autoload -Uz compinit; compinit'
fi

#====================
# Local Config
#====================
# .zshrc.local for secrets and machine-specific configurations
# This file should NOT be tracked in git.
[[ -f ~/.zshrc.local ]] && zsh-defer source ~/.zshrc.local

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
