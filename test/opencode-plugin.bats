#!/usr/bin/env bats
# Smoke test for .config/opencode/plugins/claude-code.ts: load it against a
# fixture Claude Code config with a fake OpenCode plugin context, and check
# that Claude's hooks and commands reach OpenCode's hook points. OpenCode
# itself isn't installed in CI, so this pins the plugin's side of the contract.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	# Node strips TypeScript types natively from 22.6; older Node (Ubuntu's
	# apt package) can't load the plugin, so skip rather than fail there.
	command -v node >/dev/null || skip "node not installed"
	node --experimental-strip-types --no-warnings -e '' 2>/dev/null || skip "node can't strip TypeScript types"

	export HOME="$BATS_TEST_TMPDIR/home"
	export CLAUDE_CONFIG_DIR="$HOME/.claude"
	plugin_dir="$BATS_TEST_TMPDIR/plugin"
	project="$BATS_TEST_TMPDIR/project"
	mkdir -p "$CLAUDE_CONFIG_DIR/plugins" "$HOME/.opencode/plan" "$plugin_dir/hooks" "$plugin_dir/commands" \
		"$project/.claude" "$project/.git"

	# guard: denies any command mentioning "forbidden", like guard-bash.
	cat >"$BATS_TEST_TMPDIR/guard" <<'EOF'
#!/bin/sh
if jq -r .tool_input.command | grep -q forbidden; then
	echo "no forbidden commands" >&2
	exit 2
fi
EOF
	# post: hands the edited path back, like lint-file.
	cat >"$plugin_dir/hooks/post" <<'EOF'
#!/bin/sh
echo "linted $(jq -r .tool_input.file_path) from $CLAUDE_PLUGIN_ROOT" >&2
exit 2
EOF
	# stop: blocks until Claude is already continuing, like check-drift.
	cat >"$project/.claude/stop" <<'EOF'
#!/bin/sh
[ "$(jq -r .stop_hook_active)" = true ] && exit 0
echo "tests failed in $CLAUDE_PROJECT_DIR" >&2
exit 2
EOF
	chmod +x "$BATS_TEST_TMPDIR/guard" "$plugin_dir/hooks/post" "$project/.claude/stop"

	jq -n --arg guard "$BATS_TEST_TMPDIR/guard" --arg prior "$REPO_ROOT/claude/hooks/require-prior-art" '{
		enabledPlugins: {"fake@market": true},
		hooks: {PreToolUse: [
			{matcher: "Bash", hooks: [{type: "command", command: $guard}]},
			{matcher: "ExitPlanMode", hooks: [{type: "command", command: $prior}]}
		]}
	}' >"$CLAUDE_CONFIG_DIR/settings.json"
	jq -n --arg root "$plugin_dir" '{plugins: {"fake@market": [{scope: "user", installPath: $root}]}}' \
		>"$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
	# shellcheck disable=SC2016 # Claude expands ${CLAUDE_PLUGIN_ROOT}, not this shell
	echo '{"hooks": {"PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/post\""}]}]}}' \
		>"$plugin_dir/hooks/hooks.json"
	jq -n '{hooks: {Stop: [{hooks: [{type: "command", command: "\"$CLAUDE_PROJECT_DIR\"/.claude/stop"}]}]}}' \
		>"$project/.claude/settings.json"
	# Claude Code's record of folders whose "trust this folder" prompt was
	# accepted: only these projects' own hooks may run.
	jq -n --arg project "$project" '{projects: {($project): {hasTrustDialogAccepted: true}}}' \
		>"$CLAUDE_CONFIG_DIR/.claude.json"
	# shellcheck disable=SC2016 # $ARGUMENTS is for the command, not this shell
	printf -- '---\ndescription: Say hello\n---\nGreet $ARGUMENTS warmly.\n' >"$plugin_dir/commands/hello.md"

	cat >"$BATS_TEST_TMPDIR/drive.mjs" <<'EOF'
