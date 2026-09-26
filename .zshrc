# The repo is wherever this file's symlink points (~/.files, Codespaces'
# persisted share, or any other checkout install.sh was run from).
export DOTFILES_ROOT="${${(%):-%x}:A:h}"

# Keep PATH and fpath free of duplicates: lib/globals prepends and this file
# appends on every start, so each nested shell used to add another copy. -U
# only dedupes assignments to the arrays, not to the PATH scalar that
# lib/globals and mise write, so the arrays are re-assigned at the end too.
typeset -U path fpath

# shellcheck source=lib/globals
source "$DOTFILES_ROOT/lib/globals"

typeset -a plugins
plugins=(
  ansible
  bgnotify
  colored-man-pages
  command-not-found
  common-aliases
  cp
  dotenv
  extract
  zoxide
  gem
  git
  golang
  node
  npm
  safe-paste
  sudo
  vscode
)

if [[ "$(uname)" == "Darwin" ]]; then
  plugins+=(
    brew
    bundler
    macos
  )
elif command -v dnf >/dev/null; then
  plugins+=(dnf)
fi

# Workbrew installs apps (e.g. Docker.app) as the `workbrew` user, so their
# bundled completion files are owned by workbrew rather than us. compinit's
# audit flags those as insecure and skips them. They are trusted local files,
# so disable the audit (oh-my-zsh's sanctioned escape hatch for this case).
ZSH_DISABLE_COMPFIX="true"

source "$ZSH/oh-my-zsh.sh"

# shellcheck source=lib/auto-complete
source "$DOTFILES_ROOT/lib/auto-complete"

# shellcheck source=lib/aliases
source "$DOTFILES_ROOT/lib/aliases"

# Before the mise check: install-tools puts mise itself in ~/.local/bin.
export PATH="$PATH:$HOME/.local/bin"

if command -v mise >/dev/null; then
  eval "$(mise activate zsh)"
fi

# 1Password SSH agent
if [[ "$(uname)" == "Darwin" ]]; then
  export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  # Added by LM Studio CLI (lms)
  [[ -d "$HOME/.lmstudio/bin" ]] && export PATH="$PATH:$HOME/.lmstudio/bin"
elif [[ -S "$HOME/.1password/agent.sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

if command -v starship >/dev/null; then
  eval "$(starship init zsh)"
fi

# fzf: Ctrl-T (files), Alt-C (cd). Sourced BEFORE atuin so atuin keeps Ctrl-R.
# Each helper only if installed: install-tools (Codespaces) provides fzf but
# not fd, bat or eza, and fzf's defaults beat a command that doesn't exist.
if command -v fzf >/dev/null; then
  if command -v fd >/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  fi
  command -v bat >/dev/null &&
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
  command -v eza >/dev/null &&
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
  source <(fzf --zsh)
fi

# Better shell history (Ctrl-R). Leave the up-arrow to history-substring-search.
if command -v atuin >/dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# ── Loaded shell (ORDER MATTERS) ──────────────────────────────────
# Notify when a >Ns command finishes in an unfocused terminal (bgnotify plugin).
bgnotify_threshold=8

# fzf-tab: fuzzy completion menu. Then autosuggestions, then
# syntax-highlighting (from Homebrew formulae), and finally oh-my-zsh's
# history-substring-search, whose README says to load it after
# syntax-highlighting. It was an oh-my-zsh plugin, which loaded it first.
[[ -f $HOMEBREW_PREFIX/share/fzf-tab/fzf-tab.zsh ]] && source $HOMEBREW_PREFIX/share/fzf-tab/fzf-tab.zsh
[[ -f $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f $ZSH/plugins/history-substring-search/history-substring-search.plugin.zsh ]] &&
  source $ZSH/plugins/history-substring-search/history-substring-search.plugin.zsh

# Apply -U to everything added through the PATH/FPATH scalars above.
path=("${path[@]}")
fpath=("${fpath[@]}")
