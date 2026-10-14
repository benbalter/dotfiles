#!/usr/bin/env bats
# Test the gitleaks pre-commit hook that init.templateDir copies into new
# clones, by running it against staged files in a scratch repo.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
HOOK="$REPO_ROOT/.config/git/template/hooks/pre-commit"

setup() {
	REPO="$(mktemp -d)"
	git init -q --template= "$REPO"
	cd "$REPO" || return
}

teardown() {
	rm -rf "$REPO"
}

stage_token() {
	# A random token in GitHub's PAT format, so gitleaks' github-pat rule fires.
	printf 'token = "ghp_%s"\n' "$(openssl rand -hex 18)" >secret.txt
	git add secret.txt
}

@test "pre-commit hook blocks a staged secret" {
	command -v gitleaks >/dev/null || skip "needs gitleaks"
	stage_token
	run "$HOOK"
	[ "$status" -eq 1 ] || fail "expected the hook to block, got $status: $output"
	[[ $output == *"SKIP_GITLEAKS=1"* ]] || fail "missing the how-to-skip hint: $output"
}

@test "pre-commit hook passes clean changes" {
	command -v gitleaks >/dev/null || skip "needs gitleaks"
	echo hello >a.txt
	git add a.txt
	run "$HOOK"
	[ "$status" -eq 0 ] || fail "clean change blocked: $output"
}

@test "pre-commit hook honors SKIP_GITLEAKS" {
	stage_token
	SKIP_GITLEAKS=1 run "$HOOK"
	[ "$status" -eq 0 ] || fail "SKIP_GITLEAKS ignored: $output"
}

@test "pre-commit hook passes when gitleaks isn't installed" {
	# The hook appends /opt/homebrew/bin, so this only means something where
	# gitleaks isn't there.
	[ ! -x /opt/homebrew/bin/gitleaks ] || skip "gitleaks is in /opt/homebrew/bin"
	stage_token
	PATH=/usr/bin:/bin run "$HOOK"
	[ "$status" -eq 0 ] || fail "missing gitleaks should not block commits: $output"
}

@test "install-git-hooks copies the template into a repo without hooks" {
	run "$REPO_ROOT/script/install-git-hooks" "$REPO"
	[ "$status" -eq 0 ] || fail "$output"
	cmp -s "$HOOK" "$REPO/.git/hooks/pre-commit" || fail "hook not installed: $output"
	[ -f "$REPO/.git/info/exclude" ] || fail "info/exclude not installed: $output"
}

@test "install-git-hooks leaves core.filemode alone" {
	git config core.filemode false
	run "$REPO_ROOT/script/install-git-hooks" "$REPO"
	[ "$(git config core.filemode)" = false ] || fail "core.filemode was rewritten"
}

@test "install-git-hooks refreshes a stale copy of its own hook" {
	mkdir -p .git/hooks
	printf '#!/bin/sh\n# old\ngitleaks git --pre-commit --staged\n' >.git/hooks/pre-commit
	run "$REPO_ROOT/script/install-git-hooks" "$REPO"
	cmp -s "$HOOK" "$REPO/.git/hooks/pre-commit" || fail "stale hook not refreshed: $output"
	[[ $output == *"refreshed"* ]] || fail "$output"
}

@test "install-git-hooks leaves another tool's hook alone" {
	mkdir -p .git/hooks
	printf '#!/bin/sh\nlefthook run pre-commit\n' >.git/hooks/pre-commit
	run "$REPO_ROOT/script/install-git-hooks" "$REPO"
	grep -q lefthook .git/hooks/pre-commit || fail "foreign hook overwritten"
	[[ $output == *"has its own pre-commit hook"* ]] || fail "$output"
}

@test "install-git-hooks skips repos with their own core.hooksPath" {
	git config core.hooksPath .husky
	run "$REPO_ROOT/script/install-git-hooks" "$REPO"
	[ ! -e .git/hooks/pre-commit ] || fail "installed where git won't run it"
	[[ $output == *"core.hooksPath"* ]] || fail "$output"
}

@test "install-git-hooks ignores folders that aren't repo roots" {
	mkdir sub
	run "$REPO_ROOT/script/install-git-hooks" "$REPO/sub"
	[ ! -e .git/hooks/pre-commit ] || fail "installed into the parent repo"
}
