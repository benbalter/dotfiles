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
		for cmd in brew defaults sudo dnf mas mise npm bundle mole git zsh tldr softwareupdate; do
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

	# HOME points into the sandbox so the lock, the log and
	# oh-my-zsh resolve there and never touch the real ones.
	mkdir -p "$FAKE_ROOT/.oh-my-zsh/tools"
	: >"$FAKE_ROOT/.oh-my-zsh/tools/upgrade.sh"

	export LOG
}

teardown() {
	rm -rf "$FAKE_ROOT"
}

run_update() {
	# `run` captures stdout, so [ -t 1 ] is false: the headless nightly path.
	run env -u ZSH -u XDG_CACHE_HOME -u XDG_STATE_HOME HOME="$FAKE_ROOT" DOTFILES_ROOT="$FAKE_ROOT" \
		LOG="$LOG" STUB_STATUS="$1" STUBS="$STUBS" \
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
	[ "$status" -eq 1 ] || fail "update exited $status: $output"
	assert_called "brew update"
	assert_called "brew upgrade --formula"
	assert_called "brew bundle install --no-upgrade"
	assert_called "brew autoremove"
	assert_called "brew cleanup"
	assert_called "defaults write com.microsoft.autoupdate2 HowToCheck Manual"
	assert_called "sudo -n dnf upgrade --refresh -y"
	assert_called "mise upgrade"
	assert_called "npm ci"
	assert_called "bundle update"
	assert_called "uv pip install --upgrade -r requirements.txt"
	assert_called "ansible-galaxy collection install -r requirements.yml"
	assert_called "zsh $FAKE_ROOT/.oh-my-zsh/tools/upgrade.sh -v minimal"
	assert_called "tldr --update"
	assert_called "softwareupdate --list"
}

@test "update reports failed steps and exits nonzero" {
	# Tolerating failures used to mean always exiting 0, so launchctl and
	# script/doctor never saw a broken nightly run.
	run_update 1
	[ "$status" -eq 1 ] || fail "update exited $status: $output"
	case "$output" in
		*"Failed steps:"*"brew update"*"tldr --update"*) ;;
		*) fail "expected a failed-step summary; got: $output" ;;
	esac
	# script/doctor reads failures from here, not the log.
	status_file="$FAKE_ROOT/.local/state/dotfiles/update-status"
	grep -qx "failed=brew update" "$status_file" || fail "$(cat "$status_file")"
	grep -q "^finished=" "$status_file" || fail "$(cat "$status_file")"
}

@test "update exits 0 with no failure summary when every step succeeds" {
	run_update 0
	[ "$status" -eq 0 ] || fail "update exited $status: $output"
	case "$output" in
		*"Failed steps"*) fail "unexpected failure summary: $output" ;;
	esac
	status_file="$FAKE_ROOT/.local/state/dotfiles/update-status"
	grep -q "^finished=" "$status_file" || fail "$(cat "$status_file")"
	! grep -q "^failed=" "$status_file" || fail "$(cat "$status_file")"
}

@test "update trims the same log the launchd job writes" {
	plist="$REPO_ROOT/Library/LaunchAgents/com.balter.ben.update.plist"
	grep -q "<string>/Users/[^/]*/Library/Logs/dotfiles-update.log</string>" "$plist" ||
		fail "plist log path changed; update UPDATE_LOG in script/update to match"
	grep -qF 'UPDATE_LOG="${DOTFILES_UPDATE_LOG:-$HOME/Library/Logs/dotfiles-update.log}"' \
		"$REPO_ROOT/script/update" || fail "script/update's log path drifted from the plist"
}

@test "update skips when another run holds the lock" {
	# launchd runs a missed midnight job on wake, on top of a manual `up`.
	mkdir -p "$FAKE_ROOT/.cache/dotfiles-update.lock"
	echo "$$" >"$FAKE_ROOT/.cache/dotfiles-update.lock/pid"
	run_update 0
	[ "$status" -eq 0 ] || fail "update exited $status: $output"
	[ ! -s "$LOG" ] || fail "expected no steps to run; got:$(printf '\n%s' "$(cat "$LOG")")"
}

@test "update reclaims a lock left by a dead run and releases it" {
	sh -c 'exit 0' &
	dead=$!
	wait "$dead"
	mkdir -p "$FAKE_ROOT/.cache/dotfiles-update.lock"
	echo "$dead" >"$FAKE_ROOT/.cache/dotfiles-update.lock/pid"
	run_update 0
	[ "$status" -eq 0 ] || fail "update exited $status: $output"
	assert_called "brew update"
	[ ! -e "$FAKE_ROOT/.cache/dotfiles-update.lock" ] || fail "lock not released"
}

@test "headless update trims a long log to its tail" {
	mkdir -p "$FAKE_ROOT/Library/Logs"
	log="$FAKE_ROOT/Library/Logs/dotfiles-update.log"
	seq 1 10001 >"$log"
	run_update 0
	[ "$(wc -l <"$log" | tr -d ' ')" -eq 5000 ] || fail "log has $(wc -l <"$log") lines"
	[ "$(tail -n 1 "$log")" = 10001 ] || fail "log lost its newest line"
}

@test "headless update leaves a short log alone" {
	mkdir -p "$FAKE_ROOT/Library/Logs"
	log="$FAKE_ROOT/Library/Logs/dotfiles-update.log"
	seq 1 100 >"$log"
	run_update 0
	[ "$(wc -l <"$log" | tr -d ' ')" -eq 100 ] || fail "log has $(wc -l <"$log") lines"
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
	# A pull that needs auth or conflicts has no one to see it.
	refute_called '^git'
	# Can hang on an App Store sign-in and hold the lock.
	refute_called '^mas'
}

@test "update never rewrites package-lock.json" {
	run_update 0
	refute_called '^npm (update|install)'
}
