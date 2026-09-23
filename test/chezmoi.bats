#!/usr/bin/env bats
# Spike: check that the chezmoi source state under home/ (see .chezmoiroot)
# produces exactly the links the playbook makes from config.yml, on whichever
# platform the suite runs. chezmoi reads the OS from its Go runtime, so unlike
# install.sh it can't be pointed at Linux with a uname stub; CI runs this on
# both macOS (unit-test) and Ubuntu (install-linux).

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	# Run it, not just `command -v`: a stale mise shim can be on PATH with no
	# chezmoi behind it.
	chezmoi --version >/dev/null 2>&1 || skip "chezmoi not installed"
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

@test "chezmoi links exactly what config.yml links, to the same sources" {
	# HOME, not just --destination, so chezmoi's own config and state land in
	# the temp dir too.
	run env HOME="$TEST_HOME" chezmoi --source "$REPO_ROOT" apply --no-tty
	[ "$status" -eq 0 ] || fail "chezmoi apply failed: $output"

	expected=$(expected_links | cut -f1 | sort)
	actual=$(cd "$TEST_HOME" && find . -type l | sed 's|^\./||' | sort)
	missing=$(comm -23 <(echo "$expected") <(echo "$actual"))
	extra=$(comm -13 <(echo "$expected") <(echo "$actual"))
	[ -z "$missing" ] || fail "chezmoi does not link: $missing"
	[ -z "$extra" ] || fail "chezmoi links entries config.yml doesn't: $extra"

	# Same readlink text the playbook writes, which script/doctor checks.
	while IFS=$'\t' read -r target src; do
		actual_target=$(readlink "$TEST_HOME/$target")
		[ "$actual_target" = "$REPO_ROOT/$src" ] ||
			fail "$target -> $actual_target, expected $REPO_ROOT/$src"
	done < <(expected_links)
}

@test "chezmoi verify passes after apply" {
	env HOME="$TEST_HOME" chezmoi --source "$REPO_ROOT" apply --no-tty
	run env HOME="$TEST_HOME" chezmoi --source "$REPO_ROOT" verify
	[ "$status" -eq 0 ] || fail "chezmoi verify failed: $output"
}
