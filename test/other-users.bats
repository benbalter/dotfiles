#!/usr/bin/env bats
# Test script/other-users against a stubbed directory service, so the result
# never depends on the host's accounts.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	STUB_BIN="$(mktemp -d)"
	cat >"$STUB_BIN/id" <<'STUB'
#!/bin/sh
echo me
STUB
	# Every account a real Mac might have: this one, a second person, a
	# system account, a service account without a shell, and a hidden one.
	cat >"$STUB_BIN/dscl" <<'STUB'
#!/bin/sh
case "$2 $4" in
"list UniqueID") printf '%s\n' "_www 70" "me 501" "partner 503" "agent 504" "hidden 505" ;;
"read UserShell")
	case "$3" in
	/Users/agent) echo "UserShell: /usr/bin/false" ;;
	*) echo "UserShell: /bin/zsh" ;;
	esac
	;;
"read IsHidden") [ "$3" = /Users/hidden ] && echo "IsHidden: 1" || exit 1 ;;
esac
STUB
	chmod +x "$STUB_BIN/id" "$STUB_BIN/dscl"
}

teardown() {
	rm -rf "$STUB_BIN"
}

@test "other-users lists only other people's logins" {
	run env PATH="$STUB_BIN:$PATH" "$REPO_ROOT/script/other-users"
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	[ "$output" = partner ] || fail "expected only partner, got: $output"
}
