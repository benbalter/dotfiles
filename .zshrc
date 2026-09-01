if [[ -d "/workspaces/.codespaces/.persistedshare/dotfiles/" ]]; then
  export DOTFILES_ROOT="/workspaces/.codespaces/.persistedshare/dotfiles"
else 
  export DOTFILES_ROOT="$HOME/.files"
fi 

# shellcheck source=lib/globals
source "$DOTFILES_ROOT/lib/globals"

typeset -a plugins
plugins=(
  ansible
  colored-man-pages
  command-not-found
  common-aliases
  cp
  dotenv
  extract
  zoxide
  gem
  git
  git-extras
  golang
  history-substring-search
  node
  npm
  safe-paste
  sudo
  vscode
  zsh-interactive-cd
)

if [[ "$(uname)" == "Darwin" ]]; then
  plugins+=(
    battery
    brew
    bundler
    iterm2
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

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

if command -v mise >/dev/null; then
  eval "$(mise activate zsh)"
fi

export PATH="$PATH:$HOME/.local/bin"

# 1Password SSH agent
if [[ "$(uname)" == "Darwin" ]]; then
  export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  # Added by LM Studio CLI (lms)
  export PATH="$PATH:$HOME/.lmstudio/bin"
elif [[ -S "$HOME/.1password/agent.sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

if command -v starship >/dev/null; then
  eval "$(starship init zsh)"
fi

# fzf: Ctrl-T (files), Alt-C (cd). Sourced BEFORE atuin so atuin keeps Ctrl-R.
if command -v fzf >/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
  source <(fzf --zsh)
fi

# Better shell history (Ctrl-R). Leave the up-arrow to history-substring-search.
if command -v atuin >/dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

