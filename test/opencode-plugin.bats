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

# config_fixtures: Claude Code config exercising MCP, enabledPlugins, skills
# and memory, layered onto setup's fixtures. Hosts are example.com only: this
# repo is public, and HOME/CLAUDE_CONFIG_DIR keep the real ~/.claude.json out.
config_fixtures() {
	# A dotted project path, like ~/.files, so the memory folder name shows
	# the "." → "-" rule. Project hooks aren't under test here.
	project="$BATS_TEST_TMPDIR/my.repo"
	mkdir -p "$project"
	other_dir="$BATS_TEST_TMPDIR/other"
	scoped_dir="$BATS_TEST_TMPDIR/scoped"
	mkdir -p "$other_dir/skills/other-skill" "$scoped_dir/skills/scoped-skill"
	printf -- '---\nname: other-skill\ndescription: x\n---\n' >"$other_dir/skills/other-skill/SKILL.md"
	printf -- '---\nname: scoped-skill\ndescription: x\n---\n' >"$scoped_dir/skills/scoped-skill/SKILL.md"

	jq '.enabledPlugins += {"other@market": true, "scoped@market": true}' "$CLAUDE_CONFIG_DIR/settings.json" \
		>"$BATS_TEST_TMPDIR/s.json" && mv "$BATS_TEST_TMPDIR/s.json" "$CLAUDE_CONFIG_DIR/settings.json"
	# settings.local.json turns a plugin back off, as Claude Code layers them.
	echo '{"enabledPlugins": {"other@market": false}}' >"$CLAUDE_CONFIG_DIR/settings.local.json"
	jq --arg other "$other_dir" --arg scoped "$scoped_dir" '.plugins += {
		"other@market": [{scope: "user", installPath: $other}],
		"scoped@market": [{scope: "project", installPath: $scoped}]
	}' "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json" >"$BATS_TEST_TMPDIR/i.json" &&
		mv "$BATS_TEST_TMPDIR/i.json" "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"

	# shellcheck disable=SC2016 # Claude expands these ${...}, not this shell
	jq '.mcpServers = {
		"local-tool": {command: "npx", args: ["-y", "tool"], env: {TOKEN: "${DOTFILES_UNSET_TOKEN:-fallback}", USER_HOME: "${HOME}"}},
		"docs.example": {type: "http", url: "https://docs.example.com/mcp", headers: {"X-Test": "1"}},
		"stream": {type: "sse", url: "https://stream.example.com/sse"},
		"context7": {type: "http", url: "https://context7.example.com/mcp"},
		"shared": {command: "user-shared"},
		"preset": {command: "user-preset"},
		"broken": {type: "stdio"}
	}' "$CLAUDE_CONFIG_DIR/.claude.json" >"$BATS_TEST_TMPDIR/c.json" && mv "$BATS_TEST_TMPDIR/c.json" "$CLAUDE_CONFIG_DIR/.claude.json"
	# shellcheck disable=SC2016
	echo '{"mcpServers": {"shared": {"command": "plugin-shared"}, "plugmcp": {"command": "${CLAUDE_PLUGIN_ROOT}/bin/server"}}}' \
		>"$plugin_dir/.mcp.json"

	skill() { mkdir -p "$plugin_dir/skills/$1" && printf '%b' "$2" >"$plugin_dir/skills/$1/SKILL.md"; }
	skill quoted '---\nname: "Quoted: name"\ndescription: '"'"'It'"''"'s quoted'"'"'\n---\nBody\n'
	skill literal '---\nname: literal\ndescription: |\n  Line one\n  Line two\n---\n'
	skill folded '---\nname: folded\ndescription: >-\n  Folded\n  together\n---\n'
	skill wrapped '---\nname: wrapped\ndescription: Starts here\n  and keeps going\n---\n'
	skill crlf '\xef\xbb\xbf---\r\nname: crlf\r\ndescription: Windows\r\n---\r\nBody\r\n'
	skill manual '---\nname: manual\ndescription: Only by hand\ndisable-model-invocation: true\n---\n'
	skill nofront 'Just a body, no frontmatter\n'
	skill taken '---\nname: taken\ndescription: From the plugin\n---\n'

	# Claude Code's memory folder: every non-alphanumeric character of the
	# project path becomes "-" (this repo's is -Users-<name>--files).
	memory="$CLAUDE_CONFIG_DIR/projects/$(printf '%s' "$project" | sed 's/[^A-Za-z0-9]/-/g')/memory"
	case $memory in *-my-repo/memory) ;; *) fail "fixture memory path lost the dotted name: $memory" ;; esac
	mkdir -p "$memory"
	echo '- [Note](note.md) — a remembered fact' >"$memory/MEMORY.md"

	cat >"$BATS_TEST_TMPDIR/config.mjs" <<'EOF'
