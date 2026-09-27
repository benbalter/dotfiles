#!/bin/sh
# Post-create setup for the Codespaces devcontainer

set -eu
# shellcheck disable=SC3040
(set -o pipefail) 2>/dev/null && set -o pipefail || true

# bats from apt; the lint tools at the same pinned versions as CI, since
# apt's shellcheck and `go install ...@latest` check or format differently.
sudo apt-get update -q
sudo apt-get install -y -q bats
script/install-lint-tools

# Install CLI tools used by dotfiles (delta, zoxide, fzf, and the yq the BATS
# suite reads config.yml with)
script/install-tools
