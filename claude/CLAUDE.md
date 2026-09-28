# Global instructions

Managed in ~/.files (github.com/benbalter/dotfiles, public) and symlinked to
~/.claude/CLAUDE.md. Don't put anything private here.

## Environment

- Dotfiles live in `~/.files`. Edit them there, not the symlinks in `$HOME`.
- On macOS, Homebrew is wrapped by Workbrew: `brew` runs as the `workbrew`
  user. Ownership, lock, and "not writable" errors under `/opt/homebrew`
  usually trace back to that, not to a broken install.
- Global npm CLIs are managed by mise (`~/.config/mise/config.toml`), not
  Brewfile `npm` entries.
- Secrets live in 1Password. Use the `op` CLI (e.g. `op run --env-file=.env`)
  and never write secrets to disk or commit them.

## Code

- For web UI styling, prefer Tailwind CSS utilities over custom CSS unless the
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
