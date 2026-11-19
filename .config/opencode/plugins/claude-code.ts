// OpenCode plugin: read Claude Code's own config at runtime instead of keeping
// copies of it in opencode.json, so the two agents can't drift apart.
//
// - Hooks: runs Claude Code's PreToolUse, PostToolUse, Stop and
//   UserPromptSubmit hooks at the matching OpenCode points, in Claude's hook
//   format. They come from ~/.claude/settings{,.local}.json, the project's
//   .claude/settings{,.local}.json, and each enabled plugin's hooks.json, so
//   guard-bash, this repo's lint-file and check-drift, and plugin hooks like
//   security-guidance all fire. Writing a plan file runs the ExitPlanMode
//   hooks (require-prior-art), since OpenCode has no plan-exit tool.
// - Plugins: loads the skills, commands and MCP servers of every Claude Code
//   plugin that enabledPlugins turns on, from the copies Claude Code keeps
//   updated, plus ~/.claude/commands.
// - MCP: loads the user-level MCP servers from ~/.claude.json. They're read
//   here at runtime, so private hosts never land in this public repo.
//
// Not mirrored: plugin subagents (OpenCode 2.3.2's agent editor can update and
// remove agents but not add them), and SessionStart hooks (no matching hook).
// @hamzaabili/opencode-claude-hooks covers more hook events, but it was a week
// old with one maintainer when this was written, and it would run guard-bash
// from an unpinned npm install. Worth another look once it matures.
//
// Everything fails open: a missing or unreadable file skips that part rather
// than breaking OpenCode. Config set in opencode.json always wins.
import { spawn } from "node:child_process"
import { existsSync, readdirSync, readFileSync, realpathSync } from "node:fs"
import os from "node:os"
import path from "node:path"

// MCP servers whose tools only read docs, so they don't need an approval prompt.
// Every other mirrored server asks first: OpenCode allows tools by default,
// where Claude Code's auto mode judges each call, and servers like a home
// automation hub or a signed-in browser act on real things.
const READ_ONLY_MCP = new Set(["context7"])

// Claude Code moves its whole config, ~/.claude.json included, under
// CLAUDE_CONFIG_DIR when that's set.
const configDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude")
const claudeJson = process.env.CLAUDE_CONFIG_DIR
	? path.join(configDir, ".claude.json")
	: path.join(os.homedir(), ".claude.json")

function readJson(file: string): any {
	try {
		return JSON.parse(readFileSync(file, "utf8"))
	} catch {
		return undefined
	}
}

const settings = [readJson(path.join(configDir, "settings.json")), readJson(path.join(configDir, "settings.local.json"))]

// --- Enabled plugins ---

const enabled = new Set<string>()
for (const s of settings) {
	for (const [key, on] of Object.entries(s?.enabledPlugins ?? {})) {
		if (on === true) enabled.add(key)
		else enabled.delete(key)
	}
}

// Only user-scope installs: a project-scope plugin belongs to its project.
const installed = readJson(path.join(configDir, "plugins", "installed_plugins.json"))?.plugins ?? {}
const pluginRoots: string[] = [...enabled]
	.map((key) => (installed[key] ?? []).find((install: any) => install?.scope === "user")?.installPath)
	.filter((root): root is string => typeof root === "string" && existsSync(root))

// Claude Code expands ${CLAUDE_PLUGIN_ROOT}, ${VAR} and ${VAR:-default} in MCP config.
function expand(value: unknown, root?: string): any {
	if (typeof value === "string") {
		return value.replace(/\$\{([A-Za-z0-9_]+)(?::-([^}]*))?\}/g, (whole, name, fallback) => {
			if (name === "CLAUDE_PLUGIN_ROOT" && root) return root
			return process.env[name] ?? fallback ?? whole
		})
	}
	if (Array.isArray(value)) return value.map((item) => expand(item, root))
	if (value && typeof value === "object") {
		return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, expand(v, root)]))
	}
	return value
}

function toOpenCode(server: any): any {
	const type = server?.type ?? (server?.command ? "stdio" : server?.url ? "http" : undefined)
	if (type === "stdio" && typeof server.command === "string") {
		return {
			type: "local",
			command: [server.command, ...(Array.isArray(server.args) ? server.args : [])],
			...(server.env ? { environment: server.env } : {}),
			...(server.cwd ? { cwd: server.cwd } : {}),
		}
	}
	if ((type === "http" || type === "sse") && typeof server.url === "string") {
		return { type: "remote", url: server.url, ...(server.headers ? { headers: server.headers } : {}) }
	}
	return undefined
}