const [plugin, project] = process.argv.slice(2)
const mcp = new Map([["preset", { type: "local", command: ["opencode-own"] }]])
const skills = new Map([["taken", { id: "taken", description: "OpenCode's own" }]])
const memory = []
let evaluate
const ctx = {
	location: { directory: project },
	tool: { hook: async () => {} },
	session: {
		hook: async () => {},
		get: async () => ({ directory: project }),
		instructions: { entry: { put: async (entry) => void memory.push(entry) } },
	},
	command: { transform: async () => {} },
	mcp: { transform: async (cb) => cb({ get: (n) => mcp.get(n), set: (n, c) => void mcp.set(n, c) }) },
	skill: { transform: async (cb) => cb({ get: (id) => skills.get(id), add: (s) => void skills.set(s.id, s) }) },
	permission: { hook: async (name, cb) => void (name === "evaluate" && (evaluate = cb)), assert: async () => {} },
	event: {
		subscribe: async function* () {
			yield { data: { sessionID: "s1", location: { directory: project } } }
		},
	},
}
const { default: mod } = await import(plugin)
await mod.setup(ctx)
await new Promise((resolve) => setTimeout(resolve, 100))
const effect = (action) => {
	const event = { effect: "allow", action }
	evaluate?.(event)
	return event.effect
}
const actions = ["local-tool_run", "docs_example_search", "stream_read", "context7_query", "preset_run", "plugmcp_go", "read"]
console.log(JSON.stringify({
	mcp: Object.fromEntries(mcp),
	effects: Object.fromEntries(actions.map((a) => [a, effect(a)])),
	skills: Object.fromEntries([...skills].map(([id, s]) => [id, { name: s.name, description: s.description, autoinvoke: s.autoinvoke, content: s.content }])),
	memory,
}))
EOF
}

config_run() {
	out=$(node --experimental-strip-types --no-warnings "$BATS_TEST_TMPDIR/config.mjs" \
		"$REPO_ROOT/.config/opencode/plugins/claude-code.ts" "$project")
}

@test "Claude Code's MCP servers become OpenCode local and remote servers" {
	config_fixtures
	config_run
	[ "$(field '.mcp["local-tool"].type')" = local ] || fail "stdio server not local: $out"
	[ "$(field '.mcp["local-tool"].command | join(" ")')" = "npx -y tool" ] || fail "command and args not joined: $out"
	[ "$(field '.mcp["local-tool"].environment.TOKEN')" = fallback ] || fail "\${VAR:-default} not expanded: $out"
	[ "$(field '.mcp["local-tool"].environment.USER_HOME')" = "$HOME" ] || fail "\${VAR} not expanded: $out"
	[ "$(field '.mcp["docs.example"] | [.type, .url, .headers["X-Test"]] | join(" ")')" = "remote https://docs.example.com/mcp 1" ] ||
		fail "http server not remote: $out"
	[ "$(field '.mcp.stream.type')" = remote ] || fail "sse server not remote: $out"
	[ "$(field '.mcp.plugmcp.command[0]')" = "$plugin_dir/bin/server" ] || fail "\${CLAUDE_PLUGIN_ROOT} not expanded: $out"
	[ "$(field '.mcp | has("broken")')" = false ] || fail "server with no command mirrored: $out"
}

@test "user and OpenCode MCP config win over plugin and mirrored servers" {
	config_fixtures
	config_run
	[ "$(field '.mcp.shared.command[0]')" = user-shared ] || fail "plugin server overrode ~/.claude.json's: $out"
	[ "$(field '.mcp.preset.command[0]')" = opencode-own ] || fail "overrode a server opencode.json defines: $out"
}

