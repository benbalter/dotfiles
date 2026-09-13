#!/usr/bin/env bats
# Verify Comic Sans is suppressed: VS Code font overrides are set,
# and the disable script is wired into the playbook.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
USER_SETTINGS="$REPO_ROOT/Library/Application Support/Code/User/settings.json"
WORKSPACE_SETTINGS="$REPO_ROOT/.vscode/settings.json"

# Both settings files are JSONC (JSON with comments) -- VS Code's own format.
# yq/JSON.parse choke on the comments, and stripping them with a regex would
# corrupt the "http://..." values these files contain, so parse them properly.
assert_font_overridden() {
	local file="$1" key="$2"
	local value
	value=$("$BATS_TEST_DIRNAME/bin/jsonc-get" "$file" "$key") ||
		fail "$file missing '$key'"
	echo "$value" | grep -qi 'comic sans' && fail "$file '$key' must not include Comic Sans: $value"
	return 0
}

@test "VS Code user settings overrides editor.fontFamily" {
	assert_font_overridden "$USER_SETTINGS" "editor.fontFamily"
}

@test "VS Code user settings overrides terminal.integrated.fontFamily" {
	assert_font_overridden "$USER_SETTINGS" "terminal.integrated.fontFamily"
}

@test "VS Code workspace settings overrides editor.fontFamily" {
	assert_font_overridden "$WORKSPACE_SETTINGS" "editor.fontFamily"
}

@test "VS Code workspace settings overrides terminal.integrated.fontFamily" {
	assert_font_overridden "$WORKSPACE_SETTINGS" "terminal.integrated.fontFamily"
}

@test "playbook.yml references the disable-comic-sans script" {
	grep -q 'script/disable-comic-sans' "$REPO_ROOT/playbook.yml" \
		|| fail "playbook.yml does not invoke script/disable-comic-sans"
}
