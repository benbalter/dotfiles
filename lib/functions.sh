#!/bin/bash

title () {
  echo ""
  echo "-------------------------------"
  echo $1
  echo "-------------------------------"
  echo ""
}

link() {
  username=$(whoami)
  if [[ ! -f "$HOME_DIR/$1" ]] || [[ $(ls -l "$HOME_DIR/$1" | awk '{print $11}') != "$DOTFILES_ROOT/$1" ]]; then
    echo "Linking $HOME_DIR/$1 to $DOTFILES_ROOT/$1"
    rm -f "$HOME_DIR/$1"
    ln -sf "$DOTFILES_ROOT/$1" "$HOME_DIR/$1"
  fi
}

mkdir_safe() {
  if [[ ! -d "$HOME_DIR/$1" ]]; then
    echo "Creating $1 directory"
    mkdir "$HOME_DIR/$1"
  fi
}

latest_ruby() {
  latest_ruby=$(rbenv install -l | grep -v - | tail -1 )
  echo "$(echo "${latest_ruby}" | tr -d '[[:space:]]')"
}
