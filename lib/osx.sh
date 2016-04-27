#!/bin/sh
# OS X settings

# screensaverwhub/octodex.github.com" ]]; then
  git clone https://github.com/github/octodex.github.com "$HOME_DIR/github/octodex.github.com"
fi

touch "$HOME_DIR/.hushlogin"

sudo plister "$HOME_DIR/.osx.yml"
