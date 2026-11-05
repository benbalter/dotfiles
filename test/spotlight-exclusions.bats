#!/usr/bin/env bats
# Test script/spotlight-exclusions against a stubbed PlistBuddy and mdfind and
# a test config, so it never reads or writes the host's Spotlight settings.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	TMP="$(mktemp -d)"
	mkdir -p "$TMP/home/projects" "$TMP/home/other"
	cat >"$TMP/config.yml" <<'YAML'
spotlight_exclusions:
  - ~/projects
  - ~/other
YAML
	# The stub keeps the array in a text file, one path per line, and answers
	# the three PlistBuddy commands the script uses.
	printf '%s\n' "$TMP/home/other" >"$TMP/exclusions"
	cat >"$TMP/PlistBuddy" <<STUB
#!/bin/sh
case "\$2" in
	'Print :Exclusions')
		[ -e "$TMP/exclusions" ] || exit 1
		echo 'Array {'; sed 's/^/    /' "$TMP/exclusions"; echo '}' ;;
	'Add :Exclusions array') : >"$TMP/exclusions" ;;
	'Add :Exclusions: string '*) printf '%s\n' "\${2#Add :Exclusions: string }" >>"$TMP/exclusions" ;;
	*) exit 2 ;;
esac
STUB
	cat >"$TMP/mdfind" <<STUB
#!/bin/sh
case "\$2" in "$TMP/home/projects") echo 42 ;; *) echo 0 ;; esac
STUB
	chmod +x "$TMP/PlistBuddy" "$TMP/mdfind"
}

teardown() {
	rm -rf "$TMP"
}

spotlight() {
	env SPOTLIGHT_CONFIG="$TMP/config.yml" SPOTLIGHT_HOME="$TMP/home" \
		PLISTBUDDY="$TMP/PlistBuddy" MDFIND="$TMP/mdfind" SPOTLIGHT_NO_RESTART=1 \
		"$REPO_ROOT/script/spotlight-exclusions" "$@"
}

@test "spotlight-exclusions lists only configured paths not yet excluded" {
	run spotlight
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	[ "$output" = "$TMP/home/projects" ] || fail "got: $output"
}

@test "spotlight-exclusions --apply adds the missing paths once" {
	run spotlight --apply
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	[ "$output" = "$TMP/home/projects" ] || fail "got: $output"
	run spotlight --apply
	[ -z "$output" ] || fail "second run added again: $output"
	run spotlight
	[ -z "$output" ] || fail "still missing: $output"
}

@test "spotlight-exclusions --apply creates the array when the key is missing" {
	rm "$TMP/exclusions"
	run spotlight --apply
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	[ "$(cat "$TMP/exclusions")" = "$TMP/home/projects
$TMP/home/other" ] || fail "got: $(cat "$TMP/exclusions")"
}

@test "spotlight-exclusions --indexed reports folders that still have items" {
	run spotlight --indexed
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	[ "$output" = "$TMP/home/projects: 42 items" ] || fail "got: $output"
}

@test "the repo's spotlight_exclusions are all under home" {
	! yq -r '.spotlight_exclusions[]' "$REPO_ROOT/config.yml" | grep -v '^~/' ||
		fail "paths are expanded against the login user's home"
}
