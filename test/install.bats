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
	perms=$(stat -c %a "$TEST_HOME/.gnupg" 2>/dev/null || stat -f %Lp "$TEST_HOME/.gnupg")
	[ "$perms" = "700" ] || fail ".gnupg should be 0700, got $perms"
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

	# ...and each link whose path differs in the repo points at its src.
	while IFS=$'\t' read -r src dest; do
		[ "$(readlink "$TEST_HOME/$dest")" = "$REPO_ROOT/$src" ] ||
			fail "$dest links to $(readlink "$TEST_HOME/$dest"), expected $REPO_ROOT/$src"
	done < <(yq -r '.dotfile_links_common[] | [.src, .dest] | @tsv' "$REPO_ROOT/config.yml")
}

@test "install.sh backs up a real file instead of replacing it" {
	# A pre-existing file (and an older backup of it) must both survive.
	echo mine >"$TEST_HOME/.zshrc"
	echo older >"$TEST_HOME/.zshrc.bak"
	mkdir -p "$TEST_HOME/.config/mise"
	echo mine >"$TEST_HOME/.config/mise/config.toml"
	# shellcheck disable=SC2016
	run env HOME="$TEST_HOME" DOTFILES_SKIP_TOOLS=1 DOTFILES_SIMPLE_INSTALL=1 bash -c '
		uname() { echo Linux; }; export -f uname
		git() { mkdir -p "$3"; }; export -f git
		sudo() { :; }; export -f sudo
		. "'"$REPO_ROOT"'/install.sh"
	'
	[ "$status" -eq 0 ] || fail "$output"
	[ -L "$TEST_HOME/.zshrc" ] || fail ".zshrc was not linked"
	[ "$(cat "$TEST_HOME/.zshrc.bak")" = older ] || fail "existing .zshrc.bak was overwritten"
	grep -qx mine "$TEST_HOME"/.zshrc.bak.* || fail "no timestamped backup of .zshrc"
	[ "$(cat "$TEST_HOME/.config/mise/config.toml.bak")" = mine ] ||
		fail "mise config was replaced without a backup"
}