const mcpServers = new Map<string, any>()
for (const [name, server] of Object.entries(readJson(claudeJson)?.mcpServers ?? {})) {
	const config = toOpenCode(expand(server))
	if (config) mcpServers.set(name, config)
}
for (const root of pluginRoots) {
	const file = readJson(path.join(root, ".mcp.json"))
	for (const [name, server] of Object.entries(file?.mcpServers ?? file ?? {})) {
		const config = toOpenCode(expand(server, root))
		if (config && !mcpServers.has(name)) mcpServers.set(name, config)
	}
}

// --- Skills ---

function unquote(value: string) {
	if (/^".*"$/.test(value)) {
		try {
			return JSON.parse(value)
		} catch {
			return value.slice(1, -1)
		}
	}
	if (/^'.*'$/.test(value)) return value.slice(1, -1).replace(/''/g, "'")
	return value
}

// Just enough YAML for SKILL.md frontmatter: top-level scalars, quoted or
// plain, including block (| or >) and wrapped multi-line values.
function parseFrontmatter(source: string) {
	const out: Record<string, string> = {}
	const lines = source.split(/\r?\n/)
	for (let i = 0; i < lines.length; i++) {
		const pair = /^([A-Za-z0-9_-]+):[ \t]*(.*)$/.exec(lines[i])
		if (!pair) continue
		const [, key, first] = pair
		const rest: string[] = []
		while (i + 1 < lines.length && (/^[ \t]/.test(lines[i + 1]) || lines[i + 1] === "")) rest.push(lines[++i].trim())
		if (/^[|>][+-]?$/.test(first)) {
			out[key] = first.startsWith("|") ? rest.join("\n").trim() : rest.join(" ").replace(/\s+/g, " ").trim()
		} else if (first !== "") {
			out[key] = unquote([first, ...rest].join(" ").replace(/\s+/g, " ").trim())
		}
	}
	return out
}

function truthy(value: string | undefined) {
	return ["true", "yes", "on", "1"].includes((value ?? "").trim().toLowerCase())
}

const skills: any[] = []
for (const root of pluginRoots) {
	const dir = path.join(root, "skills")
	let entries: string[] = []
	try {
		entries = readdirSync(dir)
	} catch {
		continue
	}
	for (const entry of entries) {
		const file = path.join(dir, entry, "SKILL.md")
		let text: string
		try {
			text = readFileSync(file, "utf8").replace(/^﻿/, "")
		} catch {
			continue
		}
		const match = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/.exec(text)
		if (!match) continue
		const frontmatter = parseFrontmatter(match[1])
		skills.push({
			id: entry,
			name: frontmatter.name || entry,
			...(frontmatter.description ? { description: frontmatter.description } : {}),
			...(truthy(frontmatter["disable-model-invocation"]) ? { autoinvoke: false } : {}),
			path: file,
			content: text.slice(match[0].length),
		})
	}
}

// --- Commands ---

// Claude Code slash commands are Markdown prompts: optional frontmatter, then a
// body where $ARGUMENTS (and $1, $2...) stand for what follows the command.
type Command = { name: string; description?: string; body: string }
const commands = new Map<string, Command>()
for (const dir of [path.join(configDir, "commands"), ...pluginRoots.map((root) => path.join(root, "commands"))]) {
	let entries: string[] = []
	try {
		entries = readdirSync(dir).filter((entry) => entry.endsWith(".md"))
	} catch {
		continue
	}
	for (const entry of entries) {
		const name = entry.slice(0, -3)
		if (commands.has(name)) continue
		let text: string
		try {
			text = readFileSync(path.join(dir, entry), "utf8").replace(/^﻿/, "")
		} catch {
			continue
		}
		const match = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/.exec(text)
		const frontmatter = match ? parseFrontmatter(match[1]) : {}
		commands.set(name, {
			name,
			...(frontmatter.description ? { description: frontmatter.description } : {}),
			body: match ? text.slice(match[0].length) : text,
		})
	}
}

function renderCommand(body: string, args: string) {
	const trimmed = args.trim()
	const positional = trimmed ? trimmed.split(/\s+/) : []
	const usesArgs = /\$ARGUMENTS|\$\d/.test(body)
	const text = body.replace(/\$ARGUMENTS/g, trimmed).replace(/\$(\d+)/g, (_, n) => positional[Number(n) - 1] ?? "")
	// Claude Code appends the arguments when the body never asks for them.
	return !usesArgs && trimmed ? `${text.trimEnd()}\n\nARGUMENTS: ${trimmed}` : text
}

