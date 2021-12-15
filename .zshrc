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
  battery
  brew
  bundler
  colored-man-pages
  colorize
  command-not-found
  common-aliases
  cp
  dotenv
  extract
  fasd
  gem
  git
  git-extras
  golang
  heroku
  history-substring-search
  iterm2 
  macos
  node
  npm
  osx
  safe-paste
  ssh-agent
  sudo
  vscode
  zsh-interactive-cd
)

source $ZSH/oh-my-zsh.sh

# shellcheck source=lib/auto-complete
source "$DOTFILES_ROOT/lib/auto-complete"

# shellcheck source=lib/aliases
source "$DOTFILES_ROOT/lib/aliases"

test -e ${HOME}/.iterm2_shell_integration.zsh && source ${HOME}/.iterm2_shell_integration.zsh