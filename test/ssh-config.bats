#!/usr/bin/env bats
# Test .ssh/config's 1Password agent fallback with ssh's own resolver
# (`ssh -G`), against a copy whose socket path points into a temp dir. %d is
# the passwd home directory, not $HOME, so the real path can't be faked.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SOCKET_PATH='%d/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock'

setup() {
	command -v ssh >/dev/null || skip "needs ssh"
	command -v python3 >/dev/null || skip "needs python3 to make a socket"
	TMP="$(mktemp -d)"
	SOCK="$TMP/agent.sock"
	grep -qF "$SOCKET_PATH" "$REPO_ROOT/.ssh/config" ||
		fail ".ssh/config no longer guards the agent with $SOCKET_PATH"
	# Drop the includes (this Mac's own hosts) and let Linux's ssh skip
	# Apple's UseKeychain.
	{
		echo "IgnoreUnknown UseKeychain"
		grep -v '^Include ' "$REPO_ROOT/.ssh/config" |
			awk -v from="$SOCKET_PATH" -v to="$SOCK" '/^Match exec/ { i = index($0, from); $0 = substr($0, 1, i - 1) to substr($0, i + length(from)) } { print }'
	} >"$TMP/config"
}

teardown() {
	rm -rf "$TMP"
}

identity_agent() {
	ssh -F "$TMP/config" -G github.com 2>/dev/null | sed -n 's/^identityagent //p'
}

@test "ssh uses 1Password's agent when its socket exists" {
	python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$SOCK"
	agent=$(identity_agent)
	case "$agent" in
		*2BUA8C4S2C.com.1password/t/agent.sock) ;;
		*) fail "expected the 1Password agent, got '$agent'" ;;
	esac
}

@test "ssh falls back to the system agent without 1Password" {
	agent=$(identity_agent)
	case "$agent" in
		*1password*) fail "expected no 1Password agent without its socket, got '$agent'" ;;
	esac
}
