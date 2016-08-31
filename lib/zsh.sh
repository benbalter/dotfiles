#!/bin/sh

# ZSH settings and initializations
export ZSH=$HOME/.oh-my-zsh
export SHELL=$(which zsh)
export ZSH_THEME="robbyrussell"
export DISABLE_UPDATE_PROMPT=true
export COMPLETION_WAITING_DOTS="true"

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
