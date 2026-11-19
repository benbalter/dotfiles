#!/usr/bin/env bats
# Sign a real commit the way a work Mac does (playbook.yml's "Sign commits on
# a work Mac with its local key" task): gpg.ssh.program = ssh-keygen and
# user.signingkey = the public key, with the private key only in an agent.
# A private agent and a scratch git config keep the host's keys out of it.

load test_helper

setup() {
	command -v ssh-agent >/dev/null || skip "needs ssh-agent"
	TMP="$(mktemp -d)"
	eval "$(ssh-agent -a "$TMP/agent.sock")" >/dev/null
	ssh-keygen -q -t ed25519 -N '' -C test -f "$TMP/sign" || fail "ssh-keygen failed"
	export GIT_CONFIG_GLOBAL="$TMP/gitconfig" GIT_CONFIG_NOSYSTEM=1
	cat >"$GIT_CONFIG_GLOBAL" <<CONFIG
[user]
	name = Test
	email = test@example.com
	signingkey = $TMP/sign.pub
[gpg]
	format = ssh
[gpg "ssh"]
	program = ssh-keygen
	allowedSignersFile = $TMP/allowed_signers
[commit]
	gpgSign = true
CONFIG
	echo "test@example.com $(cat "$TMP/sign.pub")" >"$TMP/allowed_signers"
	git init -q "$TMP/repo"
}

teardown() {
	[ -z "${SSH_AGENT_PID:-}" ] || kill "$SSH_AGENT_PID" 2>/dev/null || true
	rm -rf "$TMP"
}

@test "a work Mac's signing config signs commits through the agent" {
	ssh-add -q "$TMP/sign" 2>/dev/null || fail "ssh-add failed"
	# Only the agent holds the private key now.
	mv "$TMP/sign" "$TMP/sign.moved"
	git -C "$TMP/repo" commit -q --allow-empty -m signed || fail "commit failed to sign"
	run git -C "$TMP/repo" verify-commit HEAD
	[ "$status" -eq 0 ] || fail "signature didn't verify: $output"
}

@test "a work Mac's signing config fails to sign with an empty agent" {
	mv "$TMP/sign" "$TMP/sign.moved"
	run git -C "$TMP/repo" commit -q --allow-empty -m unsigned
	[ "$status" -ne 0 ] || fail "expected the commit to fail without the key in the agent"
}
