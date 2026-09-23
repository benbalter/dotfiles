#!/usr/bin/env bats
# Test that install.sh (Linux path) creates the correct symlinks.

load test_helper

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
	run env HOME="$TEST_HOME" DOTFILES_SKIP_TOOLS=1 DOTFILES_SIMPLE_INSTALL=1 bash -c '
		uname() { echo Linux; }; export -f uname
		git() { mkdir -p "$3"; }; export -f git
		sudo() { :; }; export -f sudo
		. "'"$REPO_ROOT"'/install.sh"
	'
	[ "$status" -eq 0 ]

	# Verify key dotfile symlinks exist
	for file in .digrc .gemrc .gitconfig .gitignore .hushlogin \
		.irbrc .pryrc .remarkrc .yamllint .zprofile .zshrc; do
		[ -L "$TEST_HOME/$file" ] || fail "$file was not symlinked"
	done
}

@test "install.sh creates required directories" {
	# shellcheck disable=SC2016
	run env HOME="$TEST_HOME" DOTFILES_SKIP_TOOLS=1 DOTFILES_SIMPLE_INSTALL=1 bash -c '
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

@test "install.sh does not link macOS-only dotfiles" {
	# shellcheck disable=SC2016
	run env HOME="$TEST_HOME" DOTFILES_SKIP_TOOLS=1 DOTFILES_SIMPLE_INSTALL=1 bash -c '
		uname() { echo Linux; }; export -f uname
		git() { mkdir -p "$3"; }; export -f git
		sudo() { :; }; export -f sudo
		. "'"$REPO_ROOT"'/install.sh"
	'
	[ "$status" -eq 0 ]

	# e.g. .gnupg/gpg-agent.conf hardcodes pinentry-mac and breaks gpg on Linux
	while IFS= read -r file; do
		[ ! -L "$TEST_HOME/$file" ] || fail "install.sh linked macOS-only '$file'"
	done < <(yq -r '.dotfiles_files_macos[]' "$REPO_ROOT/config.yml")
}

@test "install.sh links exactly config.yml's common dotfiles" {
	# install.sh hand-maintains a second copy of the dotfile list. Compare the
	# links it actually creates against config.yml in both directions, so an
	# entry added to one but not the other (or a Mac-only file leaking in) fails.
	# shellcheck disable=SC2016
	run env HOME="$TEST_HOME" DOTFILES_SKIP_TOOLS=1 DOTFILES_SIMPLE_INSTALL=1 bash -c '
		uname() { echo Linux; }; export -f uname
		git() { mkdir -p "$3"; }; export -f git
		sudo() { :; }; export -f sudo
		. "'"$REPO_ROOT"'/install.sh"
	'
	[ "$status" -eq 0 ]

	expected=$(
		yq -r '.dotfiles_files_common[]' "$REPO_ROOT/config.yml"
		yq -r '.dotfile_links_common[].dest' "$REPO_ROOT/config.yml"
	)
	actual=$(cd "$TEST_HOME" && find . -type l | sed 's|^\./||')

	missing=$(comm -23 <(echo "$expected" | sort) <(echo "$actual" | sort))
	extra=$(comm -13 <(echo "$expected" | sort) <(echo "$actual" | sort))
	[ -z "$missing" ] || fail "install.sh does not link: $missing"
	[ -z "$extra" ] || fail "install.sh links entries missing from config.yml common lists: $extra"
}
