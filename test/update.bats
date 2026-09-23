#!/usr/bin/env bats
# Test script/update's headless (nightly launchd) behavior with every external
# command stubbed out, so nothing is actually upgraded.
# shellcheck disable=SC2016 # stub bodies expand when they run, not here

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	FAKE_ROOT="$(mktemp -d)"
	STUB_BIN="$FAKE_ROOT/stub-bin"
	LOG="$FAKE_ROOT/calls.log"
	mkdir -p "$STUB_BIN" "$FAKE_ROOT/env/bin" "$FAKE_ROOT/script"
	: >"$LOG"

	# script/update prepends /opt/homebrew/bin, /opt/workbrew/bin and the mise
	# shims to PATH whenever they exist, which would put the host's real brew
	# ahead of any PATH stub. So stub those commands as shell functions (which
	# win over PATH), and source the script into the shell that defines them.
	STUBS='
		for cmd in brew defaults sudo dnf mas mise npm bundle mole; do
			eval "$cmd() { echo \"$cmd \$*\" >>\"\$LOG\"; return \$STUB_STATUS; }"
		done
	'

	# The venv's commands (hyphenated ansible-galaxy can't be a POSIX function)
	# come from a fake activate that puts PATH stubs first, after the prepends.
	for cmd in ansible-galaxy uv pip; do
		printf '#!/bin/sh\necho "%s $*" >>"$LOG"\nexit "$STUB_STATUS"\n' "$cmd" >"$STUB_BIN/$cmd"
		chmod +x "$STUB_BIN/$cmd"
	done
	printf 'PATH="%s:$PATH"\ndeactivate() { :; }\n' "$STUB_BIN" >"$FAKE_ROOT/env/bin/activate"

	# Interactive-only steps must never run headless; log it if they do.
	printf '#!/bin/sh\necho "audit-casks $*" >>"$LOG"\n' >"$FAKE_ROOT/script/audit-casks"
	chmod +x "$FAKE_ROOT/script/audit-casks"

	export LOG
}

teardown() {
	rm -rf "$FAKE_ROOT"
}

run_update() {
	# `run` captures stdout, so [ -t 1 ] is false: the headless nightly path.
	run env DOTFILES_ROOT="$FAKE_ROOT" LOG="$LOG" STUB_STATUS="$1" STUBS="$STUBS" \
		sh -c 'eval "$STUBS"; . "$0"' "$REPO_ROOT/script/update"
}

assert_called() {
	grep -qxF "$1" "$LOG" || fail "expected call '$1'; got:$(printf '\n%s' "$(cat "$LOG")")"
}

refute_called() {
	! grep -qE "$1" "$LOG" || fail "unexpected call matching '$1'; got:$(printf '\n%s' "$(cat "$LOG")")"
}

@test "update runs every step even when each one fails" {
	# One failing step used to abort the rest under set -e (e.g. mas upgrade
	# skipping mise, npm, gems and the Ansible roles).
	run_update 1
	[ "$status" -eq 0 ] || fail "update exited $status: $output"
	assert_called "brew update"
	assert_called "brew upgrade --formula"
	assert_called "brew bundle --global --no-upgrade"
	assert_called "brew autoremove"
	assert_called "brew cleanup"
	assert_called "defaults write com.microsoft.autoupdate2 HowToCheck Manual"
	assert_called "sudo -n dnf upgrade --refresh -y"
	assert_called "mas upgrade"
	assert_called "mise upgrade"
	assert_called "npm ci"
	assert_called "bundle update"
	assert_called "uv pip install --upgrade -r requirements.txt"
	assert_called "ansible-galaxy role install -r requirements.yml --force"
	assert_called "ansible-galaxy collection install -r requirements.yml"
}

@test "headless update skips interactive-only steps" {
	run_update 0
	[ "$status" -eq 0 ] || fail "update exited $status: $output"
	# Cask upgrades need a GUI session and sudo; formula-only when headless.
	refute_called '^brew upgrade$'
	# No TTY to answer a password prompt: sudo must be non-interactive.
	refute_called '^sudo dnf'
	# Edits the tracked Brewfile; needs a human to review.
	refute_called '^audit-casks'
	# May prompt for sudo.
	refute_called '^mole'
}

@test "update never rewrites package-lock.json" {
	run_update 0
	refute_called '^npm (update|install)'
}
