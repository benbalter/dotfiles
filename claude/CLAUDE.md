# Global instructions

Managed in [benbalter/dotfiles](https://github.com/benbalter/dotfiles) (public)
and symlinked to `~/.claude/CLAUDE.md`; edit the file the symlink points to,
not the link. Don't put anything private here. The same dotfiles also set up
GitHub Codespaces, where the repo is not at `~/.files` and nothing under
macOS below applies.

## Environment

- Global npm CLIs are managed by [mise](https://mise.jdx.dev)
  ([`~/.config/mise/config.toml`](https://github.com/benbalter/dotfiles/blob/main/.config/mise/config.toml)), not
  [`Brewfile`](https://github.com/benbalter/dotfiles/blob/main/Brewfile) `npm` entries.
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
  that tree to my user or run `sudo brew` to get past one.
- Secrets live in 1Password. Use the
  [`op` CLI](https://developer.1password.com/docs/cli/) (e.g. `op run --env-file=.env`,
  where `.env` holds `op://` references, never secret values).
- Git commits are SSH-signed through
  [1Password's `op-ssh-sign`](https://developer.1password.com/docs/ssh/git-commit-signing/)
  (set in [`.gitconfig.macos`](https://github.com/benbalter/dotfiles/blob/main/.gitconfig.macos)).
  If `git commit` fails with `1Password: failed to fill whole buffer` /
  `fatal: failed to write commit object`, the signing prompt timed out or
  wasn't approved. Nothing is wrong with the repo: rerun the same commit so
  1Password prompts again. Don't disable signing or pass `--no-gpg-sign`. When
  a commit is chained with `git push` / `gh pr create`, check it succeeded
  before pushing or opening the PR.

## Code

- For web UI styling, prefer [Tailwind CSS](https://tailwindcss.com)
  utilities over custom CSS unless the
  project already follows a different styling convention.
- Prefer established open source libraries over custom code. Before writing
  a parser, client, validator, or other utility, check whether the project
  already depends on something that does it, then look for a well-maintained
  library. Write custom code only when no suitable library exists, and say
  why.

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
