#!/usr/bin/env bats
# Test script/audit-casks against a fake Brewfile, with brew, mdls and date
# stubbed so it runs off macOS (CI runs BATS on Ubuntu) and never touches the
# real Brewfile or Spotlight.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

NOW=1790000000

setup() {
	TEST_HOME="$(mktemp -d)"
	STUB_BIN="$TEST_HOME/stub-bin"
	mkdir -p "$STUB_BIN" "$TEST_HOME/Applications" "$TEST_HOME/dotfiles" "$TEST_HOME/lastused"

	# `brew info --cask --json=v2` → one app per cask; zz-font has no app.
	cat >"$STUB_BIN/brew" <<-'EOF'
		#!/bin/sh
		cat <<-JSON
		{"casks": [
		  {"token": "zz-stale", "artifacts": [{"app": ["Zz Stale.app"]}]},
		  {"token": "zz-fresh", "artifacts": [{"app": ["Zz Fresh.app"]}]},
		  {"token": "zz-never", "artifacts": [{"app": ["Zz Never.app"]}]},
		  {"token": "zz-missing", "artifacts": [{"app": ["Zz Missing.app"]}]},
		  {"token": "zz-font", "artifacts": [{"font": ["Zz.ttf"]}]}
		]}
		JSON
	EOF

	# mdls prints whatever is recorded for the app: "T-<days>" or "(null)".
	cat >"$STUB_BIN/mdls" <<-'EOF'
		#!/bin/sh
		for last; do :; done
		cat "$HOME/lastused/$(basename "$last")"
	EOF

	# BSD `date -j -f fmt "T-<days>" +%s` → NOW minus that many days;
	# `date +%s` → NOW.
	cat >"$STUB_BIN/date" <<-EOF
		#!/bin/sh
		if [ "\$1" = -j ]; then
			days=\${4#T-}
			echo \$(($NOW - days * 86400))
		else
			echo $NOW
		fi
	EOF
	chmod +x "$STUB_BIN"/*

	for app in "Zz Stale" "Zz Fresh" "Zz Never"; do
		mkdir "$TEST_HOME/Applications/$app.app"
	done
	echo T-30 >"$TEST_HOME/lastused/Zz Stale.app"
	echo T-3 >"$TEST_HOME/lastused/Zz Fresh.app"
	echo "(null)" >"$TEST_HOME/lastused/Zz Never.app"

	# Mirror the real layout: ~/.Brewfile is a symlink into the dotfiles.
	cat >"$TEST_HOME/dotfiles/Brewfile" <<-'EOF'
		# Stale app
		cask 'zz-stale'
		cask 'zz-fresh'
		cask 'zz-never'
		cask 'zz-missing'
		cask 'zz-font'
		brew 'jq'
	EOF
	ln -s "$TEST_HOME/dotfiles/Brewfile" "$TEST_HOME/.Brewfile"
}

teardown() {
	rm -rf "$TEST_HOME"
}

run_audit() {
	run env HOME="$TEST_HOME" PATH="$STUB_BIN:$PATH" AUDIT_STALE_DAYS=14 \
		"$REPO_ROOT/script/audit-casks" "$@"
}

@test "audit-casks report mode changes nothing" {
	before=$(cat "$TEST_HOME/dotfiles/Brewfile")
	run_audit
	[ "$status" -eq 0 ] || fail "exited $status: $output"
	echo "$output" | grep -q 'zz-stale.*last opened 30 days ago' || fail "$output"
	[ "$(cat "$TEST_HOME/dotfiles/Brewfile")" = "$before" ] || fail "report mode edited the Brewfile"
}

@test "audit-casks --comment proposes only casks idle past the threshold" {
	run_audit --comment
	[ "$status" -eq 0 ] || fail "exited $status: $output"
	brewfile="$TEST_HOME/dotfiles/Brewfile"
	grep -qxF "# cask 'zz-stale' # PROPOSED REMOVAL: last opened 30 days ago" "$brewfile" ||
		fail "stale cask not proposed: $(cat "$brewfile")"
	# Recently used, undated, uninstalled, and app-less casks are never
	# guessed at: `clean` would uninstall whatever gets commented out.
	for cask in zz-fresh zz-never zz-missing zz-font; do
		grep -qxF "cask '$cask'" "$brewfile" || fail "$cask should be untouched: $(cat "$brewfile")"
	done
	grep -qxF "brew 'jq'" "$brewfile" || fail "non-cask line lost"
	grep -qxF "# Stale app" "$brewfile" || fail "comment line lost"
}

@test "audit-casks --comment edits the real file, not the symlink" {
	run_audit --comment
	[ -L "$TEST_HOME/.Brewfile" ] || fail ".Brewfile symlink was replaced"
	grep -q 'PROPOSED REMOVAL' "$TEST_HOME/dotfiles/Brewfile" || fail "real Brewfile not edited"
}

@test "audit-casks --comment is a no-op when nothing is stale" {
	echo T-1 >"$TEST_HOME/lastused/Zz Stale.app"
	before=$(cat "$TEST_HOME/dotfiles/Brewfile")
	run_audit --comment
	[ "$status" -eq 0 ] || fail "exited $status: $output"
	echo "$output" | grep -q 'nothing to propose' || fail "$output"
	[ "$(cat "$TEST_HOME/dotfiles/Brewfile")" = "$before" ] || fail "Brewfile changed"
}

@test "audit-casks rejects unknown arguments" {
	run_audit --bogus
	[ "$status" -eq 2 ]
}
