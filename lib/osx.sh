#!/bin/sh
# OS X settings

# screensaver
if [[ ! -d "$HOME_DIR/github/octodex.github.com" ]]; then
  git clone https://github.com/github/octodex.github.com "$HOME_DIR/github/octodex.github.com"
fi

touch "$HOME_DIR/.hushlogin"

sudo ./lib/osx.rb
