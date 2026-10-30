#!/usr/bin/env bats
# Test script/audit-baseline against a fake mSCP checkout and config, offline,
# so the result never depends on the network or this Mac's settings.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	command -v zsh >/dev/null || skip "mSCP checks run under zsh"
	TMP="$(mktemp -d)"
	MSCP="$TMP/cache/dotfiles/mscp"
	mkdir -p "$MSCP/baselines" "$MSCP/rules/os"
	git -C "$MSCP" init -q && git -C "$MSCP" -c user.name=t -c user.email=t@example.com \
		-c commit.gpgsign=false commit -q --allow-empty -m fake
	cat >"$MSCP/baselines/test.yaml" <<'YAML'
profile:
  - section: one
    rules: [ok_rule, bad_rule, writes_rule, root_rule, audit_one, setting_rule, odv_rule, supplemental_note]
YAML
	rule() { printf 'id: %s\ncheck: |\n  %s\nresult:\n  %s\n' "$1" "$2" "$3" >"$MSCP/rules/os/$1.yaml"; }
	rule ok_rule 'echo pass' 'string: pass'
	rule bad_rule 'echo fail' 'string: pass'
	# A write the refusal must catch, aimed at a temp file so a regression
	# can't touch real settings: chmod is on the refused list.
	touch "$TMP/marker" && chmod 644 "$TMP/marker"
	rule writes_rule "chmod 600 $TMP/marker; echo 1" 'integer: 1'
	rule root_rule 'sudo true; echo 1' 'integer: 1'
	rule audit_one 'echo nope' 'integer: 1'
	rule setting_rule 'echo from-profile' 'integer: 1'
	# shellcheck disable=SC2016 # a literal $ODV, which the script substitutes
	printf 'id: odv_rule\ncheck: |\n  echo 15\nresult:\n  integer: $ODV\nodv:\n  recommended: 12\n  test: 15\n' >"$MSCP/rules/os/odv_rule.yaml"
	printf 'id: supplemental_note\ncheck:\nresult:\n' >"$MSCP/rules/os/supplemental_note.yaml"
	cat >"$TMP/config.yml" <<'YAML'
macos_security_settings:
  - name: Pretend setting
    check: echo it is on
    expect: it is on
    set: "true"
audit_baseline:
  branch: test
  macos: 99
  baseline: test
  overrides:
    setting_rule: {setting: Pretend setting}
  exceptions:
    "audit_*": not here
YAML
}

teardown() {
	rm -rf "$TMP"
}

audit() {
	run env XDG_CACHE_HOME="$TMP/cache" AUDIT_BASELINE_CONFIG="$TMP/config.yml" \
		"$REPO_ROOT/script/audit-baseline" --offline --verbose
}

@test "audit-baseline sorts rules into pass, fail, excepted, refused, needs root and manual" {
	audit
	[ "$status" -eq 1 ] || fail "a failing rule should exit 1: $output"
	for want in "PASS       ok_rule" "FAIL       bad_rule" "REFUSED    writes_rule" \
		"NEEDS ROOT root_rule" "EXCEPTED   audit_one  (not here)" "PASS       setting_rule  (override)" \
		"PASS       odv_rule" "MANUAL     supplemental_note"; do
		echo "$output" | grep -qF "$want" || fail "missing '$want': $output"
	done
	echo "$output" | grep -q "pass 3, fail 1, excepted 1, needs root 1, manual 1, refused 1, error 0" || fail "$output"
}

@test "audit-baseline never runs a check that would write" {
	audit
	[ "$(stat -f %Lp "$TMP/marker" 2>/dev/null || stat -c %a "$TMP/marker")" = 644 ] || fail "a refused check ran"
}

@test "audit-baseline exits 0 when nothing fails" {
	printf 'id: bad_rule\ncheck: |\n  echo pass\nresult:\n  string: pass\n' >"$MSCP/rules/os/bad_rule.yaml"
	audit
	[ "$status" -eq 0 ] || fail "$output"
}

@test "the repo's audit overrides name real settings and every exception has a reason" {
	config="$REPO_ROOT/config.yml"
	for name in $(yq -r '.audit_baseline.overrides[] | select(.setting) | .setting | @base64' "$config"); do
		setting=$(echo "$name" | base64 -d)
		yq -e ".macos_security_settings[] | select(.name == \"$setting\")" "$config" >/dev/null ||
			fail "override names a setting that doesn't exist: $setting"
	done
	bad=$(yq -r '.audit_baseline.overrides | to_entries[] | select((.value.setting == null) and ((.value.check == null) or (.value.expect == null))) | .key' "$config")
	[ -z "$bad" ] || fail "override needs setting, or check and expect: $bad"
	bad=$(yq -r '.audit_baseline.exceptions | to_entries[] | select((.value // "") == "") | .key' "$config")
	[ -z "$bad" ] || fail "exception without a reason: $bad"
}
