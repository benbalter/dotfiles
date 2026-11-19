// OpenCode plugin: read Claude Code's own config at runtime instead of keeping
// copies of it in opencode.json, so the two agents can't drift apart.
//
// - Bash hooks: runs the PreToolUse hooks Claude Code runs for Bash (such as
//   claude/hooks/guard-bash) on OpenCode's shell calls, in Claude's hook format.
// - Plugins: loads the skills and MCP servers of every Claude Code plugin that
//   enabledPlugins turns on, from the copies Claude Code keeps updated.
// - MCP: loads the user-level MCP servers from ~/.claude.json. They're read
//   here at runtime, so private hosts never land in this public repo.
//
// Everything fails open: a missing or unreadable file skips that part rather
// than breaking OpenCode. Config set in opencode.json always wins.
import { spawnSync } from "node:child_process"
import { existsSync, readdirSync, readFileSync } from "node:fs"
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

// --- Bash hooks ---

function matchesTool(matcher: unknown, tool: string) {
	if (matcher === undefined || matcher === "" || matcher === "*") return true
	if (typeof matcher !== "string") return false
	try {
		return new RegExp(`^(?:${matcher})$`).test(tool)
	} catch {
		return false
	}
}

const bashHooks: { command: string; timeout?: number }[] = settings
	.flatMap((s) => s?.hooks?.PreToolUse ?? [])
	.filter((entry: any) => matchesTool(entry?.matcher, "Bash"))
	.flatMap((entry: any) => entry?.hooks ?? [])
	.filter((hook: any) => hook?.type === "command" && typeof hook.command === "string")

type Verdict = { effect: "deny" | "ask"; reason: string } | undefined

function runHook(hook: { command: string; timeout?: number }, command: string, cwd: string): Verdict {
	const input = JSON.stringify({ hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: { command }, cwd })
	const run = spawnSync("/bin/sh", ["-c", hook.command], {
		input,
		cwd: existsSync(cwd) ? cwd : undefined,
		encoding: "utf8",
		timeout: (hook.timeout ?? 60) * 1000,
		env: { ...process.env, CLAUDE_PROJECT_DIR: cwd },
	})
	// Exit 2 is Claude's "block, and show stderr to the model".
	if (run.status === 2) return { effect: "deny", reason: run.stderr.trim() || `Blocked by ${hook.command}` }
	if (run.status !== 0 || !run.stdout.trim()) return undefined
	let out: any
	try {
		out = JSON.parse(run.stdout)
	} catch {
		return undefined
	}
	const specific = out?.hookSpecificOutput
	const reason = specific?.permissionDecisionReason || out?.reason || `Blocked by ${hook.command}`
	if (specific?.permissionDecision === "deny" || out?.decision === "block") return { effect: "deny", reason }
	if (specific?.permissionDecision === "ask") return { effect: "ask", reason }
	return undefined
}

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

// --- Plugin ---

export default {
	id: "dotfiles.claude-code",
	async setup(ctx: any) {
		if (bashHooks.length) {
			await ctx.tool.hook("execute.before", async (event: any) => {
				if (event.tool !== "shell") return
				const { command, workdir } = (event.input ?? {}) as { command?: string; workdir?: string }
				if (!command) return
				const cwd = workdir ?? ctx.location?.directory ?? process.cwd()
				for (const hook of bashHooks) {
					const verdict = runHook(hook, command, cwd)
					if (verdict?.effect === "deny") throw new Error(verdict.reason)
					if (verdict?.effect === "ask") {
						await ctx.permission.assert({
							sessionID: event.sessionID,
							agent: event.agent,
							source: { type: "tool", messageID: event.messageID, id: event.id },
							action: "shell",
							resources: [command],
							metadata: { reason: verdict.reason },
						})
					}
				}
			})
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
					const prefixes = new Set([name, name.replace(/[^A-Za-z0-9_]/g, "_")])
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
	},
}
