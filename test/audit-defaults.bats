#!/usr/bin/env bats
# Test script/audit-defaults against a fixture config and a fake binary, so the
# result doesn't depend on the host's macOS version.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	command -v rg >/dev/null || skip "needs ripgrep"
	FIXTURE="$(mktemp -d)"
	# Keys sit between NULs, the way a binary's string table stores them.
	printf 'junk\0autohide\0show-recents\0LoginwindowText\0largetilesize\0' >"$FIXTURE/binary"
	export DOTFILES_ROOT="$FIXTURE" AUDIT_DEFAULTS_BINARIES="$FIXTURE/binary $FIXTURE/missing*"
}

teardown() {
	rm -rf "$FIXTURE"
}

write_config() {
	cat >"$FIXTURE/config.yml"
}

@test "audit-defaults passes when every Apple key is in a binary" {
	write_config <<'EOF'
macos_defaults:
  system:
    - {name: a, domain: /Library/Preferences/com.apple.loginwindow, key: LoginwindowText, type: string, value: x}
  user:
    - {name: b, domain: com.apple.dock, key: autohide, type: bool, value: true}
    - {name: c, domain: com.apple.dock, key: show-recents, type: bool, value: false}
EOF
	run "$REPO_ROOT/script/audit-defaults"
	[ "$status" -eq 0 ] || fail "expected success, got $status: $output"
	[[ $output == *"ok    com.apple.loginwindow LoginwindowText"* ]] || fail "absolute domain not shortened: $output"
}

@test "audit-defaults flags a key no binary contains" {
	write_config <<'EOF'
macos_defaults:
  system: []
  user:
    - {name: b, domain: com.apple.dock, key: autohide, type: bool, value: true}
    - {name: c, domain: com.apple.desktopservices, key: DSDontWriteUSBStores, type: bool, value: true}
EOF
	run "$REPO_ROOT/script/audit-defaults"
	[ "$status" -eq 1 ] || fail "expected exit 1, got $status: $output"
	[[ $output == *"dead? com.apple.desktopservices DSDontWriteUSBStores"* ]] || fail "missing key not flagged: $output"
}

@test "audit-defaults matches whole keys only" {
	write_config <<'EOF'
macos_defaults:
  system: []
  user:
    - {name: b, domain: com.apple.dock, key: autohide, type: bool, value: true}
    - {name: c, domain: com.apple.dock, key: tilesize, type: float, value: 64}
EOF
	run "$REPO_ROOT/script/audit-defaults"
	[[ $output == *"dead? com.apple.dock tilesize"* ]] || fail "tilesize matched inside largetilesize: $output"
}

@test "audit-defaults ignores third-party domains" {
	write_config <<'EOF'
macos_defaults:
  system: []
  user:
    - {name: b, domain: com.apple.dock, key: autohide, type: bool, value: true}
    - {name: c, domain: com.example.app, key: BuiltAtRuntime, type: bool, value: true}
EOF
	run "$REPO_ROOT/script/audit-defaults"
	[ "$status" -eq 0 ] || fail "third-party key was audited: $output"
}
