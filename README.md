# @BenBalter's dotfiles
[![Build Status](https://travis-ci.org/benbalter/dotfiles.svg?branch=master)](https://travis-ci.org/benbalter/dotfiles)

@BenBalter's development environment and the scripts to initialize it and keep it up to date.

## What's here:

- `script/bootstrap` - Bootstrap this repo
- `script/setup` - Set up all the things!
- `script/update` - Update all the things!
- `.Atom` - Editor configuration and plugins
- `.Brewfile` - Homebrew dependencies
- `.gemrc` - Gem settings
- `.gitconfig` and `.gitignore` - Git settings
- `.irbrc` - IRB settings
- `.zshrc` - ZSH (shell) settings
- Common development aliases
- Launch agents to keep the Downloads folder tidy and dependencies up to date

## Setting up a new machine from scratch

1. Login to [osx-strap.herokuapp.com](https://osx-strap.herokuapp.com/) (or [strap.githubapp.com](https://strap.githubapp.com) for GitHubbers)
2. Download `strap.sh`
3. `curl -s https://raw.githubusercontent.com/benbalter/dotfiles/master/script/bootstrap | bash`

## How to update dependencies

Run `up`
