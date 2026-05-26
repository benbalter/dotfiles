#!/usr/bin/env bats
# Validate that all scripts have valid shell syntax and are executable.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "scripts are executable" {
	for script in "$REPO_ROOT"/script/*; do
		[ -x "$script" ] || fail "$(basename "$script") is not executable"
	done
}

@test "scripts have valid shell syntax" {
	for script in "$REPO_ROOT"/script/*; do
		shell=$(head -1 "$script" | sed 's|^#! *||')
		case "$shell" in
			*/bash) bash -n "$script" ;;
			*/sh) sh -n "$script" ;;
			*) fail "$(basename "$script") has unknown shebang: $shell" ;;
		esac
	done
}

@test "install.sh has valid shell syntax" {
	sh -n "$REPO_ROOT/install.sh"
}

@test "install.sh is executable" {
	[ -x "$REPO_ROOT/install.sh" ]
}
