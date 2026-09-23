#!/usr/bin/env bats
# Spike: check that install.conf.yaml makes exactly the links the playbook
# makes from config.yml, on whichever platform the suite runs. CI runs this on
# macOS (unit-test) and Ubuntu (install-linux).

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	dotbot --version >/dev/null 2>&1 || skip "dotbot not installed"
	TEST_HOME="$(mktemp -d)"
}

teardown() {
	[ -z "${TEST_HOME:-}" ] || rm -rf "$TEST_HOME"
}

# Print "target<TAB>repo source" for every link config.yml defines here.
# (awk duplicates the column: mikefarah yq collapses `[., .]` to one value.)
expected_links() {
	if [ "$(uname)" = "Darwin" ]; then
		yq -r '.dotfiles_files_common[], .dotfiles_files_macos[]' "$REPO_ROOT/config.yml" | awk '{ print $0 "\t" $0 }'
		yq -r '.dotfile_links_common[] | [.dest, .src] | @tsv' "$REPO_ROOT/config.yml"
	else
		yq -r '.dotfiles_files_common[], .dotfiles_files_linux[]' "$REPO_ROOT/config.yml" | awk '{ print $0 "\t" $0 }'
		yq -r '(.dotfile_links_common[], .linux_dotfile_links[]) | [.dest, .src] | @tsv' "$REPO_ROOT/config.yml"
	fi
}

@test "dotbot links exactly what config.yml links, to the same sources" {
	run env HOME="$TEST_HOME" dotbot -q -d "$REPO_ROOT" -c "$REPO_ROOT/install.conf.yaml"
	[ "$status" -eq 0 ] || fail "dotbot failed: $output"

	expected=$(expected_links | cut -f1 | sort)
	actual=$(cd "$TEST_HOME" && find . -type l | sed 's|^\./||' | sort)
	missing=$(comm -23 <(echo "$expected") <(echo "$actual"))
	extra=$(comm -13 <(echo "$expected") <(echo "$actual"))
	[ -z "$missing" ] || fail "dotbot does not link: $missing"
	[ -z "$extra" ] || fail "dotbot links entries config.yml doesn't: $extra"

	# Same readlink text the playbook writes, which script/doctor checks.
	while IFS=$'\t' read -r target src; do
		actual_target=$(readlink "$TEST_HOME/$target")
		[ "$actual_target" = "$REPO_ROOT/$src" ] ||
			fail "$target -> $actual_target, expected $REPO_ROOT/$src"
	done < <(expected_links)
}

@test "dotbot leaves an existing regular file alone" {
	# The playbook moves a real file aside to .bak before linking. dotbot has
	# no backup: with relink (not force) it refuses to replace a real file
	# and reports the failure, so a user's local edits are never destroyed.
	echo local >"$TEST_HOME/.zshrc"
	run env HOME="$TEST_HOME" dotbot -q -d "$REPO_ROOT" -c "$REPO_ROOT/install.conf.yaml"
	[ "$status" -ne 0 ] || fail "expected dotbot to report the conflict"
	[ "$(cat "$TEST_HOME/.zshrc")" = local ] || fail "dotbot overwrote a regular file"
}
