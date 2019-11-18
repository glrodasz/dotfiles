# zmodload zsh/zprof

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Plugins
plugins=(git)

# oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Alias
alias gmasu="gcm && g fetch upstream && g reset --hard upstream/master && ggpush -f --no-verify"
alias gmaso="gcm && g fetch origin && g reset --hard origin/master"
alias nvmx="nvm use 10"

alias npmd="npm run dev"
alias npms="npm start"

alias rmnpmi="rm -rf node_modules && npm cache clean --force && npm i"
alias rmyarn="rm -rf node_modules && yarn cache clean && yarn"
alias rmpack="rm -rf node_modules && rm -rf packages/**/node_modules && yarn --force"

alias rmorig="rm -rf **/*.orig"
alias rm="trash"

alias sshadd="ssh-add -K ~/.ssh/id_rsa"
alias rundb="run-rs --mongod /usr/local/bin/mongod --keep --dbpath ~/.data/mongodb"
alias nocors="open --new -a 'Google Chrome' --args --disable-web-security --allow-running-insecure-content --user-data-dir=/tmp/$USER --test-type"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use # This loads nvm

# Custom scripts
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Z plugin
. `brew --prefix`/etc/profile.d/z.sh

# PATH
export PATH="~/.pyenv/shims:$PATH"
export PATH="$PATH:$HOME/.rvm/bin"
export PATH="$PATH:/usr/local/sbin"
export PATH="$PATH:/usr/local/mongodb/bin"
export PATH="$PATH:$HOME/miniconda3/bin"
export PATH="$PATH:`yarn global bin`"
export PATH="/usr/local/opt/mysql@5.7/bin:$PATH"
export PATH="/usr/local/opt/ruby/bin:$PATH"

export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# pyenv
eval "$(pyenv init -)"

# Read Markdownn
markdown () {
   pandoc $1 | lynx -stdin
}

# Fix hub alias
git() { hub $@; }

# Fuzzy branch
fbr() {
  git fetch
  local branches branch
  branches=$(git branch -a) &&
  branch=$(echo "$branches" | fzf +s +m -e) &&
  git checkout $(echo "$branch" | sed "s:.* remotes/origin/::" | sed "s:.* ::")
}

# Load pure
autoload -U promptinit; promptinit
prompt pure

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/glrodasz/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/glrodasz/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/glrodasz/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/glrodasz/google-cloud-sdk/completion.zsh.inc'; fi

# zprof
