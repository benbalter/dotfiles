# @BenBalter's dotfiles

[![CI](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml)

@BenBalter's development environment and the scripts to initialize it and keep it up to date.

## What's here

### Scripts

* `script/setup` - Set up all the things!
* `script/update` - Update all the things!

### Everything else

* Configuration files that will be symlinked into the proper place
* Common development aliases
* Launch agents to keep the Downloads folder tidy and dependencies up to date

## Setting up a new machine from scratch

1. Login to [osx-strap.herokuapp.com](https://osx-strap.herokuapp.com/) (or [strap.githubapp.com](https://strap.githubapp.com) for GitHubbers)
2. Download `strap.sh`
3. `bash ~/Downloads/strap.sh`

## How to update dependencies

Run `up`
