# shellcheck source=lib/globals
source "/$HOME/.files/lib/globals"

local plugins
plugins=(
  battery
  bower
  brew
  bundler
  cloudapp
  coffee
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
  history-substring-search
  heroku
  node
  npm
  osx
  rake
  rake-fast
  ruby
  safe-paste
  ssh-agent
  sudo
  vscode
  zsh_reload
  zsh-interactive-cd
)

source $ZSH/oh-my-zsh.sh

# shellcheck source=script/setup/shell
source "$DOTFILES_ROOT/script/setup/shell"

# shellcheck source=lib/aliases
source "$DOTFILES_ROOT/lib/aliases"

test -e ${HOME}/.iterm2_shell_integration.zsh && source ${HOME}/.iterm2_shell_integration.zsh