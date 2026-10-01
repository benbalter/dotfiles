# Global instructions

Managed in [benbalter/dotfiles](https://github.com/benbalter/dotfiles) (public)
and symlinked to `~/.claude/CLAUDE.md`; edit the file the symlink points to,
not the link. Don't put anything private here. The same dotfiles also set up
GitHub Codespaces, where the repo is not at `~/.files` and nothing under
macOS below applies.

## Environment

- Global npm CLIs are managed by [mise](https://mise.jdx.dev). To add one,
  put `"npm:<pkg>" = "latest"` under `[tools]` in
  [`~/.config/mise/config.toml`](https://github.com/benbalter/dotfiles/blob/main/.config/mise/config.toml)
  and run `mise install`; never `npm install -g` or a
  [`Brewfile`](https://github.com/benbalter/dotfiles/blob/main/Brewfile) `npm` entry.
- Put personal symlinks and shims in `~/.local/bin`: it's on `PATH` and
  user-writable, while `/usr/local/bin` needs sudo and `/opt/homebrew/bin`
  belongs to `workbrew`.
- [`.gitconfig`](https://github.com/benbalter/dotfiles/blob/main/.gitconfig)
  sets `push.followTags`, so pushing a branch also pushes any annotated tag
  on its commits. Where a tag triggers a release or deploy, that ships it
  early. Don't create a release tag until I approve the release; otherwise
  push with `--no-follow-tags`.
- Never write secrets to disk or commit them.
- The shell is [zsh](https://www.zsh.org), which doesn't word-split unquoted
  variables: `for r in $LIST` runs once with the whole string. Use an array
  (`for r in ${=LIST}` or `list=(a b c)`), or wrap bash-style loops in
  `bash <<'EOF' … EOF`.
- For multi-line scripts, commit messages, PR bodies, or any text with
  quotes, `$`, or backticks, use a quoted heredoc (`<<'EOF'`) so the shell
  doesn't expand or mangle it. Pass it via `-F -` / `--body-file -` / stdin
  rather than nesting it inside a double-quoted `-m "…"` argument.

### macOS

- Dotfiles are checked out at `~/.files`.
- [Homebrew](https://brew.sh) is wrapped by [Workbrew](https://workbrew.com):
  `brew` runs as the `workbrew` user, and everything under `/opt/homebrew`
  must stay owned by `workbrew`. Ownership, lock, and "not writable" errors
  there usually trace back to that, not to a broken install; never chown
  that tree to my user or run `sudo brew` to get past one. Call `brew` (the
  `/opt/workbrew/bin/brew` wrapper), never `/opt/homebrew/bin/brew`
  directly, which fails with a "conflicting Homebrew wrapper configuration"
  error.
- Secrets live in 1Password. Use the
  [`op` CLI](https://developer.1password.com/docs/cli/) (e.g. `op run --env-file=.env`,
  where `.env` holds `op://` references, never secret values).
- Git commits are SSH-signed through
  [1Password's `op-ssh-sign`](https://developer.1password.com/docs/ssh/git-commit-signing/)
  (set in [`.gitconfig.macos`](https://github.com/benbalter/dotfiles/blob/main/.gitconfig.macos)).
  If `git commit` fails with `1Password: failed to fill whole buffer` /
  `fatal: failed to write commit object`, the signing prompt timed out or
  wasn't approved. Nothing is wrong with the repo: rerun the same commit
  once so 1Password prompts again. If that fails too, stop and ask me to
  approve the prompt rather than retrying. Don't disable signing or pass
  `--no-gpg-sign`. When a commit is chained with `git push` /
  `gh pr create`, check it succeeded before pushing or opening the PR.

## Code

- For web UI styling, prefer [Tailwind CSS](https://tailwindcss.com)
  utilities over custom CSS unless the
  project already follows a different styling convention.
- Prefer established open source libraries over custom code. Before writing
  a parser, client, validator, or other utility, check whether the project
  already depends on something that does it, then look for a well-maintained
  library. Write custom code only when no suitable library exists, and say
  why.

## Working with me

- Be direct and candid, professional but not formal. Back recommendations
  with facts or data, and tell me when I'm wrong; I'd rather the better idea
  win.
- Bring a proposed fix, not just a problem, and ask *why* before doing
  what everyone else does.
- Before changing how something works, find out why it's that way (`git log`,
  `git blame`, linked issues). Say what you found when it bears on the change.
- Ship the smallest useful change, then iterate.
- Everything should have a URL: when you mention an issue, PR, commit, doc,
  or run that has one, link it. Local files count too: when you create,
  edit, or point me to a file, give a clickable markdown link with its
  absolute path (`[name.md](/abs/path/name.md)`), so I don't have to ask
  where it is.
- Write down the why. Commit messages, PR bodies, and comments should say
  why a change was made, not just what changed.
- Don't hand me work a script or tool could do. Automate it or do it
  yourself, and ask only for decisions and approvals that are mine to make.
- When I need to make a choice, ask with the multiple-choice question tool
  (2–4 options, recommended first) rather than in prose.
- In public repos, keep private figures (traffic, revenue, compensation)
  out of commit messages, PR and issue text, code comments, and committed
  docs. Describe them qualitatively instead.
- Record timelines in the words someone used ("7–10 days"), not a calendar
  date I didn't give. If a derived date helps, show it as a range with the
  math.
- Estimate development time as Claude doing the work with me reviewing it,
  not as a human developer would: hours, not days or weeks.
- A draft isn't the message I sent; I usually rewrite before sending. When a
  decision turns on what someone actually received, ask me for the sent text.
- When editing my prose, use the `no-ai-slop` skill, which preserves voice.
  Use `stop-slop` only as a detection checklist, since several of its rules
  fight my voice. A repo's own style guide overrides both.

## Drafting text for me to paste

- The terminal renders a quote bar alongside drafted text, and it comes along
  when I copy. So once a draft I'll paste elsewhere (email, message, comment)
  is final, show it and also put it on my clipboard with `pbcopy` (macOS
  only), so I can paste it clean. Use a quoted heredoc
  (`pbcopy <<'EOF'`) so the shell doesn't mangle quotes or `$`.
- When drafting a new email, also give me a Gmail compose link that prefills
  it: `https://mail.google.com/mail/?view=cm&fs=1&to=…&cc=…&bcc=…&su=…&body=…`,
  with every value URL-encoded (newlines as `%0A`). Omit empty fields.

## Writing CLAUDE.md files

- Link liberally and inline whenever a CLAUDE.md mentions a file, tool,
  service, doc, issue, or PR: link the mention itself rather than adding a
  separate list of links. Use relative paths for files in the same repo, and
  full URLs for anything a symlinked or global CLAUDE.md points to, since
  relative links break once it's read from somewhere else.
