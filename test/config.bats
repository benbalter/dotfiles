#!/usr/bin/env bats
# Validate configuration files and cross-reference dotfile inventories.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "config.yml dotfiles_files all exist in the repo" {
	for list in dotfiles_files_common dotfiles_files_macos dotfiles_files_linux; do
		while IFS= read -r file; do
			[ -e "$REPO_ROOT/$file" ] || fail "$list entry '$file' does not exist in repo"
		done < <(yq -r ".${list}[]" "$REPO_ROOT/config.yml")
	done
}

@test "config.yml dotfile link sources all exist in the repo" {
	for list in dotfile_links_common linux_dotfile_links; do
		while IFS= read -r file; do
			[ -e "$REPO_ROOT/$file" ] || fail "$list src '$file' does not exist in repo"
		done < <(yq -r ".${list}[].src" "$REPO_ROOT/config.yml")
	done
}

@test "config.yml has required top-level keys" {
	for key in dotfiles_files dotfiles_files_common dotfiles_files_macos \
		dotfiles_files_linux dotfile_links_common linux_dotfile_links fedora_packages \
		directories_to_create private_directories macos_defaults; do
		grep -q "^${key}:" "$REPO_ROOT/config.yml" || fail "config.yml missing required key '$key'"
	done
}

@test "config.yml macos_defaults entries have required fields" {
	for section in system user; do
		count=$(yq ".macos_defaults.$section | length" "$REPO_ROOT/config.yml")
		for i in $(seq 0 $((count - 1))); do
			name=$(yq ".macos_defaults.${section}[$i].name" "$REPO_ROOT/config.yml")
			for field in domain key type value; do
				val=$(yq ".macos_defaults.${section}[$i].$field" "$REPO_ROOT/config.yml")
				[ "$val" != "null" ] || fail "macos_defaults.$section entry '$name' missing '$field'"
			done
		done
	done
}

@test "config_ci.yml is valid YAML" {
	yq '.' "$REPO_ROOT/config_ci.yml" >/dev/null
}

@test "directories_to_create entries use tilde paths" {
	for list in directories_to_create_common directories_to_create_macos \
		directories_to_create_linux; do
		count=$(yq ".${list} | length" "$REPO_ROOT/config.yml")
		for i in $(seq 0 $((count - 1))); do
			dir=$(yq ".${list}[$i]" "$REPO_ROOT/config.yml")
			echo "$dir" | grep -q '^~/' || fail "directory '$dir' should use ~/ prefix"
		done
	done
}

@test "claude/settings.json is valid JSON without machine-only keys" {
	# Merged into ~/.claude/settings.json by the playbook. This repo is public,
	# so autoMode (which names private hosts) and permissions must stay local.
	jq -e 'has("autoMode") or has("permissions") | not' "$REPO_ROOT/claude/settings.json" >/dev/null ||
		fail "claude/settings.json must not contain autoMode or permissions"
}

@test "private_directories are all created by directories_to_create" {
	# The playbook sets these to 0700; a private dir missing from
	# directories_to_create would only ever be created 0755 by a dotfile task.
	while IFS= read -r dir; do
		# shellcheck disable=SC2088 # a literal ~/ path, as config.yml spells it
		yq -r '.directories_to_create_common[]' "$REPO_ROOT/config.yml" | grep -qxF "~/$dir" ||
			fail "private directory '$dir' is not in directories_to_create_common"
	done < <(yq -r '.private_directories[]' "$REPO_ROOT/config.yml")
}

@test "launch agent labels match their filenames" {
	# The playbook derives each agent's launchd label from its filename to
	# check whether it is loaded before bootstrapping it.
	while IFS= read -r file; do
		label=$(sed -n '/<key>Label<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' "$REPO_ROOT/$file")
		[ "$label" = "$(basename "$file" .plist)" ] ||
			fail "$file has Label '$label'; it must match the filename"
	done < <(yq -r '.dotfiles_files_macos[] | select(test("^Library/LaunchAgents/"))' "$REPO_ROOT/config.yml")
}

@test "macos_defaults host entries only use currentHost" {
	# The playbook reads these back with `defaults -currentHost`.
	while IFS= read -r host; do
		[ "$host" = "currentHost" ] || fail "unsupported macos_defaults host '$host'"
	done < <(yq -r '.macos_defaults.user[] | select(has("host")) | .host' "$REPO_ROOT/config.yml")
}

@test "macos_defaults system entries use absolute domain paths" {
	# These run with become: true, so a bare domain (com.apple.foo) writes to
	# root's preferences and does nothing while the task reports success.
	while IFS=$'\t' read -r name domain; do
		case "$domain" in
			/*) ;;
			*) fail "macos_defaults.system '$name' uses bare domain '$domain'; use /Library/Preferences/$domain" ;;
		esac
	done < <(yq -r '.macos_defaults.system[] | [.name, .domain] | @tsv' "$REPO_ROOT/config.yml")
}

@test "claude/settings.json plugins come from a known marketplace" {
	# The playbook runs `claude plugin install` for each enabled plugin, which
	# fails unless its marketplace is the official one or declared here. The
	# playbook skips this in CI, so check it statically.
	while IFS= read -r plugin; do
		marketplace=${plugin#*@}
		[ "$marketplace" = claude-plugins-official ] && continue
		jq -e --arg m "$marketplace" '.extraKnownMarketplaces | has($m)' \
			"$REPO_ROOT/claude/settings.json" >/dev/null ||
			fail "$plugin: marketplace '$marketplace' is not in extraKnownMarketplaces"
	done < <(jq -r '.enabledPlugins | keys[]' "$REPO_ROOT/claude/settings.json")
}

@test "launch agent plists are valid" {
	command -v plutil >/dev/null || skip "plutil is macOS-only"
	for plist in "$REPO_ROOT"/Library/LaunchAgents/*.plist; do
		plutil -lint "$plist" >/dev/null || fail "$(basename "$plist") is not a valid plist"
	done
}
