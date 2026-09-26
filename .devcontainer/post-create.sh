#!/bin/sh
# Post-create setup for the Codespaces devcontainer

set -eu
# shellcheck disable=SC3040
(set -o pipefail) 2>/dev/null && set -o pipefail || true

# Install lint tools not provided by devcontainer features
sudo apt-get update -q
sudo apt-get install -y -q shellcheck bats
go install mvdan.cc/sh/v3/cmd/shfmt@latest
go install github.com/rhysd/actionlint/cmd/actionlint@latest
# The BATS suite reads config.yml with (mikefarah's) yq.
go install github.com/mikefarah/yq/v4@latest

# Install CLI tools used by dotfiles (delta, zoxide, fzf)
script/install-tools
