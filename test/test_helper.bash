#!/usr/bin/env bash
# Shared bats helpers.
#
# Provides fail(), which bats itself does not define -- it ships with
# bats-support/bats-assert, which this repo deliberately does not vendor so the
# suite runs identically under brew bats-core (macOS CI) and apt bats (Linux CI).

fail() {
	echo "$@" >&2
	return 1
}

# On a work Mac, interactive shells export DOTFILES_PROFILE=work (lib/globals
# sources lib/profile), and lib/profile reads the real
# ~/.config/dotfiles/env. Either would turn the personal-profile expectations
# below into work ones, so every test starts from the default profile.
unset DOTFILES_PROFILE
export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}/xdg-config"
