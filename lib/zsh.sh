#!/bin/sh
# ZSH settings and initializations

export ZSH=/Users/benbalter/.oh-my-zsh
export SHELL=$(which zsh)

export ZSH_THEME="robbyrussell"
export DISABLE_UPDATE_PROMPT=true
export COMPLETION_WAITING_DOTS="true"

export plugins=(
  atom
  battery
  bower
  brew
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
  history-substring-search
  git
  git-extras
  heroku
  iwhois
  node
  npm
  osx
  rake
  rake-fast
  rbenv
  ruby
  safe-paste
  ssh-agent
  sudo
  zsh_reload
)

source $ZSH/oh-my-zsh.sh
