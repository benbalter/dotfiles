# @BenBalter's dotfiles

[![CI](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml)

@BenBalter's development environment and the scripts to initialize it and keep it up to date.

## What's here

### Scripts

- `script/setup` - Set up all the things!
- `script/update` - Update all the things!
- `install.sh` - Codespaces / Linux installer

### Everything else

- Configuration files that will be symlinked into the proper place
- Common development aliases
- Launch agents to keep the Downloads folder tidy and dependencies up to date

## Setting up a new machine from scratch

1. `git clone https://github.com/benbalter/dotfiles ~/.dotfiles`
2. `cd ~/.dotfiles && script/setup`

## GitHub Codespaces

These dotfiles are automatically applied to new Codespaces when configured in
your [GitHub settings](https://github.com/settings/codespaces). The `install.sh`
script symlinks dotfiles, installs oh-my-zsh, and sets zsh as the default shell.
macOS-specific configuration is skipped in Codespaces.

## How to update dependencies

Run `up`
