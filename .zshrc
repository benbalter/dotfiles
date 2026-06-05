if [[ -d "/workspaces/.codespaces/.persistedshare/dotfiles/" ]]; then
  export DOTFILES_ROOT="/workspaces/.codespaces/.persistedshare/dotfiles"
else 
  export DOTFILES_ROOT="$HOME/.files"
fi 

# shellcheck source=lib/globals
source "$DOTFILES_ROOT/lib/globals"

local plugins
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
 # ssh-agent
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

