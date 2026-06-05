#!/usr/bin/env bats
# Validate configuration files and cross-reference dotfile inventories.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "config.yml dotfiles_files all exist in the repo" {
	for list in dotfiles_files_common dotfiles_files_macos dotfiles_files_linux; do
		while IFS= read -r file; do
			[ -e "$REPO_ROOT/$file" ] || fail "$list entry '$file' does not exist in repo"
		done < <(yq -r ".${list}[]" "$REPO_ROOT/config.yml")
	done
}

@test "config.yml linux_dotfile_links sources all exist in the repo" {
	while IFS= read -r file; do
		[ -e "$REPO_ROOT/$file" ] || fail "linux_dotfile_links src '$file' does not exist in repo"
	done < <(yq -r '.linux_dotfile_links[].src' "$REPO_ROOT/config.yml")
}

@test "install.sh dotfiles all exist in the repo" {
	# Parse the for-loop file list from install.sh
	in_list=false
	while IFS= read -r line; do
		if echo "$line" | grep -q 'for file in'; then
			in_list=true
			continue
		fi
		if $in_list; then
			# Strip trailing backslash and semicolon
			cleaned=$(echo "$line" | sed 's/\\$//' | sed 's/;.*//')
			for file in $cleaned; do
				[ "$file" = "do" ] && continue
				[ -e "$REPO_ROOT/$file" ] || fail "install.sh references '$file' which does not exist in repo"
			done
			# Stop after the line without a backslash (end of list)
			echo "$line" | grep -q '\\$' || break
		fi
	done <"$REPO_ROOT/install.sh"
}

@test "config.yml has required top-level keys" {
	for key in dotfiles_files dotfiles_files_common dotfiles_files_macos \
		dotfiles_files_linux linux_dotfile_links fedora_packages \
		homebrew_brewfile_dir directories_to_create macos_defaults; do
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
