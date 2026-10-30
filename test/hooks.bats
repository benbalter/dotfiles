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
PRIOR_ART="$REPO_ROOT/claude/hooks/require-prior-art"

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
sudo brew install wget
sudo -E /opt/homebrew/bin/brew upgrade
sudo chown -R me /opt/homebrew
npm install -g typescript
npm i --global typescript
npm login
npm adduser --registry https://registry.npmjs.org
npm config set //registry.npmjs.org/:_authToken abc
npm set //registry.npmjs.org/:_authToken=abc
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
/opt/homebrew/bin/brew list
ls -l /opt/homebrew/bin/brew
npm install
npm ls -g
npm config get registry
npm whoami
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

# plan_decision <plan text>: require-prior-art's decision for a plan passed
# the way Claude Code injects it, empty if allowed. No plans dir, so the
# newest-file fallback can't pick up a real plan.
plan_decision() {
	jq -n --arg p "$1" '{tool_name: "ExitPlanMode", tool_input: {plan: $p}}' |
		CLAUDE_PLANS_DIR="$PROJECT/none" "$PRIOR_ART" | jq -r '.hookSpecificOutput.permissionDecision // empty'
}

@test "require-prior-art rejects a plan without a Prior art section" {
	[ "$(plan_decision "$(printf '# Plan\n\n## Design\n\nBuild it.')")" = deny ] || fail "plan without prior art was allowed"
}

@test "require-prior-art allows a plan with a Prior art heading at any level" {
	for heading in "## Prior art" "### Prior Art" "# prior art (searched restic, kopia)"; do
		[ -z "$(plan_decision "$(printf '# Plan\n\n%s\n\nNothing fit.' "$heading")")" ] || fail "rejected: $heading"
	done
}

@test "require-prior-art reads the plan file when the input has no plan text" {
	mkdir -p "$PROJECT/plans"
	printf '# Plan\n## Design\n' >"$PROJECT/plans/p.md"
	out=$(jq -n --arg f "$PROJECT/plans/p.md" '{tool_input: {planFilePath: $f}}' | "$PRIOR_ART")
	[ "$(echo "$out" | jq -r .hookSpecificOutput.permissionDecision)" = deny ] || fail "$out"
}

@test "require-prior-art never blocks on input it can't read" {
	run sh -c "echo 'not json' | CLAUDE_PLANS_DIR='$PROJECT/none' '$PRIOR_ART'"
	[ "$status" -eq 0 ] && [ -z "$output" ] || fail "status $status: $output"
}

@test "claude/settings.json runs require-prior-art on ExitPlanMode" {
	jq -e '.hooks.PreToolUse[] | select(.matcher == "ExitPlanMode") | .hooks[].command | test("require-prior-art")' \
		"$REPO_ROOT/claude/settings.json" >/dev/null || fail "hook not wired up"
}
