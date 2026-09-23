#!/usr/bin/env bats
# Test script/doctor's symlink checks against a fake $HOME (Linux lists).

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	TEST_HOME="$(mktemp -d)"
	STUB_BIN="$(mktemp -d)"
	# Force the Linux lists (and skip launchctl) wherever the suite runs.
	printf '#!/bin/sh\necho Linux\n' >"$STUB_BIN/uname"
	chmod +x "$STUB_BIN/uname"

	# Link everything the Linux playbook would.
	while IFS= read -r file; do
		mkdir -p "$(dirname "$TEST_HOME/$file")"
		ln -s "$REPO_ROOT/$file" "$TEST_HOME/$file"
	done < <(yq -r '.dotfiles_files_common[], .dotfiles_files_linux[]' "$REPO_ROOT/config.yml")
	while IFS=$'\t' read -r src dest; do
		mkdir -p "$(dirname "$TEST_HOME/$dest")"
		ln -s "$REPO_ROOT/$src" "$TEST_HOME/$dest"
	done < <(yq -r '(.dotfile_links_common[], .linux_dotfile_links[]) | [.src, .dest] | @tsv' "$REPO_ROOT/config.yml")
}

teardown() {
	rm -rf "$TEST_HOME" "$STUB_BIN"
}

run_doctor() {
	run env HOME="$TEST_HOME" DOTFILES_ROOT="$REPO_ROOT" PATH="$STUB_BIN:$PATH" \
		"$REPO_ROOT/script/doctor"
	# Only the symlink section: the brew check depends on the host.
	links_output=$(echo "$output" | sed -n '/^==> Dotfile symlinks/,/^==> /p')
}

@test "doctor passes when every dotfile is linked" {
	run_doctor
	echo "$links_output" | grep -q '  ok    ' || fail "no links checked: $output"
	! echo "$links_output" | grep -q 'FAIL' || fail "unexpected failure: $links_output"
}

@test "doctor flags a missing, replaced, or misdirected link" {
	rm "$TEST_HOME/.zshrc"
	rm "$TEST_HOME/.gitconfig" && echo local >"$TEST_HOME/.gitconfig"
	ln -sf /nonexistent "$TEST_HOME/.digrc"
	run_doctor
	[ "$status" -ne 0 ] || fail "doctor should exit non-zero"
	echo "$links_output" | grep -q "FAIL  $TEST_HOME/.zshrc is missing" || fail "$links_output"
	echo "$links_output" | grep -q "FAIL  $TEST_HOME/.gitconfig is a regular file" || fail "$links_output"
	echo "$links_output" | grep -q "FAIL  $TEST_HOME/.digrc points to /nonexistent" || fail "$links_output"
}

@test "doctor warns about leftover .bak files" {
	echo old >"$TEST_HOME/.npmrc.bak"
	run_doctor
	echo "$links_output" | grep -q "warn  $TEST_HOME/.npmrc.bak" || fail "$links_output"
}
