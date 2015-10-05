#!/bin/sh
# Set up some common global variables

export DOTFILES_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
export EDITOR='atom -w'

# Setup cli tools
export HOMEBREW_CASK_OPTS="--appdir=/Applications"
export PATH="./bin:/usr/local/sbin:$PATH"

# GitHub token with no scope, used to get around API limits
export HOMEBREW_GITHUB_API_TOKEN=$(cat ~/.token)

# You've got mail
unset MAILCHECK
