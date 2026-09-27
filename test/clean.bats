#!/usr/bin/env bats
# Test script/clean with brew and uname stubbed, so nothing is uninstalled.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	STUB_BIN="$(mktemp -d)"
	LOG="$STUB_BIN/calls.log"
	: >"$LOG"
	# shellcheck disable=SC2016 # expands when the stub runs
	printf '#!/bin/sh\necho "${UNAME:-Darwin}"\n' >"$STUB_BIN/uname"
	printf '#!/bin/sh\necho "brew $*" >>"%s"\n' "$LOG" >"$STUB_BIN/brew"
	chmod +x "$STUB_BIN/uname" "$STUB_BIN/brew"
}

teardown() {
	rm -rf "$STUB_BIN"
}

@test "clean refuses to run on Linux" {
	# The Brewfile only describes macOS: cleanup there would uninstall
	# everything brew has installed.
	run env UNAME=Linux PATH="$STUB_BIN:$PATH" "$REPO_ROOT/script/clean"
	[ "$status" -eq 1 ] || fail "clean exited $status: $output"
	[ ! -s "$LOG" ] || fail "brew was called: $(cat "$LOG")"
}

@test "clean cleans up against the repo Brewfile on macOS" {
	run env PATH="$STUB_BIN:$PATH" "$REPO_ROOT/script/clean"
	[ "$status" -eq 0 ] || fail "$output"
	[ "$(cat "$LOG")" = "brew bundle cleanup --file=Brewfile --force" ] || fail "$(cat "$LOG")"
}
