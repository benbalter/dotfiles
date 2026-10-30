#!/usr/bin/env bats
# Test script/firewall-extras against a stubbed socketfilterfw and a test
# config, so the result never depends on the host's firewall or apps.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	TMP="$(mktemp -d)"
	# Apps that exist, so only the allowlist decides; one is gone.
	mkdir -p "$TMP/Kept.app/Contents/Helper.app" "$TMP/Extra App.app" "$TMP/Blocked.app"
	cat >"$TMP/config.yml" <<YAML
firewall_allowed_apps:
  - $TMP/Kept.app
YAML
	cat >"$TMP/socketfilterfw" <<STUB
#!/bin/sh
cat <<'OUT'
Total number of apps = 6 
1 : /System/Library/CoreServices/UniversalControl.app/Contents/MacOS/UniversalControl 
             (Allow incoming connections)
2 : /usr/libexec/rapportd 
             (Allow incoming connections)
3 : $TMP/Kept.app/Contents/Helper.app 
             (Allow incoming connections)
4 : $TMP/Extra App.app 
             (Allow incoming connections)
5 : $TMP/Blocked.app 
             (Block incoming connections)
6 : $TMP/Gone.app 
             (Block incoming connections)
OUT
STUB
	chmod +x "$TMP/socketfilterfw"
}

teardown() {
	rm -rf "$TMP"
}

@test "firewall-extras lists unlisted allows and missing apps only" {
	run env SOCKETFILTERFW="$TMP/socketfilterfw" FIREWALL_CONFIG="$TMP/config.yml" \
		"$REPO_ROOT/script/firewall-extras"
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	expected="$TMP/Extra App.app
$TMP/Gone.app"
	[ "$output" = "$expected" ] || fail "got: $output"
}

@test "the repo's firewall allowlist only names apps outside macOS's own directories" {
	! yq -r '.firewall_allowed_apps[]' "$REPO_ROOT/config.yml" | grep -E '^/(System|usr/libexec|usr/sbin)/' ||
		fail "macOS's own binaries are never removed, so listing them does nothing"
}
