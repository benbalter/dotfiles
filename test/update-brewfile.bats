#!/usr/bin/env bats
# Test script/update-brewfile's guard against erasing audit-casks proposals.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	FAKE_ROOT="$(mktemp -d)"
	STUB_BIN="$FAKE_ROOT/stub-bin"
	LOG="$FAKE_ROOT/calls.log"
	mkdir -p "$STUB_BIN"
	: >"$LOG"
	for cmd in brew bundle; do
		printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$cmd" "$LOG" >"$STUB_BIN/$cmd"
		chmod +x "$STUB_BIN/$cmd"
	done
}

teardown() {
	rm -rf "$FAKE_ROOT"
}

run_update_brewfile() {
	run env DOTFILES_ROOT="$FAKE_ROOT" PATH="$STUB_BIN:$PATH" "$REPO_ROOT/script/update-brewfile"
}

@test "update-brewfile refuses to dump over pending removal proposals" {
	printf "cask 'kept'\n# cask 'stale' # PROPOSED REMOVAL: last opened 30 days ago\n" >"$FAKE_ROOT/Brewfile"
	run_update_brewfile
	[ "$status" -eq 1 ] || fail "expected refusal, got $status: $output"
	echo "$output" | grep -q 'PROPOSED REMOVAL' || fail "$output"
	[ ! -s "$LOG" ] || fail "should not run brew or rubocop: $(cat "$LOG")"
}

@test "update-brewfile dumps and lints only the Brewfile" {
	printf "cask 'kept'\n" >"$FAKE_ROOT/Brewfile"
	run_update_brewfile
	[ "$status" -eq 0 ] || fail "exited $status: $output"
	grep -qxF "brew bundle dump --global --force" "$LOG" || fail "$(cat "$LOG")"
	grep -qxF "bundle exec rubocop -A Brewfile" "$LOG" || fail "$(cat "$LOG")"
}
