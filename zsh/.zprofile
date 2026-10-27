# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh"

# Homebrew environment. Static equivalent of `eval "$(brew shellenv zsh)"`, which
# spawns brew on every login shell just to print these same lines.
if [[ "$CPUTYPE" == "arm64" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew" HOMEBREW_REPOSITORY="/opt/homebrew"
else
    export HOMEBREW_PREFIX="/usr/local" HOMEBREW_REPOSITORY="/usr/local/Homebrew"
fi
if [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
    export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
    fpath[1,0]="$HOMEBREW_PREFIX/share/zsh/site-functions"
    export FPATH
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin${PATH+:$PATH}"
    [ -z "${MANPATH-}" ] || { export MANPATH="${MANPATH%"${MANPATH##*[!:]}"}"; export MANPATH=":${MANPATH#"${MANPATH%%[!:]*}"}"; }
    export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
fi

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh"
