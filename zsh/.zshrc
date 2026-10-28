# Tabulador pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/tab/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/tab/shell/zshrc.pre.zsh"
#====================
# Initialization
#====================

# How to profile zsh
# for i in $(seq 1 10); do /usr/bin/time zsh -i -c exit; done

source ~/.zsh-defer/zsh-defer.plugin.zsh

#====================
# Core Environment & Prompt
#====================
export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
export NVM_DIR="$HOME/.nvm"
export PNPM_HOME="$HOME/Library/pnpm"

# Performance and Compatibility Settings
DISABLE_AUTO_UPDATE="true"
ZSH_DISABLE_COMPFIX=true
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Prompt initialization (needs to be immediate). `starship init` is cached and
# regenerated only when the starship binary (e.g. `brew upgrade`) or its config
# changes. PROMPT2 is resolved at cache time too, since the stock init script
# spawns `starship prompt --continuation` on every startup.
STARSHIP_INIT_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/starship/init.zsh"
() {
    local bin=${commands[starship]:A} config=${STARSHIP_CONFIG:-$HOME/.config/starship.toml}
    [[ -n "$bin" ]] || return 1
    local -a mtimes init
    zmodload -F zsh/stat b:zstat
    zstat -A mtimes +mtime -- $bin $config(N)
    local key="# $bin ${mtimes[*]}" cached_key
    [[ -r "$STARSHIP_INIT_CACHE" ]] && read -r cached_key < "$STARSHIP_INIT_CACHE"
    [[ "$cached_key" == "$key" ]] && return
    init=("${(@f)$(starship init zsh --print-full-init)}")
    mkdir -p "${STARSHIP_INIT_CACHE:h}"
    {
        print -r -- "$key"
        print -rl -- "${(@)init:#PROMPT2=*}"
        print -r -- "PROMPT2=${(q)$(starship prompt --continuation)}"
    } >| "$STARSHIP_INIT_CACHE"
} && source "$STARSHIP_INIT_CACHE"

#====================
# Critical Path Configuration
#====================
# System Paths (including $HOME/.local/bin for user-specific scripts) (needed immediately)
export PATH="/usr/local/bin:/usr/local/sbin:$HOME/.local/bin:$PATH"

# pnpm
export PATH="$PNPM_HOME:$PATH"

# pyenv
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
[[ -d "$PYENV_ROOT/shims" ]] && export PATH="$PYENV_ROOT/shims:$PATH"

# Dynamic Python Version for Google Cloud SDK
() {
    local version=system
    [[ -r "$PYENV_ROOT/version" ]] && read -r version < "$PYENV_ROOT/version"
    local -a pythons=($PYENV_ROOT/versions/${version}*/bin/python3(N-.nOn))
    CLOUDSDK_PYTHON=$pythons[1]
}

# Deferred tool paths. Single quotes are required: zsh-defer -c evals the
# string when the task runs, so $PATH and the *_HOME variables are read live
# instead of being frozen at startup (which made each line overwrite the last).

# Go path (binaries from `go install`, e.g. golines, golangci-lint, gotestsum)
zsh-defer -mp -c 'export GOPATH="$HOME/go"; export PATH="$GOPATH/bin:$PATH"'

# Ruby-related Paths (RVM and additional Ruby binaries)
zsh-defer -mp -c 'export PATH="$HOME/.rvm/bin:/usr/local/opt/ruby/bin:$PATH"'

# MongoDB path
zsh-defer -mp -c 'export PATH="$PATH:/usr/local/mongodb/bin"'

# Android SDK path
zsh-defer -mp -c 'export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"'

# Java OpenJDK path
zsh-defer -mp -c 'export JAVA_HOME="/opt/homebrew/opt/openjdk@21"; export PATH="/opt/homebrew/bin/java:$PATH"'

# Antigravity path
zsh-defer -mp -c 'export PATH="$HOME/.antigravity/antigravity/bin:$PATH"'

# Rust cargo path
[[ -d "$HOME/.cargo/bin" ]] && zsh-defer -mp -c 'export PATH="$HOME/.cargo/bin:$PATH"'