// --- Hooks ---

type Hook = { command: string; timeout?: number; root?: string }
type HookSource = { hooks: any; root?: string }

// User settings and enabled plugins don't change while OpenCode runs; Claude
// Code also reads them once at startup.
const staticSources: HookSource[] = [
	...settings.map((s) => ({ hooks: s?.hooks })),
	...pluginRoots.map((root) => ({ hooks: readJson(path.join(root, "hooks", "hooks.json"))?.hooks, root })),
]

// The project is the nearest folder with Claude Code settings, else the git
// root, else the session's own folder. ~/.claude is user config, not a project.
function projectRoot(dir: string) {
	for (let d = dir; ; d = path.dirname(d)) {
		if (d === os.homedir()) break
		if (["settings.json", "settings.local.json"].some((f) => existsSync(path.join(d, ".claude", f)))) return d
		if (existsSync(path.join(d, ".git"))) return d
		if (path.dirname(d) === d) break
	}
	return dir
}

// Project settings are read on each call, so a hook added mid-session counts.
function projectSources(project: string): HookSource[] {
	if (path.join(project, ".claude") === configDir) return []
	return ["settings.json", "settings.local.json"].map((f) => ({
		hooks: readJson(path.join(project, ".claude", f))?.hooks,
	}))
}

function matchesTool(matcher: unknown, tool: string) {
	if (matcher === undefined || matcher === "" || matcher === "*") return true
	if (typeof matcher !== "string") return false
	try {
		return new RegExp(`^(?:${matcher})$`).test(tool)
	} catch {
		return false
	}
}

// tool is undefined for events without a matcher (Stop, UserPromptSubmit).
function hooksFor(event: string, tool: string | undefined, sources: HookSource[]): Hook[] {
	const seen = new Set<string>()
	const out: Hook[] = []
	for (const { hooks, root } of sources) {
		const entries = hooks?.[event]
		if (!Array.isArray(entries)) continue
		for (const entry of entries) {
			if (tool !== undefined && !matchesTool(entry?.matcher, tool)) continue
			for (const hook of entry?.hooks ?? []) {
				if (hook?.type !== "command" || typeof hook.command !== "string") continue
				// Claude Code runs an identical command once, even when several
				// matchers pick it.
				const key = `${root ?? ""}\0${hook.command}`
				if (seen.has(key)) continue
				seen.add(key)
				out.push({ command: hook.command, timeout: hook.timeout, ...(root ? { root } : {}) })
			}
		}
	}
	return out
}

type Run = { status: number | null; stdout: string; stderr: string }

// Async, unlike spawnSync, so a slow hook (check-drift runs bats) doesn't
// freeze the OpenCode server for every other session.
function runHook(hook: Hook, input: object, cwd: string, project: string): Promise<Run> {
	return new Promise((resolve) => {
		let stdout = ""
		let stderr = ""
		let child: ReturnType<typeof spawn>
		try {
			child = spawn("/bin/sh", ["-c", hook.command], {
				cwd: existsSync(cwd) ? cwd : undefined,
				env: {
					...process.env,
					CLAUDE_PROJECT_DIR: project,
					...(hook.root ? { CLAUDE_PLUGIN_ROOT: hook.root } : {}),
				},
				stdio: ["pipe", "pipe", "pipe"],
			})
		} catch {
			return resolve({ status: null, stdout, stderr })
		}
		const timer = setTimeout(() => child.kill("SIGKILL"), (hook.timeout ?? 60) * 1000)
		child.stdout?.on("data", (chunk) => (stdout += chunk))
		child.stderr?.on("data", (chunk) => (stderr += chunk))
		child.stdin?.on("error", () => {})
		child.on("error", () => {
			clearTimeout(timer)
			resolve({ status: null, stdout, stderr })
		})
		child.on("close", (status) => {
			clearTimeout(timer)
			resolve({ status, stdout, stderr })
		})
		child.stdin?.end(JSON.stringify(input))
	})
}

type Outcome = { block: string[]; ask: string[]; context: string[] }

