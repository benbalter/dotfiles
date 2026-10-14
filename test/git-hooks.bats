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
