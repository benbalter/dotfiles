#!/bin/sh
# Init ZSH and the shell environment
# Usage source script/init

# Init some stuff
if brew command command-not-found-init > /dev/null; then eval "$(brew command-not-found-init)"; fi
if which nodenv > /dev/null; then eval "$(nodenv init -)"; fi
#if which rbenv > /dev/null;  then eval "$(rbenv init -)"; fi
if which fasd > /dev/null; then eval "$(fasd --init auto)"; fi

# Load libs
source ~/.files/lib/globals.sh
source ~/.files/lib/zsh.sh
source ~/.files/lib/aliases.sh
source ~/.iterm2_shell_integration.zsh
