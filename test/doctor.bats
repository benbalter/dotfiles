#!/usr/bin/env bats
# Test script/doctor's symlink and last-update checks against a fake $HOME
# (Linux lists).

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	TEST_HOME="$(mktemp -d)"
	STUB_BIN="$(mktemp -d)"
	# Force the Linux lists (and skip launchctl) wherever the suite runs, unless
	# a test sets UNAME=Darwin.
	printf '#!/bin/sh\necho "${UNAME:-Linux}"\n' >"$STUB_BIN/uname"
	chmod +x "$STUB_BIN/uname"

	# Host-independent launchd, brew and mise. Each prints $<NAME>_OUT and
	# exits $<NAME>_STATUS (default: healthy, silent).
	cat >"$STUB_BIN/launchctl" <<'STUB'
#!/bin/sh
printf '%s\n' "${LAUNCHCTL_OUT-	last exit code = 0}"
exit "${LAUNCHCTL_STATUS:-0}"
STUB
	cat >"$STUB_BIN/brew" <<'STUB'
#!/bin/sh
printf '%s\n' "${BREW_OUT:-}"
exit "${BREW_STATUS:-0}"
STUB
	cat >"$STUB_BIN/mise" <<'STUB'
#!/bin/sh
[ -z "${MISE_OUT:-}" ] || printf '%s\n' "$MISE_OUT"
STUB
	chmod +x "$STUB_BIN/launchctl" "$STUB_BIN/brew" "$STUB_BIN/mise"

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
	# Per-section slices: the Homebrew and security checks depend on the host.
	links_output=$(echo "$output" | sed -n '/^==> Dotfile symlinks/,/^==> /p')
	update_output=$(echo "$output" | sed -n '/^==> Last update run/,/^==> Packages/p')
	agents_output=$(echo "$output" | sed -n '/^==> Launch agents/,/^==> /p')
	packages_output=$(echo "$output" | sed -n '/^==> Packages/,/^==> /p')
}

# write_status <line>...: a fake script/update status file, one per line.
write_status() {
	STATUS="$TEST_HOME/.local/state/dotfiles/update-status"
	mkdir -p "${STATUS%/*}"
	printf '%s\n' "$@" >"$STATUS"
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

@test "doctor reports the last update run's failed steps" {
	write_status "started=Tue" "finished=Tue" "failed=mas upgrade" "failed=tldr --update"
	run_doctor
	[ "$status" -ne 0 ] || fail "doctor should exit non-zero"
	echo "$update_output" | grep -q "FAIL  run started Tue failed: mas upgrade" || fail "$update_output"
	echo "$update_output" | grep -q "FAIL  run started Tue failed: tldr --update" || fail "$update_output"
}

@test "doctor passes a clean update run" {
	write_status "started=Tue" "finished=Tue"
	run_doctor
	echo "$update_output" | grep -q "ok    run started Tue finished cleanly" || fail "$update_output"
	! echo "$update_output" | grep -q FAIL || fail "$update_output"
}

@test "doctor warns about an update run that never finished" {
	write_status "started=Tue"
	run_doctor
	echo "$update_output" | grep -q "warn  run started Tue never finished" || fail "$update_output"
}

@test "doctor flags an update that hasn't run in days on macOS" {
	write_status "started=Tue" "finished=Tue"
	touch -t 202001010000 "$STATUS"
	UNAME=Darwin run_doctor
	[ "$status" -ne 0 ] || fail "doctor should exit non-zero"
	echo "$update_output" | grep -q "FAIL  no update has run in 2+ days" || fail "$update_output"
}

@test "doctor only warns about a stale update on Linux, which has no nightly job" {
	write_status "started=Tue" "finished=Tue"
	touch -t 202001010000 "$STATUS"
	run_doctor
	echo "$update_output" | grep -q "warn  no update has run in 2+ days" || fail "$update_output"
}

@test "doctor warns about timestamped .bak files too" {
	echo old >"$TEST_HOME/.npmrc.bak.1700000000"
	run_doctor
	echo "$links_output" | grep -q "warn  $TEST_HOME/.npmrc.bak.1700000000" || fail "$links_output"
}

@test "doctor reports a launch agent's failed exit code and its log" {
	LAUNCHCTL_OUT="	last exit code = 78" run_doctor
	[ "$status" -ne 0 ] || fail "doctor should exit non-zero"
	echo "$agents_output" | grep -q "FAIL  com.balter.ben.update last exit code 78; see .*dotfiles-update.log" ||
		fail "$agents_output"
	echo "$agents_output" | grep -q "FAIL  com.balter.ben.tmpreaper last exit code 78" || fail "$agents_output"
}

@test "doctor flags a launch agent that isn't loaded" {
	LAUNCHCTL_OUT="" LAUNCHCTL_STATUS=113 run_doctor
	echo "$agents_output" | grep -q "FAIL  com.balter.ben.update is not loaded" || fail "$agents_output"
}

@test "doctor passes loaded, logging launch agents" {
	run_doctor
	echo "$agents_output" | grep -q "ok    com.balter.ben.tmpreaper loaded" || fail "$agents_output"
	! echo "$agents_output" | grep -qE "FAIL|warn" || fail "$agents_output"
}

@test "doctor lists Brewfile entries that aren't installed" {
	BREW_STATUS=1 BREW_OUT="→ Formula jq needs to be installed or updated." run_doctor
	[ "$status" -ne 0 ] || fail "doctor should exit non-zero"
	echo "$packages_output" | grep -q "FAIL  Brewfile entries not installed" || fail "$packages_output"
	echo "$packages_output" | grep -q "^        Formula jq needs" || fail "$packages_output"
}

@test "doctor lists missing mise tools" {
	MISE_OUT="node  24  (missing)" run_doctor
	echo "$packages_output" | grep -q "FAIL  mise tools not installed" || fail "$packages_output"
	echo "$packages_output" | grep -q "^        node  24  (missing)" || fail "$packages_output"
}

@test "doctor passes when every package is installed" {
	run_doctor
	echo "$packages_output" | grep -q "ok    every Brewfile entry installed" || fail "$packages_output"
	echo "$packages_output" | grep -q "ok    every mise tool installed" || fail "$packages_output"
}

@test "doctor flags an update that has held its lock for hours" {
	lock="$TEST_HOME/.cache/dotfiles-update.lock"
	mkdir -p "$lock"
	echo "$$" >"$lock/pid"
	touch -t 202001010000 "$lock"
	run_doctor
	[ "$status" -ne 0 ] || fail "doctor should exit non-zero"
	echo "$update_output" | grep -q "FAIL  update PID $$ has held .* for 2+ hours" || fail "$update_output"
}

@test "doctor warns about a lock left by a dead update" {
	sh -c 'exit 0' &
	dead=$!
	wait "$dead"
	mkdir -p "$TEST_HOME/.cache/dotfiles-update.lock"
	echo "$dead" >"$TEST_HOME/.cache/dotfiles-update.lock/pid"
	run_doctor
	echo "$update_output" | grep -q "warn  stale lock .* from dead PID $dead" || fail "$update_output"
}
