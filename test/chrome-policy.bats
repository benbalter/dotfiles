#!/usr/bin/env bats
# script/chrome-policy, with `gam` and `op` stubbed to log their calls.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	STUB_BIN="$(mktemp -d)"
	STORE="$(mktemp -d)"
	# gam also records which credential files it found in GAMCFGDIR, to show
	# they were there while it ran.
	cat >"$STUB_BIN/gam" <<STUB
#!/bin/sh
echo "gam \$*" >>"$STORE/calls"
ls "\$GAMCFGDIR" >"$STORE/cfgdir"
echo "\$GAMCFGDIR" >"$STORE/cfgpath"
# With NO_OU set, the org unit doesn't exist yet.
[ "\$1 \$2" = "info org" ] && [ -n "\${NO_OU:-}" ] && exit 1
exit 0
STUB
	cat >"$STUB_BIN/op" <<STUB
#!/bin/sh
echo "op \$*" >>"$STORE/calls"
[ "\$1" = read ] && echo secret >"\$4"
exit 0
STUB
	chmod +x "$STUB_BIN/gam" "$STUB_BIN/op"
	cat >"$STORE/policies.json" <<'JSON'
{
  "orgunit": "/Me",
  "user": "me@example.com",
  "policies": [
    {"name": "Block one", "schema": "chrome.users.apps.InstallType",
     "appid": "chrome:abc", "fields": {"appInstallType": "BLOCKED"}},
    {"name": "Set search", "schema": "chrome.users.Example",
     "fields": {"name": "Two words"}}
  ]
}
JSON
}

teardown() {
	rm -rf "$STUB_BIN" "$STORE"
}

run_policy() {
	run env PATH="$STUB_BIN:$PATH" CHROME_POLICIES="$STORE/policies.json" \
		"$REPO_ROOT/script/chrome-policy" "$@"
}

@test "chrome-policy applies each policy, with app IDs and quoted values" {
	run_policy
	[ "$status" -eq 0 ]
	grep -qx 'gam update chromepolicy chrome.users.apps.InstallType appInstallType BLOCKED ou /Me appid chrome:abc' "$STORE/calls"
	grep -qx 'gam update chromepolicy chrome.users.Example name Two words ou /Me' "$STORE/calls"
}

@test "chrome-policy moves the user into the org unit, creating it only if missing" {
	run_policy
	[ "$status" -eq 0 ]
	run ! grep -q 'gam create org' "$STORE/calls"
	grep -qx 'gam update org /Me add users me@example.com' "$STORE/calls"

	run env NO_OU=1 PATH="$STUB_BIN:$PATH" CHROME_POLICIES="$STORE/policies.json" \
		"$REPO_ROOT/script/chrome-policy"
	[ "$status" -eq 0 ]
	grep -qx 'gam create org Me' "$STORE/calls"
}

@test "chrome-policy reads credentials from 1Password and deletes them after" {
	run_policy
	[ "$status" -eq 0 ]
	grep -q 'op read --no-newline --out-file .*/oauth2.txt op://Private/GAM/oauth2_txt' "$STORE/calls"
	grep -qx oauth2.txt "$STORE/cfgdir"
	[ ! -e "$(cat "$STORE/cfgpath")" ]
}

@test "chrome-policy --setup refuses to run without a terminal" {
	run_policy --setup </dev/null
	[ "$status" -eq 1 ]
	[[ "$output" == *"run it in a terminal"* ]]
	[ ! -e "$STORE/calls" ]
}

@test "chrome-policy --setup saves each file under a dot-free 1Password field" {
	command -v script >/dev/null || skip "needs script(1) for a pseudo-terminal"
	# script(1) gives the run a pseudo-terminal, as a real terminal would.
	# util-linux's (CI) takes the command via -c; BSD's (macOS) as arguments.
	cmd=(env PATH="$STUB_BIN:$PATH" CHROME_POLICIES="$STORE/policies.json"
		"$REPO_ROOT/script/chrome-policy" --setup)
	if script --version >/dev/null 2>&1; then
		run script -qec "$(printf '%q ' "${cmd[@]}")" /dev/null
	else
		run script -q /dev/null "${cmd[@]}"
	fi
	[ "$status" -eq 0 ]
	grep -q 'op item create --category Secure Note --vault Private --title GAM client_secrets_json\[file\]=.*/client_secrets.json oauth2_txt\[file\]=.*/oauth2.txt oauth2service_json\[file\]=.*/oauth2service.json' "$STORE/calls"
}

@test "chrome-policy --show doesn't write" {
	run_policy --show
	[ "$status" -eq 0 ]
	grep -qx 'gam show chromepolicies ou /Me show direct' "$STORE/calls"
	run ! grep -q 'gam update' "$STORE/calls"
	run ! grep -q 'gam create' "$STORE/calls"
}

@test "the repo's policies.json parses and every entry has a name and schema" {
	jq -e '.orgunit != "/" and .user and (.policies | all(.name and .schema and .fields))' \
		"$REPO_ROOT/chrome/policies.json"
}
