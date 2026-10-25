#!/usr/bin/env bats
# script/chrome-policy, with `gam` and `op` stubbed to log their calls.

load test_helper
bats_require_minimum_version 1.5.0 # for `run !`

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
# What's set on the org unit, written to the redirect file: \$STORE/live.csv if
# a test wrote one, else none. The noise on stdout is what real GAM prints when
# it initializes a fresh GAMCFGDIR.
if [ "\$1 \$2 \$4 \$5" = "redirect csv print chromepolicies" ]; then
	echo "Created: \$GAMCFGDIR/gamcache"
	cat "$STORE/live.csv" 2>/dev/null >"\$3" || echo 'name,orgUnitPath,parentOrgUnitPath,direct,JSON' >"\$3"
fi
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
     "fields": {"name": "Two words"}},
    {"name": "Turn off", "schema": "chrome.users.Flag",
     "fields": {"flagEnabled": false}}
  ]
}
JSON
}

teardown() {
	rm -rf "$STUB_BIN" "$STORE"
}

# live <policy JSON>...: the policies gam reports as set directly on /Me, in
# the CSV that `gam print chromepolicies ... formatjson` prints.
live() {
	echo 'name,orgUnitPath,parentOrgUnitPath,direct,JSON' >"$STORE/live.csv"
	for j; do
		printf 'x,/Me,/Me,True,"%s"\n' "$(printf %s "$j" | sed 's/"/""/g')" >>"$STORE/live.csv"
	done
}

# The live JSON for each policy in the test file, as already applied.
BLOCK_ONE='{"name": "chrome.users.apps.InstallType", "direct": true, "additionalTargetKeys": [{"name": "app_id", "value": "chrome:abc"}], "fields": [{"name": "appInstallType", "value": "BLOCKED"}]}'
SEARCH='{"name": "chrome.users.Example", "direct": true, "fields": [{"name": "name", "value": "Two words"}]}'
FLAG='{"name": "chrome.users.Flag", "direct": true, "fields": [{"name": "flagEnabled", "value": false}, {"name": "flagPolicyMode", "value": "POLICY_MODE_MANDATORY"}]}'

run_policy() {
	run env PATH="$STUB_BIN:$PATH" CHROME_POLICIES="$STORE/policies.json" \
		"$REPO_ROOT/script/chrome-policy" "$@"
}

@test "chrome-policy applies each policy, with app IDs and quoted values" {
	run_policy
	[ "$status" -eq 0 ]
	grep -qx 'gam update chromepolicy chrome.users.apps.InstallType appInstallType BLOCKED ou /Me appid chrome:abc' "$STORE/calls"
	grep -qx 'gam update chromepolicy chrome.users.Example name Two words ou /Me' "$STORE/calls"
	grep -qx 'gam update chromepolicy chrome.users.Flag flagEnabled false ou /Me' "$STORE/calls"
}

@test "chrome-policy leaves matching policies alone and changes the rest" {
	live "${BLOCK_ONE/BLOCKED/ALLOWED}" "$SEARCH" "$FLAG"
	run_policy
	[ "$status" -eq 0 ]
	[[ "$output" == *"Change Block one"* ]]
	grep -qx 'gam update chromepolicy chrome.users.apps.InstallType appInstallType BLOCKED ou /Me appid chrome:abc' "$STORE/calls"
	run ! grep -q 'gam update chromepolicy chrome.users.Example' "$STORE/calls"
	run ! grep -q 'gam update chromepolicy chrome.users.Flag' "$STORE/calls"
}

@test "chrome-policy unsets what's on the org unit but not in the file" {
	live "$BLOCK_ONE" "$SEARCH" "$FLAG" "${BLOCK_ONE/chrome:abc/chrome:old}" \
		'{"name": "chrome.users.Stale", "direct": true, "fields": []}'
	run_policy
	[ "$status" -eq 0 ]
	grep -qx 'gam delete chromepolicy chrome.users.apps.InstallType ou /Me appid chrome:old' "$STORE/calls"
	grep -qx 'gam delete chromepolicy chrome.users.Stale ou /Me' "$STORE/calls"
	run ! grep -q 'gam update chromepolicy' "$STORE/calls"
}

@test "chrome-policy ignores policies the org unit only inherits" {
	live "$BLOCK_ONE" "$SEARCH" "$FLAG" '{"name": "chrome.users.FromRoot", "direct": false, "fields": []}'
	run_policy --check
	[ "$status" -eq 0 ]
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

@test "chrome-policy stops at the first failed policy and still deletes the credentials" {
	# gam fails only for the first policy's update.
	sed -i.bak 's|^exit 0$|case "$*" in *chrome:abc*) exit 2 ;; esac; exit 0|' "$STUB_BIN/gam"
	run_policy
	[ "$status" -ne 0 ]
	run ! grep -q 'chrome.users.Example' "$STORE/calls"
	[ ! -e "$(cat "$STORE/cfgpath")" ]
}

@test "chrome-policy runs nothing in gam when 1Password can't read the credentials" {
	printf '#!/bin/sh\necho "op $*" >>"%s/calls"\nexit 1\n' "$STORE" >"$STUB_BIN/op"
	run_policy
	[ "$status" -ne 0 ]
	run ! grep -q '^gam ' "$STORE/calls"
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

@test "chrome-policy --check lists drift and exits 1 without writing" {
	live "$SEARCH" "${BLOCK_ONE/chrome:abc/chrome:old}"
	run_policy --check
	[ "$status" -eq 1 ]
	[[ "$output" == *"would Set Block one"* ]]
	[[ "$output" == *"would Set Turn off"* ]]
	[[ "$output" == *"would Unset chrome.users.apps.InstallType chrome:old"* ]]
	[[ "$output" != *"Set search"* ]]
	run ! grep -q -E 'gam (update|create|delete)' "$STORE/calls"
}

@test "chrome-policy --check passes when the org unit matches, ignoring default fields" {
	live "$BLOCK_ONE" "$SEARCH" "$FLAG"
	run_policy --check
	[ "$status" -eq 0 ]
	[[ "$output" == *"/Me matches"* ]]
}

@test "the repo's policies.json parses and every entry has a name and schema" {
	jq -e '.orgunit != "/" and .user and (.policies | all(.name and .schema and .fields))' \
		"$REPO_ROOT/chrome/policies.json"
}