const [plugin, project] = process.argv.slice(2)
const hooks = {}
const commands = []
const synthetic = []
const prompts = []
const ctx = {
	location: { directory: project },
	tool: { hook: async (name, cb) => void (hooks[`tool.${name}`] = cb) },
	session: {
		hook: async (name, cb) => void (hooks[`session.${name}`] = cb),
		get: async () => ({ directory: project }),
		synthetic: async (input) => void synthetic.push(input),
		prompt: async (input) => void prompts.push(input),
		instructions: { entry: { put: async () => {} } },
	},
	command: { transform: async (cb) => cb({ add: (command) => commands.push(command) }) },
	mcp: { transform: async () => {} },
	skill: { transform: async () => {} },
	permission: { hook: async () => {}, assert: async () => {} },
	event: { subscribe: async function* () {} },
}
const { default: mod } = await import(plugin)
await mod.setup(ctx)
const call = { sessionID: "s1", agent: "build", messageID: "m1", id: "c1" }
const blocked = async (tool, input) => {
	try {
		await hooks["tool.execute.before"]({ ...call, tool, input })
		return ""
	} catch (error) {
		return error.message
	}
}
const after = { ...call, tool: "edit", input: { path: "a.txt", oldString: "a", newString: "b" }, status: "completed", result: { content: "done" } }
await hooks["tool.execute.after"](after)
await hooks["session.experimental.idle"]({ sessionID: "s1", background: [] })
await hooks["session.experimental.idle"]({ sessionID: "s1", background: [] })
await commands.find((c) => c.name === "hello")?.execute({ sessionID: "s1", prompt: { text: "Ben" }, delivery: "queue" })
const plan = `${process.env.HOME}/.opencode/plan/p.md`
console.log(JSON.stringify({
	forbidden: await blocked("shell", { command: "echo forbidden" }),
	allowed: await blocked("shell", { command: "echo ok" }),
	planWithout: await blocked("write", { path: plan, content: "# Plan\n" }),
	planWith: await blocked("write", { path: plan, content: "# Plan\n\n## Prior art\nNone.\n" }),
	notPlan: await blocked("write", { path: `${project}/notes.md`, content: "# Notes\n" }),
	post: after.result.content,
	synthetic: synthetic.map((s) => s.text),
	commands: commands.map((c) => [c.name, c.description]),
	prompts: prompts.map((p) => p.text),
}))
EOF
	out=$(node --experimental-strip-types --no-warnings "$BATS_TEST_TMPDIR/drive.mjs" \
		"$REPO_ROOT/.config/opencode/plugins/claude-code.ts" "$project")
}

field() { printf '%s' "$out" | jq -r "$1"; }

@test "PreToolUse hooks block OpenCode's shell calls" {
	[ "$(field .forbidden)" = "no forbidden commands" ] || fail "forbidden command ran: $out"
	[ "$(field .allowed)" = "" ] || fail "allowed command blocked: $out"
}

@test "writing a plan file runs the ExitPlanMode hooks" {
	field .planWithout | grep -q 'Prior art' || fail "plan without Prior art got through: $out"
	[ "$(field .planWith)" = "" ] || fail "plan with Prior art blocked: $out"
	[ "$(field .notPlan)" = "" ] || fail "non-plan Markdown checked as a plan: $out"
}

@test "plugin PostToolUse hooks get Claude's tool names and paths" {
	[ "$(field '.post | type')" = string ] || fail "result content changed type: $out"
	field .post | grep -q "linted $project/a.txt from $plugin_dir" || fail "no PostToolUse feedback: $out"
}

@test "project Stop hooks continue the session once, then honor stop_hook_active" {
	[ "$(field '.synthetic | length')" = 1 ] || fail "expected one continuation: $out"
	field '.synthetic[0]' | grep -q "tests failed in $project" || fail "Stop reason missing: $out"
}

@test "plugin commands become OpenCode commands" {
	[ "$(field '.commands[0] | join(" ")')" = "hello Say hello" ] || fail "command not loaded: $out"
	[ "$(field '.prompts[0]')" = "Greet Ben warmly." ] || fail "arguments not filled in: $out"
}

@test "an untrusted project's own hooks never run" {
	# Same project files, but a folder Claude Code's trust prompt never
	# approved, as with a freshly cloned repo. Trusting "/" mustn't count either.
	untrusted="$BATS_TEST_TMPDIR/untrusted"
	cp -R "$project" "$untrusted"
	jq --arg project "$project" '.projects = {($project): {hasTrustDialogAccepted: true}, "/": {hasTrustDialogAccepted: true}}' \
		"$CLAUDE_CONFIG_DIR/.claude.json" >"$BATS_TEST_TMPDIR/claude.json" && mv "$BATS_TEST_TMPDIR/claude.json" "$CLAUDE_CONFIG_DIR/.claude.json"
	out=$(node --experimental-strip-types --no-warnings "$BATS_TEST_TMPDIR/drive.mjs" \
		"$REPO_ROOT/.config/opencode/plugins/claude-code.ts" "$untrusted")
	[ "$(field '.synthetic | length')" = 0 ] || fail "untrusted project's Stop hook ran: $out"
	# User-level hooks still apply there.
	[ "$(field .forbidden)" = "no forbidden commands" ] || fail "user hooks stopped running: $out"
}