#====================
# OS-Specific Config
#====================
# Optimized HOMEBREW_PREFIX Setting | checks for ARM vs Intel
if [[ "$CPUTYPE" == "arm64" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
else
    export HOMEBREW_PREFIX="/usr/local"
fi

# macOS
[[ "$OSTYPE" == darwin* ]] && {
    export APPLE_SSH_ADD_BEHAVIOR=macos

    # Open SSL and Kafka hotfix
    zsh-defer -mp export LDFLAGS="-L/opt/homebrew/opt/openssl/lib"
    zsh-defer -mp export CPPFLAGS="-I/opt/homebrew/opt/openssl/include"

    # C paths for python libs to access (confluent_kafka)
    zsh-defer -mp export C_INCLUDE_PATH=$C_INCLUDE_PATH:$HOMEBREW_PREFIX/include
    zsh-defer -mp export LIBRARY_PATH=$LIBRARY_PATH:$HOMEBREW_PREFIX/lib

    # Z plugin
    zsh-defer -mp . $HOMEBREW_PREFIX/etc/profile.d/z.sh
    
    # SSH Agent alias (Including loading resident keys from FIDO authenticator)
    [[ -f ~/.ssh/id_rsa ]] && ID_RSA_OPT="-K ~/.ssh/id_rsa"
    [[ -f ~/.ssh/id_ed25519 ]] && ID_ED25519_OPT="-K ~/.ssh/id_ed25519"
    alias sshadd="ssh-add ${ID_RSA_OPT:-} ${ID_ED25519_OPT:-}"
}

# Linux/WSL
[[ "$OSTYPE" == linux* ]] && {
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
        zsh-defer -mp source "$ZSH_CUSTOM/plugins/$plugin/$plugin.plugin.zsh"
    done
}

#====================
# Plugins & Shell
#====================
# Docker CLI and Homebrew completions (added before compinit so it picks them up).
# Homebrew's is also added by .zprofile; repeating it here covers non-login shells.
fpath=("$HOME/.docker/completions"(N/) "$HOMEBREW_PREFIX/share/zsh/site-functions"(N/) $fpath)

# Oh My Zsh, loaded directly instead of through oh-my-zsh.sh: its startup checks
# spawn ~10 processes, ~25ms each here because endpoint security inspects every
# exec. Same libs, git plugin and custom configs, so `omz` commands keep working.
plugins=(git)
ZSH_CACHE_DIR="$ZSH/cache"
ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"
fpath=("$ZSH/plugins/git" "$ZSH_CACHE_DIR/completions" $ZSH/{functions,completions} $ZSH_CUSTOM/{functions,completions} $fpath)
# Nested shells inherit the exported FPATH, so drop duplicates to keep fpath
# identical across shells (and the completion dump from being rebuilt)
typeset -U fpath

# Rebuild the completion dump only when fpath changed or one of its directories
# gained or lost a file since the last build; otherwise load it without a rescan.
autoload -Uz compinit
() {
    local fpath_line="#fpath: $fpath"
    local -a changed=(${^fpath}(N/e:'[[ $REPLY -nt $ZSH_COMPDUMP ]]':))
    if [[ -s "$ZSH_COMPDUMP" ]] && (( ! $#changed )) &&
        [[ ${${(f)"$(<$ZSH_COMPDUMP)"}[-1]} == "$fpath_line" ]]; then
        compinit -C -d "$ZSH_COMPDUMP"
    else
        zmodload -F zsh/files b:zf_rm
        zf_rm -f "$ZSH_COMPDUMP"
        compinit -u -d "$ZSH_COMPDUMP"
        print -r -- "$fpath_line" >> "$ZSH_COMPDUMP"
        zcompile "$ZSH_COMPDUMP"
    fi
}

for lib_file ("$ZSH"/lib/*.zsh) source "$lib_file"
source "$ZSH/plugins/git/git.plugin.zsh"
for config_file ("$ZSH_CUSTOM"/*.zsh(N)) source "$config_file"
unset lib_file config_file

# Set completion colors to be the same as `ls`
[[ -z "$LS_COLORS" ]] || zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Defer additional plugins
load_omz_plugins_with_defer z poetry
zsh-defer -mp source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#====================
# Aliases
#====================
# Git
alias gaem="g commit --allow-empty -m"
alias gwip='g commit --all -m "chore: work in progress" -n'
alias gwin='g add -A && g commit -m "chore: commit changes"'
alias greb='git rebase -i $(git merge-base HEAD origin/main)'
alias gfresh="gcm && g fetch && ggpull"
alias grvscode="git restore .vscode/settings.json"

# Node Version Manager
alias nvmu="nvm use"
alias nvmx="nvm use 22"
alias nvmy="nvm use 24"
alias nvmz="nvm use 25"

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
alias rmyarn="rm -rf node_modules && yarn cache clean && yarn --check-cache"
alias rmmodules="find . -name node_modules -type d -prune -exec rm -rf '{}' +"

# Python
alias py2="pyenv global 2"
alias py3="pyenv global 3"
alias pyinit="source .venv/bin/activate"

# System Utils
alias rmorig="rm -rf **/*.orig"
alias rm="trash"
alias cl="clear"
alias cafe="cat /dev/urandom | hexdump | grep \"ca fe\""
alias sagent='eval "$(ssh-agent)"'
alias mostused='history | awk '\''{print $2}'\'' | sort | uniq -c | sort -nr | head -n 10'
alias secret="openssl rand -hex 32"

#====================
# Functions
#====================
# Ignore local .vscode/settings.json changes
givscode() {
    local exclude
    exclude=$(git rev-parse --git-path info/exclude 2>/dev/null) || return 1
    git update-index --assume-unchanged .vscode/settings.json
    mkdir -p "${exclude:h}"
    grep -qxF '.vscode/settings.json' "$exclude" 2>/dev/null ||
        echo '.vscode/settings.json' >> "$exclude"
}

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

# Kill all processes listening on given port(s)
killport() {
    for port in "$@"; do
        local pids=$(sudo lsof -t -n -i :$port)
        if [[ -n "$pids" ]]; then
            echo "Killing processes on port $port: $pids"
            echo "$pids" | xargs kill -9
        else
            echo "No processes found on port $port"
        fi
    done
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
zsh-defer -mp . "$NVM_DIR/nvm.sh" --no-use
zsh-defer -mp . "$HOME/.deno/env"

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then 
    zsh-defer -mp source "$HOME/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
    zsh-defer -mp source "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

#====================
# Local Config
#====================
# .zshrc.local for secrets and machine-specific configurations
# This file should NOT be tracked in git.
[[ -f ~/.zshrc.local ]] && zsh-defer -mp source ~/.zshrc.local

# Tabulador post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/tab/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/tab/shell/zshrc.post.zsh"
