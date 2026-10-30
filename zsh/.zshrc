if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # If you're using macOS, you'll want this enabled
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

typeset -U path  # ensures unique entries only (removes duplicates)
path=(
    $HOME/bin
    $HOME/.local/bin
    $path
)
export PATH

# Zinit installation
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# Git
alias gc="git commit -m"
alias gp="git push"
alias gpr="git pull -r"
alias gst="git status"
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
alias gdiff="git diff"
alias gco="git checkout"
alias gb='git branch'
alias gba='git branch -a'
alias gadd='git add'
alias gf='git fetch'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'

# checkout default branch
gcm() {
  local b=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  git checkout "${b#origin/}"
}

# squash commits on the current branch into a single commit
# Usage: gsquash, optionally followed by a commit message: gsquash -m "message"
gsquash() {
  local b=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  git reset --soft "$(git merge-base "$b" HEAD)" && git commit "$@"
}

# Zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-history-substring-search
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Load completions efficiently (after prompt is ready)
autoload -Uz compinit && compinit
zinit cdreplay -q

# Initialize tools
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v fnm &>/dev/null && eval "$(fnm env --use-on-cd --shell zsh --version-file-strategy=recursive)"
command -v fzf &>/dev/null && eval "$(fzf --zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# Keybindings
bindkey -e
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[H' beginning-of-line # home key
bindkey '^[[F' end-of-line # end key
bindkey '^[[1;3C' forward-word # Option+Right
bindkey '^[[1;3D' backward-word # Option+Left

export HOMEBREW_AUTO_UPDATE_SECS="86400"
export EDITOR='nvim'
export VISUAL='nvim'
export LESS='-R'

# history setup
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND=""
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND=""
HISTSIZE=10000
SAVEHIST=$HISTSIZE
HISTFILE="$ZDOTDIR/.zhistory"
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias ls='ls --color'
alias vim='nvim'
alias c='clear'
alias mkdir='mkdir -p'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias reload='source $ZDOTDIR/.zshrc'
alias nvm='fnm'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Eza
alias l="eza -l --icons --git -a"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2  --icons --git"

mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Open command in a tmux popup
u() {
    local cmd="$*"
    (( $+aliases[$1] )) && cmd="${aliases[$1]} ${*:2}"
    tmux display-popup -E -w 90% -h 90% -d "#{pane_current_path}" -S "fg=magenta" "${cmd:-$SHELL}"
}

# Machine-specific config, untracked. Sourced last so it can override anything above.
[[ -f "$ZDOTDIR/.zshrc.local" ]] && source "$ZDOTDIR/.zshrc.local"
