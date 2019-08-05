# zmodload zsh/zprof

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Plugins
plugins=(git)

# oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Alias
alias gmas="gcm && g fetch upstream && g reset --hard upstream/master && ggpush -f --no-verify"

alias npmd="npm run dev"
alias npms="npm start"

alias rmnpmi="rm -rf node_modules && rm -f package-lock.json && npm cache clean --force && npm i"
alias rmyarn="rm -rf node_modules && rm -f yarn.lock && yarn cache clean && yarn"

alias bumpp="npm version patch"
alias bumpi="npm version minor"
alias bumpa="npm version major"

alias rmorig="rm -rf **/*.orig"
alias rm="trash"

alias sshadd="ssh-add -K ~/.ssh/id_rsa"
alias rundb="run-rs --mongod /usr/local/bin/mongod --keep --dbpath ~/.data/mongodb"

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

# pyenv
eval "$(pyenv init -)"

# Read Markdownn
markdown () {
   pandoc $1 | lynx -stdin
}

# Fix hub alias
function git() { hub $@; }

# Load pure
autoload -U promptinit; promptinit
prompt pure

# zprof
