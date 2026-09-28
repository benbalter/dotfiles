# Global instructions

Managed in `~/.files` ([benbalter/dotfiles](https://github.com/benbalter/dotfiles), public)
and symlinked to `~/.claude/CLAUDE.md`. Don't put anything private here.

## Environment

- Dotfiles live in `~/.files`. Edit them there, not the symlinks in `$HOME`.
- On macOS, [Homebrew](https://brew.sh) is wrapped by
  [Workbrew](https://workbrew.com): `brew` runs as the `workbrew`
  user. Ownership, lock, and "not writable" errors under `/opt/homebrew`
  usually trace back to that, not to a broken install.
- Global npm CLIs are managed by [mise](https://mise.jdx.dev)
  ([`~/.config/mise/config.toml`](https://github.com/benbalter/dotfiles/blob/main/.config/mise/config.toml)), not
  [`Brewfile`](https://github.com/benbalter/dotfiles/blob/main/Brewfile) `npm` entries.
- Secrets live in 1Password. Use the
  [`op` CLI](https://developer.1password.com/docs/cli/) (e.g. `op run --env-file=.env`)
  and never write secrets to disk or commit them.

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
