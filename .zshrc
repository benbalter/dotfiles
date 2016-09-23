source ~/.files/script/setup/shell

local plugins
plugins=(
  atom
  battery
  bower
  brew
  brew-cask
  bundler
  cloudapp
  coffee
  colored-man
  colorize
  command-not-found
  common-aliases
  cp
  extract
  fasd
  gem
  git
  git-extras
  history-substring-search
  heroku
  iwhois
  node
  npm
  osx
  rake
  rake-fast
  ruby
  safe-paste
  ssh-agent
  sudo
  zsh_reload
)

source $ZSH/oh-my-zsh.sh

test -e ${HOME}/.iterm2_shell_integration.zsh && source ${HOME}/.iterm2_shell_integration.zsh
