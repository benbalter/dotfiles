#!/usr/bin/env bats
# script/claude-ai-prefs: --check decides whether script/doctor and
# script/update warn that the claude.ai paste is stale, so a wrong answer
# either nags forever or never warns.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
PREFS_SCRIPT="$REPO_ROOT/script/claude-ai-prefs"

setup() {
	export DOTFILES_ROOT="$BATS_TEST_TMPDIR/root"
	export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
	mkdir -p "$DOTFILES_ROOT/claude" "$BATS_TEST_TMPDIR/bin"
	echo "# Preferences" >"$DOTFILES_ROOT/claude/preferences.md"
	STATE="$XDG_STATE_HOME/dotfiles/claude-ai-preferences.sha256"
	# Stubs, so the copy path never touches the real clipboard or opens a browser.
	# Only pbcopy reads stdin; open would block waiting on it.
	printf '#!/bin/sh\ncat >/dev/null\necho pbcopy >>"%s/calls"\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/bin/pbcopy"
	printf '#!/bin/sh\necho "open $*" >>"%s/calls"\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/bin/open"
	chmod +x "$BATS_TEST_TMPDIR/bin/pbcopy" "$BATS_TEST_TMPDIR/bin/open"
}

@test "--check fails when preferences.md was never copied" {
	run "$PREFS_SCRIPT" --check
	[ "$status" -ne 0 ] || fail "passed with no state file"
}

@test "--check fails once preferences.md changes after a copy" {
	mkdir -p "$(dirname "$STATE")"
	echo stale >"$STATE"
	run "$PREFS_SCRIPT" --check
	[ "$status" -ne 0 ] || fail "passed with a stale hash"
}

@test "copying records a hash that --check then accepts" {
	run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" "$PREFS_SCRIPT"
	[ "$status" -eq 0 ] || fail "copy failed ($status): $output"
	grep -q '^pbcopy' "$BATS_TEST_TMPDIR/calls" || fail "didn't copy to the clipboard"
	grep -q '^open https://claude.ai/' "$BATS_TEST_TMPDIR/calls" || fail "didn't open claude.ai settings"
	run "$PREFS_SCRIPT" --check
	[ "$status" -eq 0 ] || fail "--check rejected a fresh copy"
	echo "- a new rule" >>"$DOTFILES_ROOT/claude/preferences.md"
	run "$PREFS_SCRIPT" --check
	[ "$status" -ne 0 ] || fail "--check accepted an edited preferences.md"
}

@test "copying without pbcopy fails and records nothing" {
	# Codespaces and Linux have no pbcopy; recording a hash there would hide
	# the stale warning on the Mac that does the pasting.
	# macOS ships pbcopy in /usr/bin, so link in only what the script needs.
	nopb="$BATS_TEST_TMPDIR/nopb"
	mkdir -p "$nopb"
	for cmd in sh shasum perl cut cat dirname mkdir; do
		ln -s "$(command -v "$cmd")" "$nopb/$cmd"
	done
	run env PATH="$nopb" "$PREFS_SCRIPT"
	[ "$status" -eq 1 ] || fail "expected exit 1, got $status: $output"
	[[ $output == *"copy"*"by hand"* ]] || fail "no copy-by-hand hint: $output"
	[ ! -e "$STATE" ] || fail "recorded a hash without copying"
}
