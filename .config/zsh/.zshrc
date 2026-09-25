if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # If you're using macOS, you'll want this enabled
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

typeset -U path  # ensures unique entries only (removes duplicates)
path=(
    $HOME/bin
    $HOME/.local/bin
    $HOME/.digicert
    $path
)
export PATH

# Zinit installation
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"


# Load OMZ libs we need (not the whole thing)
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git

# Zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
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
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[H' beginning-of-line # home key
bindkey '^[[F' end-of-line # end key
bindkey '^[[1;3C' forward-word # Option+Right
bindkey '^[[1;3D' backward-word # Option+Left

export HOMEBREW_AUTO_UPDATE_SECS="86400"
export EDITOR='nvim'
export VISUAL='nvim'
export LESS='-R'

# history setup
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
alias reload='source ~/.zshrc'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

mkcd() {
    mkdir -p "$1" && cd "$1"
}
