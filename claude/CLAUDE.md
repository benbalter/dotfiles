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
