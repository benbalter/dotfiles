#!/usr/bin/env bats
# Test the Claude Code hooks by feeding them the JSON Claude Code sends on
# stdin. A hook that misreads its input fails silently, so this is the only
# place a broken one shows up.
# The fixtures are shell scripts with literal $1s for the linters to flag.
# shellcheck disable=SC2016

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
LINT_FILE="$REPO_ROOT/.claude/hooks/lint-file"
CHECK_DRIFT="$REPO_ROOT/.claude/hooks/check-drift"
GUARD_BASH="$REPO_ROOT/claude/hooks/guard-bash"

setup() {
	command -v jq >/dev/null || skip "jq not installed"
	PROJECT="$(mktemp -d)"
	mkdir -p "$PROJECT/script"
}

teardown() {
	rm -rf "$PROJECT"
}

# edit <file>: run lint-file as if Claude just edited <file> in $PROJECT.
edit() {
	jq -n --arg f "$1" '{tool_input: {file_path: $f}}' |
		CLAUDE_PROJECT_DIR="$PROJECT" "$LINT_FILE"
}

# bash_decision <command>: guard-bash's permission decision, empty if allowed.
bash_decision() {
	jq -n --arg c "$1" '{tool_input: {command: $c}}' | "$GUARD_BASH" |
		jq -r '.hookSpecificOutput.permissionDecision // empty'
}

@test "lint-file reports shellcheck findings to Claude" {
	command -v shellcheck >/dev/null || skip "shellcheck not installed"
	printf '#!/bin/sh\necho $1\n' >"$PROJECT/script/bad"
	run edit "$PROJECT/script/bad"
	[ "$status" -eq 2 ] || fail "expected exit 2, got $status: $output"
	[[ "$output" == *SC2086* ]] || fail "shellcheck output missing: $output"
}

@test "lint-file formats shell files in place" {
	command -v shfmt >/dev/null || skip "shfmt not installed"
	printf '#!/bin/sh\nif true; then\n    echo "$1"\nfi\n' >"$PROJECT/script/spaces"
	run edit "$PROJECT/script/spaces"
	[ "$status" -eq 0 ] || fail "expected exit 0, got $status: $output"
	grep -q "$(printf '^\techo')" "$PROJECT/script/spaces" || fail "not reindented with tabs"
}

@test "lint-file ignores files outside the project" {
	printf '#!/bin/sh\necho $1\n' >"$BATS_TEST_TMPDIR/bad"
	run edit "$BATS_TEST_TMPDIR/bad"
	[ "$status" -eq 0 ] || fail "expected exit 0, got $status: $output"
}

@test "lint-file catches invalid JSON" {
	printf '{"a": }\n' >"$PROJECT/bad.json"
	run edit "$PROJECT/bad.json"
	[ "$status" -eq 2 ] || fail "expected exit 2, got $status: $output"
}

@test "lint-file accepts JSONC editor settings" {
	mkdir -p "$PROJECT/.vscode"
	printf '{\n  // a comment\n  "a": 1\n}\n' >"$PROJECT/.vscode/settings.json"
	run edit "$PROJECT/.vscode/settings.json"
	[ "$status" -eq 0 ] || fail "expected exit 0, got $status: $output"
}

@test "check-drift lets Claude stop when a stop hook is already active" {
	run sh -c "echo '{\"stop_hook_active\": true}' | CLAUDE_PROJECT_DIR='$PROJECT' '$CHECK_DRIFT'"
	[ "$status" -eq 0 ] || fail "expected exit 0, got $status: $output"
}

@test "check-drift blocks the stop when config.bats fails" {
	git -C "$PROJECT" init -q
	touch "$PROJECT/config.yml"
	# Stub bats so the test doesn't run the real suite against an empty repo.
	mkdir "$PROJECT/bin"
	printf '#!/bin/sh\necho drifted\nexit 1\n' >"$PROJECT/bin/bats"
	chmod +x "$PROJECT/bin/bats"
	command -v yq >/dev/null || ln -s /usr/bin/true "$PROJECT/bin/yq"
	run sh -c "echo '{\"stop_hook_active\": false}' |
		PATH='$PROJECT/bin:$PATH' CLAUDE_PROJECT_DIR='$PROJECT' '$CHECK_DRIFT'"
	[ "$status" -eq 2 ] || fail "expected exit 2, got $status: $output"
	[[ "$output" == *drifted* ]] || fail "bats output missing: $output"
}

@test "check-drift skips the tests when nothing it checks changed" {
	git -C "$PROJECT" init -q
	touch "$PROJECT/README.md"
	mkdir "$PROJECT/bin"
	printf '#!/bin/sh\nexit 1\n' >"$PROJECT/bin/bats"
	chmod +x "$PROJECT/bin/bats"
	command -v yq >/dev/null || ln -s /usr/bin/true "$PROJECT/bin/yq"
	run sh -c "echo '{\"stop_hook_active\": false}' |
		PATH='$PROJECT/bin:$PATH' CLAUDE_PROJECT_DIR='$PROJECT' '$CHECK_DRIFT'"
	[ "$status" -eq 0 ] || fail "expected exit 0, got $status: $output"
}

@test "guard-bash denies the commands CLAUDE.md forbids" {
	while IFS= read -r cmd; do
		[ "$(bash_decision "$cmd")" = deny ] || fail "allowed: $cmd"
	done <<'EOF'
/opt/homebrew/bin/brew list
sudo brew install wget
sudo -E /opt/workbrew/bin/brew upgrade
sudo chown -R me /opt/homebrew
npm install -g typescript
npm i --global typescript
git commit --no-gpg-sign -m x
git -c commit.gpgsign=false commit -m x
git add -A
cd repo && git add .
git add --all && git commit -m x
EOF
}

@test "guard-bash allows ordinary commands" {
	while IFS= read -r cmd; do
		[ -z "$(bash_decision "$cmd")" ] || fail "denied: $cmd"
	done <<'EOF'
brew upgrade
ls -l /opt/homebrew/bin/brew
npm install
npm ls -g
git add script/lint
git add .claude/hooks/lint-file
git log --show-signature
sudo -v && brew upgrade
EOF
}

@test "guard-bash allows commands that only mention a forbidden one" {
	# A commit message describing these rules once tripped the guard.
	cmd=$(printf 'git commit -F - <<EOF\nDeny chown of /opt/homebrew, npm install -g, --no-gpg-sign and git add -A\nEOF')
	[ -z "$(bash_decision "$cmd")" ] || fail "denied: $cmd"
}