// Claude's hook protocol: exit 2 blocks and hands stderr to the model; exit 0
// may print JSON with a decision or extra context; anything else is a
// non-blocking error that Claude Code only shows the user.
function interpret(run: Run, event: string, command: string, outcome: Outcome) {
	if (run.status === 2) {
		outcome.block.push(run.stderr.trim() || `Blocked by ${command}`)
		return
	}
	if (run.status !== 0) return
	const stdout = run.stdout.trim()
	if (!stdout) return
	let out: any
	try {
		out = JSON.parse(stdout)
	} catch {
		// Plain stdout becomes context only for prompt hooks, as in Claude Code.
		if (event === "UserPromptSubmit") outcome.context.push(stdout)
		return
	}
	const specific = out?.hookSpecificOutput
	const reason = specific?.permissionDecisionReason || out?.reason || out?.stopReason || `Blocked by ${command}`
	if (specific?.permissionDecision === "deny" || out?.decision === "block" || out?.continue === false) {
		outcome.block.push(reason)
	} else if (specific?.permissionDecision === "ask") {
		outcome.ask.push(reason)
	}
	if (typeof specific?.additionalContext === "string" && specific.additionalContext.trim()) {
		outcome.context.push(specific.additionalContext.trim())
	}
}

async function runAll(hooks: Hook[], event: string, input: object, cwd: string, project: string) {
	const outcome: Outcome = { block: [], ask: [], context: [] }
	const runs = await Promise.all(
		hooks.map((hook) => runHook(hook, { hook_event_name: event, cwd, ...input }, cwd, project)),
	)
	runs.forEach((run, i) => interpret(run, event, hooks[i].command, outcome))
	return outcome
}

// OpenCode's built-in tools under Claude Code's names and input fields, so
// matchers like "Edit|Write" and hooks reading tool_input.file_path just work.
const CLAUDE_TOOLS: Record<string, string> = {
	shell: "Bash",
	edit: "Edit",
	write: "Write",
	read: "Read",
	grep: "Grep",
	glob: "Glob",
	webfetch: "WebFetch",
	websearch: "WebSearch",
	subagent: "Task",
	skill: "Skill",
	question: "AskUserQuestion",
}

function toClaude(tool: string, input: any, cwd: string): { name: string; input: any } {
	const i = input && typeof input === "object" ? input : {}
	const file = typeof i.path === "string" ? path.resolve(cwd, i.path) : undefined
	const name = CLAUDE_TOOLS[tool] ?? tool
	switch (tool) {
		case "shell":
			return { name, input: { command: i.command, ...(i.background ? { run_in_background: true } : {}) } }
		case "edit":
			return {
				name,
				input: { file_path: file, old_string: i.oldString, new_string: i.newString, replace_all: !!i.replaceAll },
			}
		case "write":
			return { name, input: { file_path: file, content: i.content } }
		case "read":
			return { name, input: { file_path: file, offset: i.offset, limit: i.limit } }
		default:
			return { name, input: i }
	}
}

function realDir(dir: string) {
	try {
		return realpathSync(dir)
	} catch {
		return path.resolve(dir)
	}
}

// OpenCode's plan agent writes to ~/.opencode/plan, which the dotfiles link to
// Claude Code's plans folder; check both, through any symlinks.
const planDirs = [path.join(os.homedir(), ".opencode", "plan"), path.join(configDir, "plans")].map(realDir)

function isPlanFile(file: unknown) {
	if (typeof file !== "string" || !file.endsWith(".md")) return false
	const dir = realDir(path.dirname(file))
	return planDirs.some((plans) => dir === plans || dir.startsWith(plans + path.sep))
}

// Stop hooks that keep blocking get this many continuations before the
// session is allowed to stop, so a hook that ignores stop_hook_active can't
// loop forever.
const MAX_STOP_BLOCKS = 3

// Registers a hook OpenCode may not offer in every release (some are marked
// experimental), so one rejected registration can't stop setup before the rest
// of the plugin, guard-bash included, is in place.
async function optional(register: () => Promise<unknown>) {
	try {
		await register()
	} catch {}
}

function appendToResult(result: any, text: string) {
	const content = result?.content
	if (typeof content === "string") return { ...result, content: `${content}\n\n${text}` }
	if (Array.isArray(content)) return { ...result, content: [...content, { type: "text", text }] }
	const output = result?.output
	const prior = output === undefined ? [] : [{ type: "text", text: typeof output === "string" ? output : JSON.stringify(output) }]
	return { ...result, content: [...prior, { type: "text", text }] }
}

// --- Memory ---

