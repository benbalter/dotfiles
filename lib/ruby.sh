#!/bin/sh

gem update --system
bundle install --system --gemfile "$DOTFILES_ROOT/Gemfile"
gem update
