#!/usr/bin/env bats
# Test script/setup's flags and script/ansible's choice of how to get sudo,
# against copies in a fake repo whose bootstrap, playbook and sudo are stubs.
# Both scripts cd to their own repo root, so they're copied, not called in place.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	ROOT="$(mktemp -d)"
	LOG="$ROOT/calls"
	STUB_BIN="$ROOT/stub-bin"
	mkdir -p "$ROOT/script" "$ROOT/lib" "$ROOT/env/bin" "$STUB_BIN" "$ROOT/config"
	cp "$REPO_ROOT/script/setup" "$REPO_ROOT/script/ansible" "$ROOT/script/"
	cp "$REPO_ROOT/lib/profile" "$ROOT/lib/"
	for stub in bootstrap update blocking-io; do
		printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$stub" "$LOG" >"$ROOT/script/$stub"
	done
	chmod +x "$ROOT"/script/*
	# The venv's activate: puts the stubs first and defines deactivate.
	cat >"$ROOT/env/bin/activate" <<-EOF
		PATH="$STUB_BIN:\$PATH"
		deactivate() { :; }
	EOF
	printf '#!/bin/sh\necho "ansible-playbook $*" >>"%s"\n' "$LOG" >"$STUB_BIN/ansible-playbook"
	# sudo -n succeeds or fails as the test says.
	cat >"$STUB_BIN/sudo" <<-'EOF'
		#!/bin/sh
		exit "${SUDO_STATUS:-1}"
	EOF
	chmod +x "$STUB_BIN"/*
	: >"$LOG"
}

teardown() {
	rm -rf "$ROOT"
}

# run_setup [flag]: script/setup with the playbook stubbed out too.
run_setup() {
	printf '#!/bin/sh\necho "ansible $*" >>"%s"\n' "$LOG" >"$ROOT/script/ansible"
	run env -u DOTFILES_PROFILE XDG_CONFIG_HOME="$ROOT/config" "$ROOT/script/setup" "$@"
}

# run_ansible [args]: script/ansible with no terminal on stdin. CI and the
# password file are unset unless a test sets them (CI runs this suite too).
run_ansible() {
	run env -u CI -u ANSIBLE_BECOME_PASSWORD_FILE ${CI_VALUE:+CI="$CI_VALUE"} \
		${PASSWORD_FILE:+ANSIBLE_BECOME_PASSWORD_FILE="$PASSWORD_FILE"} \
		SUDO_STATUS="${SUDO_STATUS:-1}" PATH="$STUB_BIN:$PATH" \
		"$ROOT/script/ansible" "$@" </dev/null
}

@test "setup runs bootstrap, the playbook and update, in that order" {
	run_setup
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	echo "$output" | grep -q "Profile: personal" || fail "$output"
	[ "$(tr '\n' ',' <"$LOG")" = "bootstrap ,ansible ,update ," ] || fail "ran: $(cat "$LOG")"
	[ ! -e "$ROOT/config/dotfiles/env" ] || fail "wrote a profile nobody asked for"
}

@test "setup --work records the profile before anything runs" {
	# The stub playbook fails unless the profile is already on disk.
	printf '#!/bin/sh\ngrep -qx "DOTFILES_PROFILE=work" "%s/config/dotfiles/env" || exit 9\n' "$ROOT" >"$ROOT/script/bootstrap"
	run_setup --work
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	echo "$output" | grep -q "Profile: work" || fail "$output"
}

@test "setup --personal switches a work Mac back" {
	mkdir -p "$ROOT/config/dotfiles"
	echo 'DOTFILES_PROFILE=work' >"$ROOT/config/dotfiles/env"
	run_setup --personal
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	echo "$output" | grep -q "Profile: personal" || fail "$output"
	! grep -q 'DOTFILES_PROFILE=work' "$ROOT/config/dotfiles/env" || fail "still work: $(cat "$ROOT/config/dotfiles/env")"
}

@test "setup rejects an unknown flag before running anything" {
	run_setup --wrok
	[ "$status" -eq 1 ] || fail "exit $status: $output"
	echo "$output" | grep -q "Usage: script/setup" || fail "$output"
	[ ! -s "$LOG" ] || fail "ran: $(cat "$LOG")"
}

@test "ansible doesn't prompt for a password in CI" {
	CI_VALUE=true run_ansible --tags dotfiles
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	grep -qx "ansible-playbook playbook.yml --tags dotfiles" "$LOG" || fail "ran: $(cat "$LOG")"
}

@test "ansible lets Ansible read a password file itself" {
	PASSWORD_FILE="$ROOT/password" run_ansible --check
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	grep -qx "ansible-playbook playbook.yml --check" "$LOG" || fail "ran: $(cat "$LOG")"
}

@test "ansible asks for the sudo password when there's a terminal" {
	command -v python3 >/dev/null || skip "needs python3 for a pseudo-terminal"
	run env -u CI -u ANSIBLE_BECOME_PASSWORD_FILE PATH="$STUB_BIN:$PATH" \
		python3 -c 'import pty, sys; sys.exit(pty.spawn(sys.argv[1:]) >> 8)' \
		"$ROOT/script/ansible" --tags security
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	grep -qx "ansible-playbook playbook.yml --ask-become-pass --tags security" "$LOG" || fail "ran: $(cat "$LOG")"
}

@test "ansible runs without a terminal when sudo needs no password" {
	SUDO_STATUS=0 run_ansible
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	grep -qx "ansible-playbook playbook.yml " "$LOG" || grep -qx "ansible-playbook playbook.yml" "$LOG" ||
		fail "ran: $(cat "$LOG")"
}

@test "ansible refuses, with a hint, when it has no way to get sudo" {
	SUDO_STATUS=1 run_ansible
	[ "$status" -eq 1 ] || fail "exit $status: $output"
	echo "$output" | grep -q "No terminal to prompt" || fail "$output"
	! grep -q '^ansible-playbook' "$LOG" || fail "ran the playbook anyway: $(cat "$LOG")"
}
