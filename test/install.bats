#!/usr/bin/env bats
# Test that install.sh (Linux path) creates the correct symlinks.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	TEST_HOME="$(mktemp -d)"
	export HOME="$TEST_HOME"
}

teardown() {
	rm -rf "$TEST_HOME"
}

@test "install.sh symlinks dotfiles to HOME" {
	# Stub out uname so we hit the Linux path and git/chsh so they no-op
	# shellcheck disable=SC2016
	run env HOME="$TEST_HOME" DOTFILES_SKIP_TOOLS=1 bash -c '
		uname() { echo Linux; }; export -f uname
		git() { mkdir -p "$3"; }; export -f git
		sudo() { :; }; export -f sudo
		. "'"$REPO_ROOT"'/install.sh"
	'
	[ "$status" -eq 0 ]

	# Verify key dotfile symlinks exist
	for file in .asdfrc .digrc .gemrc .gitconfig .gitignore .hushlogin \
		.irbrc .pryrc .remarkrc .yamllint .zprofile .zshrc; do
		[ -L "$TEST_HOME/$file" ] || fail "$file was not symlinked"
	done
}

@test "install.sh creates required directories" {
	# shellcheck disable=SC2016
	run env HOME="$TEST_HOME" DOTFILES_SKIP_TOOLS=1 bash -c '
		uname() { echo Linux; }; export -f uname
		git() { mkdir -p "$3"; }; export -f git
		sudo() { :; }; export -f sudo
		. "'"$REPO_ROOT"'/install.sh"
	'
	[ "$status" -eq 0 ]

	for dir in .bundle .gnupg; do
		[ -d "$TEST_HOME/$dir" ] || fail "$dir directory was not created"
	done
}
