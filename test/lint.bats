#!/usr/bin/env bats
# Test that script/lint runs every linter and lists each failure, with every
# linter stubbed to fail in a copy of the scripts, so nothing real is linted.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	FAKE_REPO="$(mktemp -d)"
	mkdir -p "$FAKE_REPO/script" "$FAKE_REPO/env/bin" "$FAKE_REPO/bin"
	cp "$REPO_ROOT/script/lint" "$REPO_ROOT/script/blocking-io" "$FAKE_REPO/script/"
	echo "deactivate() { :; }" >"$FAKE_REPO/env/bin/activate"
	for cmd in ansible-lint yamllint python3 shellcheck shfmt zsh git actionlint bundle ruby npx; do
		printf '#!/bin/sh\nexit 1\n' >"$FAKE_REPO/bin/$cmd"
		chmod +x "$FAKE_REPO/bin/$cmd"
	done
}

teardown() {
	rm -rf "$FAKE_REPO"
}

@test "lint runs every linter and lists each failure" {
	# Stopping at the first failure once kept CI red for five pushes in a row,
	# as each fix uncovered the next linter's error.
	run env PATH="$FAKE_REPO/bin:/usr/bin:/bin" sh "$FAKE_REPO/script/lint"
	[ "$status" -eq 1 ] || fail "lint exited $status: $output"
	summary=$(echo "$output" | sed -n '/^==> Failed:/,$p')
	count=0
	while IFS= read -r desc; do
		count=$((count + 1))
		echo "$summary" | grep -qF "    $desc" || fail "'$desc' is missing from the failure list: $output"
	done < <(sed -n 's/^lint "\([^"]*\)".*/\1/p' "$REPO_ROOT/script/lint")
	[ "$count" -gt 5 ] || fail "found only $count lint calls; did the lint helper change?"
}

@test "lint stops early without a Python venv" {
	rm "$FAKE_REPO/env/bin/activate"
	run env PATH="$FAKE_REPO/bin:/usr/bin:/bin" sh "$FAKE_REPO/script/lint"
	[ "$status" -eq 1 ] || fail "$output"
	echo "$output" | grep -q "run script/bootstrap first" || fail "$output"
}
