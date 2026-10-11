#!/usr/bin/env bats
# script/app-preferences, with `defaults` stubbed to keep each domain as a file.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	STUB_BIN="$(mktemp -d)"
	STORE="$(mktemp -d)"
	PREFS="$(mktemp -d)"
	# Every call is logged, so tests can tell a no-op run from a write.
	cat >"$STUB_BIN/defaults" <<STUB
#!/bin/sh
echo "\$*" >>"$STORE/calls"
f="$STORE/\$2.plist"
case "\$1" in
	export)
		[ -f "\$f" ] || { echo "Domain \$2 does not exist" >&2; exit 1; }
		cat "\$f"
		;;
	import) cat >"\$f" ;;
esac
STUB
	chmod +x "$STUB_BIN/defaults"
	# A fragment with a flat value, a nested array and a key with a dot in it.
	python3 -I -c '
import plistlib, sys
plistlib.dump({"popupSize": 2, "Order.saved": {"hidden": ["a", "b"]}}, open(sys.argv[1], "wb"))
' "$PREFS/com.example.app.plist"
}

teardown() {
	rm -rf "$STUB_BIN" "$STORE" "$PREFS"
}

run_prefs() {
	run env PATH="$STUB_BIN:$PATH" APP_PREFERENCES_DIR="$PREFS" "$REPO_ROOT/script/app-preferences" "$@"
}

# stored <python expression over `d`, the stored domain>
stored() {
	python3 -I -c "import plistlib, sys; d = plistlib.load(open(sys.argv[1], 'rb')); print($1)" \
		"$STORE/com.example.app.plist"
}

@test "app-preferences creates the domain of an app that has never run" {
	run_prefs
	[ "$status" -eq 0 ] || fail "$output"
	echo "$output" | grep -q "set   com.example.app: Order.saved, popupSize" || fail "$output"
	[ "$(stored 'd["Order.saved"]["hidden"]')" = "['a', 'b']" ] || fail "$(stored d)"
}

@test "app-preferences keeps keys it doesn't manage" {
	python3 -I -c '
import plistlib, sys
plistlib.dump({"popupSize": 1, "activationKey": "keep-me"}, open(sys.argv[1], "wb"))
' "$STORE/com.example.app.plist"
	run_prefs
	[ "$(stored 'd["popupSize"]')" = 2 ] || fail "$(stored d)"
	[ "$(stored 'd["activationKey"]')" = keep-me ] || fail "$(stored d)"
}

@test "app-preferences doesn't write a domain that already matches" {
	run_prefs
	rm "$STORE/calls"
	run_prefs
	echo "$output" | grep -q "ok    com.example.app" || fail "$output"
	! grep -q '^import' "$STORE/calls" || fail "$(cat "$STORE/calls")"
}

@test "app-preferences --check reports drift without writing" {
	run_prefs --check
	[ "$status" -eq 1 ] || fail "expected exit 1, got $status: $output"
	echo "$output" | grep -q "drift com.example.app: Order.saved, popupSize" || fail "$output"
	[ ! -f "$STORE/com.example.app.plist" ] || fail "--check wrote the domain"
}

@test "tracked app preferences hold no window state or secrets" {
	# The repo is public, and window frames churn on every run.
	for frag in "$REPO_ROOT"/app-preferences/*.plist; do
		keys=$(python3 -I -c 'import plistlib, sys; print("\n".join(plistlib.load(open(sys.argv[1], "rb"))))' "$frag")
		! echo "$keys" | grep -Eiq 'activation|license|token|password|cloud|NSWindow Frame|NSStatusItem' ||
			fail "$frag tracks a key it shouldn't: $keys"
	done
}
