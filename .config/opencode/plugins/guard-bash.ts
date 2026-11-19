// OpenCode plugin: run each shell command past claude/hooks/guard-bash, the
// same check Claude Code runs as a PreToolUse hook, so the rules in
// claude/CLAUDE.md hold in OpenCode too without a second copy of them.
// guard-bash reads Claude's hook JSON; this adapts OpenCode's shell call to it
// and turns a deny into a rejected tool call that carries guard-bash's reason.
import { spawnSync } from "node:child_process"
import { existsSync, realpathSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

// This file is a symlink into the dotfiles repo. Resolving it finds the repo
// wherever it's checked out (~/.files on macOS, elsewhere in Codespaces).
const repo = path.resolve(path.dirname(realpathSync(fileURLToPath(import.meta.url))), "../../..")
const guard = path.join(repo, "claude/hooks/guard-bash")

export default {
	id: "dotfiles.guard-bash",
	async setup(ctx: any) {
		await ctx.tool.hook("execute.before", (event: any) => {
			if (event.tool !== "shell" || !existsSync(guard)) return
			const { command, workdir } = (event.input ?? {}) as { command?: string; workdir?: string }
			if (!command) return
			const input = JSON.stringify({
				tool_input: { command },
				cwd: workdir ?? ctx.location?.directory ?? process.cwd(),
			})
			const run = spawnSync(guard, { input, encoding: "utf8", timeout: 10_000 })
			// Like guard-bash without jq: never break the shell tool over the guard itself.
			if (run.status !== 0 || !run.stdout.trim()) return
			let out: any
			try {
				out = JSON.parse(run.stdout)
			} catch {
				return
			}
			const decision = out?.hookSpecificOutput
			if (decision?.permissionDecision === "deny") throw new Error(decision.permissionDecisionReason)
		})
	},
}
