#!/usr/bin/env bats
# Verify Comic Sans is suppressed in VS Code via explicit font overrides. (It's
# a protected system font, and Font Book isn't scriptable, so there's no way to
# disable it system-wide from the playbook.)

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
