# Global instructions

Managed in [benbalter/dotfiles](https://github.com/benbalter/dotfiles) (public) and symlinked to `~/.claude/CLAUDE.md`; edit the file the symlink points to, not the link. Don't put anything private here. The same dotfiles also set up GitHub Codespaces, where the repo isn't at `~/.files` and nothing under macOS below applies.

How I like to work, write, and handle privacy is in [`preferences.md`](https://github.com/benbalter/dotfiles/blob/main/claude/preferences.md), linked to `~/.claude/rules/preferences.md`, where Claude Code loads it alongside this file. It's shared with claude.ai, where I paste it as my instructions (`script/claude-ai-prefs`), so keep it free of anything that only makes sense in Claude Code; Claude Code–specific additions go in the matching sections below.

## Environment

- Global npm CLIs are managed by [mise](https://mise.jdx.dev). To add one, put `"npm:<pkg>" = "latest"` under `[tools]` in [`~/.config/mise/config.toml`](https://github.com/benbalter/dotfiles/blob/main/.config/mise/config.toml) and run `mise install`; never `npm install -g` or a [`Brewfile`](https://github.com/benbalter/dotfiles/blob/main/Brewfile) `npm` entry.
- Put personal symlinks and shims in `~/.local/bin`: it's on `PATH` and user-writable, while `/usr/local/bin` needs sudo and `/opt/homebrew/bin` belongs to Homebrew.
- [`.gitconfig`](https://github.com/benbalter/dotfiles/blob/main/.gitconfig) sets `push.followTags`, so pushing a branch also pushes any annotated tag on its commits. Where a tag triggers a release or deploy, that ships it early. Don't create a release tag until I approve the release; otherwise push with `--no-follow-tags`.
- Never write secrets to disk or commit them.
- Treat clickops (changing a service by clicking through its UI, mine or yours via Claude in Chrome or DevTools) as a smell. Prefer config or infrastructure as code, or a repeatable script against the service's API or CLI, so the change is reviewable and can be rerun; failing that, a plugin, connector, or MCP server before the browser. If clicking really is the only way, say so, and note what would let us codify it next time.
- Once a service is managed as code (OpenTofu, a config repo), every write goes through that code, with no "pre-staging" through its API, an MCP server, or the dashboard. A plan-mode plan doesn't override this file; if they conflict, fix the plan.
- Chrome is my primary browser, signed in to my accounts. When a task does need a browser (reading a logged-in page, a flow with no API, checking a deployed site), use [Claude in Chrome](https://claude.com/chrome) first, before Chrome DevTools MCP, headless browsers, or `curl`. Fall back to those only for what it can't do, like Lighthouse audits or performance traces.
- On macOS, a [`guard-bash`](https://github.com/benbalter/dotfiles/blob/main/claude/hooks/guard-bash) hook denies the Bash commands these rules forbid. A denial means use the alternative it names, not find a way around it.
- The shell is [zsh](https://www.zsh.org), which doesn't word-split unquoted variables: `for r in $LIST` runs once with the whole string. Use an array (`for r in ${=LIST}` or `list=(a b c)`), or wrap bash-style loops in `bash <<'EOF' … EOF`.
- `gh api` prints an error body such as a 404 to stdout, so check its exit code, not whether it printed anything.
- For multi-line scripts, commit messages, PR bodies, or any text with quotes, `$`, or backticks, use a quoted heredoc (`<<'EOF'`) so the shell doesn't expand or mangle it. Pass it via `-F -` / `--body-file -` / stdin rather than nesting it inside a double-quoted `-m "…"` argument.

### macOS

- Dotfiles are checked out at `~/.files`.
- [Homebrew](https://brew.sh) is plain Homebrew at `/opt/homebrew`, owned by me (this Mac ran [Workbrew](https://workbrew.com) until 2026-10, so older notes may mention it). Never run `sudo brew` or chown that tree: files left owned by root or another user cause its "not writable" and lock errors, so fix the specific path brew names.
- Secrets live in 1Password. Use the [`op` CLI](https://developer.1password.com/docs/cli/) (e.g. `op run --env-file=.env`, where `.env` holds `op://` references, never secret values).
- Git commits are SSH-signed through [1Password's `op-ssh-sign`](https://developer.1password.com/docs/ssh/git-commit-signing/) (set in [`.gitconfig.macos`](https://github.com/benbalter/dotfiles/blob/main/.gitconfig.macos)). If `git commit` fails with `1Password: failed to fill whole buffer` / `fatal: failed to write commit object`, the signing prompt timed out or wasn't approved, and the repo is fine. Rerun it once; if that times out too, tell me it's waiting on 1Password and rerun it on my next message, rather than looping. Don't disable signing or pass `--no-gpg-sign`. When a commit is chained with `git push` / `gh pr create`, check it succeeded first. Tags are signed too (`tag.gpgSign`), so `git tag` needs `-m`.

## Code

- For new websites and web apps, use [Astro](https://astro.build), which my sites already run on, unless the project already uses another framework.
- For web UI styling, prefer [Tailwind CSS](https://tailwindcss.com) utilities over custom CSS unless the project already follows a different styling convention.
- Check for prior art before building, reverse-engineering, or proposing something new (a parser, client, validator, or other utility): first what the project already depends on, then well-maintained open source libraries, the web, GitHub, and my own repos in `~/projects` and on [github.com/benbalter](https://github.com/benbalter), where I may already have it as a workflow or script. Before opening a PR or issue, search for an open one that covers it (`gh pr list --search`, `gh search prs`). Write custom code only when nothing suitable exists, and say why. Every plan gets a `## Prior art` section saying what you searched, what turned up, and why each was or wasn't used; a [`require-prior-art`](https://github.com/benbalter/dotfiles/blob/main/claude/hooks/require-prior-art) hook rejects a plan without one, so search before designing.
- When a skill, doc, or what you remember disagrees with the installed package's types or `--help`, the installed version wins.
- Keep one source of truth. Edit the source, not generated or mirrored copies, and don't restate config or facts in a second file. If a copy is unavoidable, guard it with a test.
- Run the repo's lint, typecheck, and tests before committing. Lint and format only the files you touched, stage specific paths rather than `git add -A`, and never commit scratch output or generated artifacts.
- Don't pin GitHub Actions or Docker images to SHAs or digests; use floating version tags. The pin churn is noise I don't want.
- Before creating, archiving, deleting, or changing the visibility or settings of a repo, or adding or reshaping CI workflows and jobs, load the [`repo-and-ci-setup`](https://github.com/benbalter/dotfiles/blob/main/claude/skills/repo-and-ci-setup/SKILL.md) skill. It covers Renovate, the github-settings repo that owns repo settings, required status checks, and Actions minutes.

## Git and GitHub

- Shorthand I type (spell it out when you write back):
  - "cpm" or "shipit": commit and push to main, which ships to production where main deploys.
  - "opr": open a pull request (commit, branch first if on the default branch, push, `gh pr create`).
  - "mag": merge all green. Merge every PR under discussion whose checks pass, and report the rest (failing, pending, blocked by review rules, conflicting) rather than forcing or admin-merging them.
  - "gb": open the current repo on GitHub (`gh repo view --web`, like the [`gb` alias](https://github.com/benbalter/dotfiles/blob/main/lib/aliases)).
- Write down the why. Commit messages, PR bodies, and comments should say why a change was made, not just what changed.
- Never credit Claude in a commit or pull request: no `Co-Authored-By: Claude` trailer, even where a repo's older commits have one, and say so in every brief for an agent that commits. [`settings.json`](https://github.com/benbalter/dotfiles/blob/main/claude/settings.json) leaves `attribution` empty for this, and [`guard-bash`](https://github.com/benbalter/dotfiles/blob/main/claude/hooks/guard-bash) denies a commit that adds the trailer.
- On my solo, personal repos, pushing straight to the default branch past its protection rules (required PR, required checks) is the normal workflow, since I bypass them as the admin. Don't warn about the "Bypassed rule violations" message; do check the CI run the push triggers.
- Before pushing to a PR's branch, check that the PR is still open (`gh pr view <n> --json state`). I often merge while you're still working, and commits pushed after the merge never reach the default branch. If it's merged or closed, branch from the updated default branch, cherry-pick the new commits, and open a new PR. Check again after pushing, since a merge can land between the check and the push. Likewise, when a step waits on a merge ("once #123 merges"), check the PR's state yourself at the start of each turn instead of asking me to tell you, and carry on once it's merged.
- After a PR merges, or before starting unrelated work, switch to the default branch and pull. Always say which branch you left the repo on.
- After a deploy, load the live URL and confirm the change is there. A green build or deploy check proves the build ran, not that the site is serving it.
- **Never create a public repo, or make a private one public, without my explicit approval for that specific repo and visibility.** Approving a plan that says "public repo" is not that approval: ask with the question tool right before `gh repo create --public` or a visibility change, and default to `--private`. A public push can't be taken back. It may be cloned, cached, or indexed within minutes.
- Run audits across my repos against origin (`gh api …/contents`, or fetch first), not local checkouts: the ones in `~/projects` are often weeks behind.
- When writing a changelog or release notes, or merging a PR from outside the project's maintainers, load the [`credit-contributors`](https://github.com/benbalter/dotfiles/blob/main/claude/skills/credit-contributors/SKILL.md) skill, so external contributors get credited and thanked.

## Parallel sessions

I often run several Claude Code sessions in the same repo at once, so assume another session may be working in the same checkout, and coordinate rather than collide.

- Use `ListAgents` to see the other sessions on this machine and `SendMessage` to agree who owns which files and who commits, pushes, or switches branches. Check before starting anything that touches shared files.
- Treat changes you didn't make as another session's work in progress: don't revert, stash, reset, reformat, or commit them. Staging only your own paths matters doubly here.
- Switching branches, rebasing, or pulling in a shared checkout changes the tree under every other session there, so agree on it first. That includes the "switch to the default branch and pull" step under Git and GitHub. For work that needs its own branch, use a git worktree (`EnterWorktree`) instead.
- Remove a worktree when you're done with it: once its branch is merged or abandoned, `ExitWorktree` (or `git worktree remove`, then `git worktree prune`). Leftovers pile up under `.claude/worktrees` as full copies of the repo that Spotlight and git's fsmonitor keep re-scanning, which spins up the fan. Leave a worktree alone if another session (`ListAgents`) is still working in it, and never remove one with uncommitted or unpushed changes; tell me instead.
- Before committing or pushing, recheck `git status` and `git log`. If the branch moved, another session committed: build on its work rather than overwriting it, and never force-push over it.
- Don't push another session's commits. If `git log @{u}..` lists one that isn't yours, wait until that session or I explicitly say to push it, or until it pushes first. "If you push before me, rebase over it" isn't consent: pushing ships its work, and on a branch that deploys, that's production.
- If sessions deadlock over who goes first or who owns a file, settle it with the [`roll-for-initiative`](https://github.com/benbalter/dotfiles/blob/main/claude/skills/roll-for-initiative/SKILL.md) skill rather than waiting on me.
- If the conflict is about what the right change is, not just who goes first, ask me.

## Working with me in Claude Code

- Before changing how something works, find out why it's that way (`git log`, `git blame`, linked issues). Say what you found when it bears on the change.
- Ship the smallest useful change, then iterate. "Smallest" limits scope; it isn't a reason to stop early. When you find in-scope, reversible fixes, make them rather than listing them for me to approve. Ask first only about destructive or outward-facing steps (merge, publish, send, deploy) or real judgment calls. Deleting anything whose history can't be recovered (an analytics site, logs, a database) always needs my explicit OK, even when it looks orphaned.
- An MFA step that's a link plus a passkey tap isn't a blocker: drive it, and I'll approve the prompt.
- Size multi-agent runs (subagents, workflows, skills that fan out) to the target. Before launching one, say in one line what depth or effort level you picked and the most agents it will run, and pick the lightest one a skill offers for a small repo. Don't raise that cap mid-run; offer the deeper pass as a follow-up I can opt into.
- On long or background work, post a one-line status periodically and say what you're waiting on.
- When you create, edit, or point me to a local file, link it by absolute path (`[name.md](/abs/path/name.md)`).
- Estimate development time as Claude doing the work with me reviewing it, not as a human developer would: hours, not days or weeks.

## Privacy in Claude Code

- Leaks of private data happen at the private-to-public boundary, when a figure from me, a private repo, or a connected tool becomes the justification in a public commit or PR. Before you commit, push, or open a PR or issue, check the repo's visibility (`gh repo view --json visibility`) rather than assuming, and if it's public, reread the message, body, and diff for any number or detail that didn't come from that repo's own public contents. Rewrite it qualitatively before it ships; a pushed commit message can't be quietly fixed.
- Before any photo, video, or screenshot goes anywhere public (a post, README, issue, or PR), run the [`media-privacy-pass`](https://github.com/benbalter/dotfiles/blob/main/claude/skills/media-privacy-pass/SKILL.md) skill.

## Writing in Claude Code

- The `writing-style` skill lives in my private [benbalter/writing-style](https://github.com/benbalter/writing-style) repo. On macOS, [`script/update`](https://github.com/benbalter/dotfiles/blob/main/script/update) keeps a clone at `~/projects/writing-style` linked into `~/.claude/skills`; elsewhere (Codespaces), read `SKILL.md` with `gh api repos/benbalter/writing-style/contents/SKILL.md -H 'Accept: application/vnd.github.raw'`. Open its `references/long-form.md` (blog posts and other long-form writing) and `references/language.md` (grammar lookups) only when the task needs them.
- `writing-style` already folds in `no-ai-slop`'s editing rules, so don't load that skill too. Use `stop-slop` only as a detection checklist, since several of its rules fight my voice. A repo's own style guide overrides both.
- Whenever you draft or revise text I'll paste elsewhere (email, message, post, PR or issue comment) or an event for my calendar, load the [`draft-for-paste`](https://github.com/benbalter/dotfiles/blob/main/claude/skills/draft-for-paste/SKILL.md) skill. It covers the clipboard copy and LinkedIn formatting.

## Writing CLAUDE.md files

- Link liberally and inline whenever a CLAUDE.md mentions a file, tool, service, doc, issue, or PR: link the mention itself rather than adding a separate list of links. Use relative paths for files in the same repo, and full URLs for anything a symlinked or global CLAUDE.md points to, since relative links break once it's read from somewhere else.