// Claude Code keeps each project's auto-memory under projects/<path with every
// non-alphanumeric character turned into "-">/memory, indexed by MEMORY.md.
function memoryFor(directories: (string | undefined)[]): string | undefined {
	for (const directory of directories) {
		if (!directory) continue
		const dir = path.join(configDir, "projects", directory.replace(/[^A-Za-z0-9]/g, "-"), "memory")
		let index: string
		try {
			index = readFileSync(path.join(dir, "MEMORY.md"), "utf8").trim()
		} catch {
			continue
		}
		if (!index) continue
		// Read-only on purpose: Claude Code stays the one writer, so the format
		// can't drift. Linked entries are read on demand, as Claude Code does.
		return [
			`Claude Code's memory for this project, from ${dir}. Each line links to a file in that folder; read one when it's relevant. Treat it as background that was true when written, and don't edit these files from OpenCode.`,
			"",
			index,
		].join("\n")
	}
	return undefined
}

// --- Plugin ---

export default {
	id: "dotfiles.claude-code",
	async setup(ctx: any) {
		// Each session's folder, which can differ from the plugin's location.
		const sessions = new Map<string, { directory: string; child: boolean }>()
		const fallback = () => ctx.location?.directory ?? process.cwd()
		async function sessionInfo(sessionID: string) {
			const cached = sessions.get(sessionID)
			if (cached) return cached
			let info = { directory: fallback(), child: false }
			try {
				const session = await ctx.session.get({ sessionID })
				const directory = session?.directory ?? session?.location?.directory
				info = { directory: typeof directory === "string" ? directory : fallback(), child: !!session?.parentID }
			} catch {}
			sessions.set(sessionID, info)
			return info
		}

		await ctx.tool.hook("execute.before", async (event: any) => {
			const { directory } = await sessionInfo(event.sessionID)
			const project = projectRoot(directory)
			const sources = [...staticSources, ...projectSources(project)]
			const claude = toClaude(event.tool, event.input, directory)
			const workdir = (event.input as any)?.workdir
			const cwd = event.tool === "shell" && typeof workdir === "string" ? path.resolve(directory, workdir) : directory
			const base = { session_id: event.sessionID, tool_name: claude.name, tool_input: claude.input }
			const outcome = await runAll(hooksFor("PreToolUse", claude.name, sources), "PreToolUse", base, cwd, project)
			if (event.tool === "write" && isPlanFile(claude.input.file_path)) {
				const plan = await runAll(
					hooksFor("PreToolUse", "ExitPlanMode", sources),
					"PreToolUse",
					{
						session_id: event.sessionID,
						tool_name: "ExitPlanMode",
						tool_input: { plan: claude.input.content, planFilePath: claude.input.file_path },
					},
					cwd,
					project,
				)
				outcome.block.push(...plan.block)
				outcome.ask.push(...plan.ask)
			}
			if (outcome.block.length) throw new Error(outcome.block.join("\n\n"))
			if (outcome.ask.length) {
				await ctx.permission.assert({
					sessionID: event.sessionID,
					agent: event.agent,
					source: { type: "tool", messageID: event.messageID, id: event.id },
					action: event.tool,
					resources: [claude.input.command ?? claude.input.file_path ?? claude.name],
					metadata: { reason: outcome.ask.join("\n\n") },
				})
			}
		})

		await optional(() => ctx.tool.hook("execute.after", async (event: any) => {
			if (event.status !== "completed") return
			try {
				const { directory } = await sessionInfo(event.sessionID)
				const project = projectRoot(directory)
				const claude = toClaude(event.tool, event.input, directory)
				const hooks = hooksFor("PostToolUse", claude.name, [...staticSources, ...projectSources(project)])
				if (!hooks.length) return
				const response = event.result?.output ?? event.result?.content
				const outcome = await runAll(
					hooks,
					"PostToolUse",
					{ session_id: event.sessionID, tool_name: claude.name, tool_input: claude.input, tool_response: response },
					directory,
					project,
				)
				// The tool already ran, so a block only reaches the model as
				// feedback on the result, the same as in Claude Code.
				const notes = [...outcome.block, ...outcome.context]
				if (notes.length) event.result = appendToResult(event.result, `PostToolUse hook feedback:\n${notes.join("\n\n")}`)
			} catch {}
		}))

		// Consecutive Stop blocks per session; cleared once a stop goes through.
		const stopBlocks = new Map<string, number>()
		await optional(() => ctx.session.hook("experimental.idle", async (event: any) => {
			try {
				// The session's own shell or subagent is still running; the hook
				// runs again when that work finishes.
				if ((event.background ?? []).some((work: any) => work?.sessionID === event.sessionID)) return
				const { directory, child } = await sessionInfo(event.sessionID)
				// Claude Code's Stop is for the main agent; subagents have SubagentStop.
				if (child) return
				const project = projectRoot(directory)
				const hooks = hooksFor("Stop", undefined, [...staticSources, ...projectSources(project)])
				if (!hooks.length) return
				const attempts = stopBlocks.get(event.sessionID) ?? 0
				const outcome = await runAll(
					hooks,
					"Stop",
					{ session_id: event.sessionID, stop_hook_active: attempts > 0 },
					directory,
					project,
				)
				if (!outcome.block.length || attempts >= MAX_STOP_BLOCKS) {
					stopBlocks.delete(event.sessionID)
					return
				}
				stopBlocks.set(event.sessionID, attempts + 1)
				await ctx.session.synthetic({
					sessionID: event.sessionID,
					text: `Stop hook feedback:\n${outcome.block.join("\n\n")}`,
				})
			} catch {}
		}))

		await optional(() => ctx.session.hook("prompt", async (event: any) => {
			const { directory } = await sessionInfo(event.sessionID)
			const project = projectRoot(directory)
			const hooks = hooksFor("UserPromptSubmit", undefined, [...staticSources, ...projectSources(project)])
			if (!hooks.length || typeof event.prompt?.text !== "string") return
			const outcome = await runAll(
				hooks,
				"UserPromptSubmit",
				{ session_id: event.sessionID, prompt: event.prompt.text },
				directory,
				project,
			)
			if (outcome.block.length) throw new Error(outcome.block.join("\n\n"))
			if (outcome.context.length) {
				event.prompt.text += `\n\n<system-reminder>\n${outcome.context.join("\n\n")}\n</system-reminder>`
			}
		}))

		if (commands.size) {
			await optional(() => ctx.command.transform((editor: any) => {
				for (const command of commands.values()) {
					try {
						editor.add({
							name: command.name,
							...(command.description ? { description: command.description } : {}),
							execute: async ({ sessionID, prompt, delivery }: any) => {
								await ctx.session.prompt({
									...prompt,
									sessionID,
									text: renderCommand(command.body, prompt?.text ?? ""),
									delivery,
								})
							},
						})
					} catch {}
				}
			}))
		}

		// Names actually mirrored, so a server opencode.json defines itself keeps
		// whatever permissions it's given there.
		const mirrored = new Set<string>()
		if (mcpServers.size) {
			await ctx.mcp.transform((editor: any) => {
				for (const [name, config] of mcpServers) {
					if (editor.get(name) && !mirrored.has(name)) continue
					editor.set(name, config)
					mirrored.add(name)
				}
			})
			await ctx.permission.hook("evaluate", (event: any) => {
				if (event.effect !== "allow" || typeof event.action !== "string") return
				for (const name of mirrored) {
					if (READ_ONLY_MCP.has(name)) continue
					// OpenCode names an MCP tool's action `${server with "." → "_"}_${tool}`
					// (tool/runtime.ts in v2.3.2). The other spellings cover a future
					// release that sanitizes the server name like the tool name.
					const prefixes = new Set([
						name,
						name.replaceAll(".", "_"),
						name.replace(/[^A-Za-z0-9_-]/g, "_"),
						name.replace(/[^A-Za-z0-9_]/g, "_"),
					])
					if ([...prefixes].some((prefix) => event.action.startsWith(`${prefix}_`))) {
						event.effect = "ask"
						event.message = `${name} is a Claude Code MCP server mirrored into OpenCode; its tools ask before running.`
						return
					}
				}
			})
		}

		if (skills.length) {
			await ctx.skill.transform((editor: any) => {
				for (const skill of skills) if (!editor.get(skill.id)) editor.add(skill)
			})
		}

		// Attach the project's Claude Code memory to each new session. Session
		// instruction entries are an experimental OpenCode API, so any failure
		// just leaves the session without it.
		const controller = new AbortController()
		void (async () => {
			try {
				for await (const event of ctx.event.subscribe({ types: ["session.created"], signal: controller.signal })) {
					try {
						const data = event?.data ?? event?.properties ?? event
						const sessionID = data?.sessionID
						if (!sessionID) continue
						let directory = data?.location?.directory
						if (!directory) directory = (await ctx.session.get({ sessionID }))?.directory
						const value = memoryFor([directory, ctx.location?.project?.canonical, ctx.location?.directory])
						if (value) await ctx.session.instructions.entry.put({ sessionID, key: "claude-code-memory", value })
					} catch {}
				}
			} catch {}
		})()
		return () => controller.abort()
	},
}
