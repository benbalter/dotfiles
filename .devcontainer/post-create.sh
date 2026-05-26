#!/bin/sh
# Post-create setup for the Codespaces devcontainer

set -e

# Install lint tools not provided by devcontainer features
sudo apt-get update -q
sudo apt-get install -y -q shellcheck bats
go install mvdan.cc/sh/v3/cmd/shfmt@latest
go install github.com/rhysd/actionlint/cmd/actionlint@latest

# Install CLI tools used by dotfiles (delta, zoxide, fzf)
script/install-tools