@test "mirrored MCP tools ask first, except read-only docs and OpenCode's own servers" {
	config_fixtures
	config_run
	[ "$(field '.effects["local-tool_run"]')" = ask ] || fail "mirrored tool didn't ask: $out"
	# OpenCode turns "." in a server name into "_" in the action name.
	[ "$(field '.effects.docs_example_search')" = ask ] || fail "dotted server name didn't ask: $out"
	[ "$(field '.effects.stream_read')" = ask ] || fail "sse tool didn't ask: $out"
	[ "$(field '.effects.plugmcp_go')" = ask ] || fail "plugin MCP tool didn't ask: $out"
	[ "$(field '.effects.context7_query')" = allow ] || fail "read-only docs server asked: $out"
	[ "$(field '.effects.preset_run')" = allow ] || fail "opencode.json's own server forced to ask: $out"
	[ "$(field '.effects.read')" = allow ] || fail "built-in tool forced to ask: $out"
}

@test "only user-scope plugins that enabledPlugins leaves on are loaded" {
	config_fixtures
	config_run
	[ "$(field '.skills | has("other-skill")')" = false ] || fail "settings.local.json's false didn't win: $out"
	[ "$(field '.skills | has("scoped-skill")')" = false ] || fail "project-scope plugin loaded: $out"
	[ "$(field '.skills | has("literal")')" = true ] || fail "enabled plugin's skills missing: $out"
}

@test "plugin skills' frontmatter parses like Claude Code's" {
	config_fixtures
	config_run
	[ "$(field '.skills.quoted.name')" = "Quoted: name" ] || fail "double-quoted value: $out"
	[ "$(field '.skills.quoted.description')" = "It's quoted" ] || fail "single-quoted value: $out"
	[ "$(field '.skills.quoted.content')" = "Body" ] || fail "body not split from frontmatter: $out"
	[ "$(field '.skills.literal.description')" = "$(printf 'Line one\nLine two')" ] || fail "| block: $out"
	[ "$(field '.skills.folded.description')" = "Folded together" ] || fail "> block: $out"
	[ "$(field '.skills.wrapped.description')" = "Starts here and keeps going" ] || fail "wrapped value: $out"
	[ "$(field '.skills.crlf.description')" = "Windows" ] || fail "BOM and CRLF: $out"
	[ "$(field '.skills.manual.autoinvoke')" = false ] || fail "disable-model-invocation ignored: $out"
	[ "$(field '.skills.literal.autoinvoke')" = null ] || fail "autoinvoke set without disable-model-invocation: $out"
	[ "$(field '.skills | has("nofront")')" = false ] || fail "skill with no frontmatter loaded: $out"
	[ "$(field '.skills.taken.description')" = "OpenCode's own" ] || fail "overwrote a skill OpenCode already has: $out"
}

@test "new sessions get the project's Claude Code memory, read-only" {
	config_fixtures
	config_run
	[ "$(field '.memory | length')" = 1 ] || fail "expected one memory entry: $out"
	[ "$(field '.memory[0].key')" = claude-code-memory ] || fail "wrong entry key: $out"
	field '.memory[0].value' | grep -q 'a remembered fact' || fail "MEMORY.md not attached: $out"
	field '.memory[0].value' | grep -q "don't edit" || fail "lost the read-only instruction: $out"
}

@test "an empty MEMORY.md attaches nothing" {
	config_fixtures
	: >"$memory/MEMORY.md"
	config_run
	[ "$(field '.memory | length')" = 0 ] || fail "attached an empty memory: $out"
}

@test "unreadable Claude Code config leaves OpenCode working" {
	# Every file is read at load time; one bad file mustn't take OpenCode down.
	config_fixtures
	for file in settings.json settings.local.json plugins/installed_plugins.json .claude.json; do
		echo '{ not json' >"$CLAUDE_CONFIG_DIR/$file"
	done
	config_run
	[ "$(field '.mcp | keys | join(" ")')" = preset ] || fail "mirrored servers from broken config: $out"
	[ "$(field '.skills | keys | join(" ")')" = taken ] || fail "loaded skills from broken config: $out"
}
