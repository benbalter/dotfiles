#!/usr/bin/env bats
# Validate configuration files and cross-reference dotfile inventories.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "config.yml dotfiles_files all exist in the repo" {
	for list in dotfiles_files_common dotfiles_files_macos; do
		while IFS= read -r file; do
			[ -e "$REPO_ROOT/$file" ] || fail "$list entry '$file' does not exist in repo"
		done < <(yq -r ".${list}[]" "$REPO_ROOT/config.yml")
	done
}

@test "config.yml dotfile link sources all exist in the repo" {
	while IFS= read -r file; do
		[ -e "$REPO_ROOT/$file" ] || fail "dotfile_links_common src '$file' does not exist in repo"
	done < <(yq -r '.dotfile_links_common[].src' "$REPO_ROOT/config.yml")
}

@test "config.yml has required top-level keys" {
	for key in dotfiles_files dotfiles_files_common dotfiles_files_macos \
		dotfile_links_common directories_to_create private_directories macos_defaults; do
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

@test "directories_to_create entries use tilde paths" {
	for list in directories_to_create_common directories_to_create_macos; do
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

@test ".npmrc has no literal credentials" {
	# ~/.npmrc links into this public repo, and `npm login` writes its token
	# there. Credentials must come from ${ENV_VARS} instead.
	! grep -En '(_authToken|_auth|_password)=[^$]' "$REPO_ROOT/.npmrc" ||
		fail ".npmrc contains a literal credential; use \${NPM_TOKEN?} instead"
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

@test ".gitconfig leaves signing and credential helpers to .gitconfig.macos" {
	# Set in the shared .gitconfig, they overrode Codespaces' own signing and
	# credentials, and every commit there failed.
	keys=$(git config -f "$REPO_ROOT/.gitconfig" --name-only --list |
		grep -iE '^(commit\.gpgsign|tag\.gpgsign|user\.signingkey|gpg\.format|gpg\.([a-z0-9]+\.)?program|credential\.)') || true
	[ -z "$keys" ] || fail ".gitconfig sets macOS-only keys: $keys"
}

@test "Brewfile has no npm entries" {
	# Global npm CLIs belong in mise: Brewfile npm entries ran into Workbrew's
	# workbrew-owned node prefix and failed with EACCES.
	! grep -nE '^[[:space:]]*npm[[:space:]]' "$REPO_ROOT/Brewfile" ||
		fail "move these to npm: entries in .config/mise/config.toml"
}

@test "claude/CLAUDE.md and preferences.md links are full URLs" {
	# Both are read through symlinks in ~/.claude, where a relative link
	# resolves against the wrong directory, and preferences.md is also pasted
	# into claude.ai, which can't resolve one at all. Code spans hold examples,
	# not links.
	for file in claude/CLAUDE.md claude/preferences.md; do
		# shellcheck disable=SC2016
		links=$(sed 's/`[^`]*`//g' "$REPO_ROOT/$file" |
			grep -oE '\]\([^)]*\)' | grep -vE '^\]\(https?://') || true
		[ -z "$links" ] || fail "relative links in $file: $links"
	done
}

@test "claude/preferences.md is linked into Claude Code's user rules" {
	# Claude Code loads ~/.claude/rules/*.md every session; this link is the
	# only way the shared preferences reach it. Without it they'd silently
	# apply to claude.ai alone.
	yq -e '.dotfile_links_common[] | select(.src == "claude/preferences.md" and .dest == ".claude/rules/preferences.md")' \
		"$REPO_ROOT/config.yml" >/dev/null || fail "config.yml must link claude/preferences.md to ~/.claude/rules/preferences.md"
}

@test "the shorthand slash commands are linked for Claude Code and OpenCode" {
	# claude-code.ts loads ~/.claude/commands into OpenCode, so this one link
	# gives both agents /cpm, /opr, /mag and /gb.
	yq -e '.dotfile_links_common[] | select(.src == "claude/commands" and .dest == ".claude/commands")' \
		"$REPO_ROOT/config.yml" >/dev/null || fail "config.yml must link claude/commands to ~/.claude/commands"
	grep -q 'link claude/commands .claude/commands' "$REPO_ROOT/install.sh" || fail "install.sh must link claude/commands"
	for command in cpm opr mag gb; do
		[ -f "$REPO_ROOT/claude/commands/$command.md" ] || fail "missing claude/commands/$command.md"
	done
}

@test "OpenCode loads the same global instructions as Claude Code" {
	# OpenCode never looks in ~/.claude/rules, so preferences.md needs the
	# instructions entry. Since 2.3.1 it also falls back to ~/.claude/CLAUDE.md
	# when the global AGENTS.md is missing, but that fallback was dropped once
	# before (v2.0) and restored only in 2.3.1, so the explicit link keeps the
	# global rules from depending on it.
	yq -e '.dotfile_links_common[] | select(.src == "claude/CLAUDE.md" and .dest == ".config/opencode/AGENTS.md")' \
		"$REPO_ROOT/config.yml" >/dev/null || fail "config.yml must link claude/CLAUDE.md to ~/.config/opencode/AGENTS.md"
	jq -e '.instructions | index("~/.claude/rules/preferences.md")' \
		"$REPO_ROOT/.config/opencode/opencode.json" >/dev/null || fail "opencode.json must load ~/.claude/rules/preferences.md"
}

@test "OpenCode keeps sessions private and leaves upgrades to brew" {
	# Shared sessions publish a transcript, and self-update would fight the
	# Brewfile's opencode formula, which script/update upgrades.
	jq -e '.share == "disabled" and .update == "disable"' \
		"$REPO_ROOT/.config/opencode/opencode.json" >/dev/null ||
		fail "opencode.json must set share to disabled and update to disable"
	# V2 ignores or remaps these v1 keys, so a setting under one silently lapses.
	jq -e 'has("autoupdate") or has("autoshare") or has("permission") or has("plugin") or has("mode") | not' \
		"$REPO_ROOT/.config/opencode/opencode.json" >/dev/null || fail "opencode.json uses a deprecated v1 key"
}

@test "OpenCode takes plugins and MCP servers from Claude Code, not copies" {
	# claude-code.ts mirrors enabled Claude Code plugins' skills and MCP servers,
	# plus ~/.claude.json's, at runtime. A hand-written skills or mcp block here
	# would be a second copy that drifts from Claude Code.
	jq -e 'has("skills") or has("mcp") | not' "$REPO_ROOT/.config/opencode/opencode.json" >/dev/null ||
		fail "opencode.json must leave skills and MCP servers to plugins/claude-code.ts"
}

@test "OpenCode's claude-code plugin is linked and reads Claude Code's config" {
	# OpenCode doesn't read Claude Code's hooks, plugins or MCP servers itself,
	# so without this plugin guard-bash's rules and those tools skip it.
	plugin=.config/opencode/plugins/claude-code.ts
	yq -e ".dotfiles_files_common[] | select(. == \"$plugin\")" "$REPO_ROOT/config.yml" >/dev/null ||
		fail "config.yml must link $plugin"
	grep -q "$plugin" "$REPO_ROOT/install.sh" || fail "install.sh must link $plugin"
	for source in PreToolUse enabledPlugins installed_plugins.json mcpServers tool_input; do
		grep -q "$source" "$REPO_ROOT/$plugin" || fail "$plugin must read $source"
	done
}

# shellcheck disable=SC2016 # the grep patterns match a literal $
@test "OpenCode and Claude Code share a plans folder" {
	# OpenCode's plan agent writes to ~/.opencode/plan, which nothing backs up
	# and Claude Code never sees; both installers point it at ~/.claude/plans.
	grep -q 'ln -sfn "$plans" "$dest"' "$REPO_ROOT/playbook.yml" ||
		fail "playbook.yml must link ~/.opencode/plan to ~/.claude/plans"
	grep -q 'ln -sfn "$HOME/.claude/plans" "$HOME/.opencode/plan"' "$REPO_ROOT/install.sh" ||
		fail "install.sh must link ~/.opencode/plan to ~/.claude/plans"
}

@test "macos_defaults all_users entries don't use this account's home" {
	# all_users entries are also written for other local logins, where
	# user_dir would point at the playbook runner's home instead of theirs.
	! yq -r '.macos_defaults.user[] | select(.all_users) | .value' "$REPO_ROOT/config.yml" | grep -q user_dir ||
		fail "an all_users default templates user_dir"
}

@test "macos_security_settings entries are complete and their patterns work in grep and Python" {
	# The playbook matches with Python's re (Ansible's search test) and doctor
	# with grep -E, so a pattern must mean the same to both.
	yq -e '.macos_security_settings | length > 0' "$REPO_ROOT/config.yml" >/dev/null || fail "no settings"
	bad=$(yq -r '.macos_security_settings[] | select((.name and .check and .set) | not) | .name // "unnamed"' "$REPO_ROOT/config.yml")
	[ -z "$bad" ] || fail "missing name, check or set: $bad"
	bad=$(yq -r '.macos_security_settings[] | select(((.expect != null) and (.reject != null)) or ((.expect == null) and (.reject == null))) | .name' "$REPO_ROOT/config.yml")
	[ -z "$bad" ] || fail "need exactly one of expect or reject: $bad"
	while IFS= read -r pattern; do
		[ "$pattern" != - ] || fail "a pattern of just - would read as empty in script/doctor"
		rc=0
		echo x | grep -Eq "$pattern" 2>/dev/null || rc=$?
		[ "$rc" -le 1 ] || fail "grep -E rejects: $pattern"
		python3 -c 'import re, sys; re.compile(sys.argv[1])' "$pattern" || fail "Python rejects: $pattern"
		case "$pattern" in *'[['*) fail "POSIX classes don't work in Python: $pattern" ;; esac
	done < <(yq -r '.macos_security_settings[] | (.expect // .reject)' "$REPO_ROOT/config.yml")
}

@test "every claude/skills directory is linked by config.yml" {
	# A skill dir with no link never reaches ~/.claude/skills, and nothing else
	# notices: Claude Code just doesn't list it. install.sh is checked against
	# this same list by install.bats.
	expected=$(cd "$REPO_ROOT" && find claude/skills -mindepth 1 -maxdepth 1 -type d | sort)
	linked=$(yq -r '.dotfile_links_common[].src | select(test("^claude/skills/"))' "$REPO_ROOT/config.yml" | sort)
	[ "$expected" = "$linked" ] ||
		fail "claude/skills dirs and config.yml links differ: $(diff <(echo "$expected") <(echo "$linked"))"
}

@test "claude/skills SKILL.md files have the frontmatter Claude Code needs" {
	# Limits from the Agent Skills spec (https://agentskills.io/specification),
	# which claude.ai uploads and the Skills API validate; Claude Code itself
	# only truncates long descriptions in its skill listing. The description is
	# all Claude sees when deciding to load a skill, so an empty or missing one
	# makes the skill dead weight.
	for dir in "$REPO_ROOT"/claude/skills/*/; do
		dir=${dir%/}
		skill=$(basename "$dir")
		file="$dir/SKILL.md"
		[ -f "$file" ] || fail "$skill has no SKILL.md"
		[ "$(head -n 1 "$file")" = "---" ] || fail "$skill/SKILL.md doesn't open with frontmatter"
		name=$(yq --front-matter=extract -r '.name // ""' "$file")
		description=$(yq --front-matter=extract -r '.description // ""' "$file")
		[ "$name" = "$skill" ] || fail "$skill/SKILL.md name is '$name', not its directory name"
		{ [ "${#name}" -le 64 ] && printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; } ||
			fail "$skill name must be up to 64 lowercase letters and digits, joined by single hyphens"
		[ -n "$description" ] || fail "$skill/SKILL.md has no description"
		[ "${#description}" -le 1024 ] || fail "$skill description is ${#description} characters, over 1024"
	done
}
