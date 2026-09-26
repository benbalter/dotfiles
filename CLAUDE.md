# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal dotfiles (public repo `benbalter/dotfiles`, checked out at `~/.files`) that set up macOS with Ansible and Homebrew. The only Linux target is GitHub Codespaces (and other containers), which get a symlink-only install from `install.sh`.

## Commands

```sh
script/bootstrap   # create the Python venv (env/) and install Ansible collections
script/setup       # bootstrap + run the full playbook (prompts for sudo)
script/update      # update everything; aliased to `up`, also runs nightly headless
script/lint        # ansible-lint, yamllint, shellcheck, shfmt, actionlint, rubocop, remark
script/test        # the whole BATS suite (bats test/)
script/doctor      # read-only health check: symlinks, .bak files, brew wrapper, launch agents, last update, packages, security
```

- Run one test file: `bats test/config.bats`. Run one test by name: `bats test/config.bats -f 'install.sh links'`.
- Run part of the playbook: `. env/bin/activate && ansible-playbook playbook.yml --tags dotfiles --ask-become-pass`. Tags include `dotfiles`, `packages`, `mise`, `claude`, `macos`, `defaults`, `security`, `launchagents`, `homebrew`.
- Preview playbook changes without applying them: add `--check --diff`.
- ansible-lint and yamllint run from the venv, so run `script/bootstrap` first on a fresh checkout.

## Architecture

**Entry points.** `install.sh` is the Codespaces entry point. On macOS it just `exec`s `script/setup`, which runs `playbook.yml`. On Linux it runs its own symlink-only path (common dotfiles, oh-my-zsh, and `script/install-tools` for delta/zoxide/fzf via mise). That makes `install.sh` a second, hand-maintained copy of the dotfile list. The playbook is macOS-only and fails fast elsewhere.

**`config.yml` drives the playbook.** It holds the dotfile lists, macOS defaults and directories. Lists are split `*_common` (linked everywhere, including by `install.sh`) and `*_macos` (playbook only). Tasks that shouldn't run in CI (anything that changes the runner's system or security settings) are guarded with `when: not is_ci`.

**Adding a dotfile** touches several places, and `test/config.bats` fails if they drift apart:

- If it sits at the same path in the repo and in `$HOME`, add it to `dotfiles_files_common` or `dotfiles_files_macos`.
- If the paths differ, add a `src`/`dest` pair to `dotfile_links_common`.
- Every common entry must also be linked in `install.sh`. Anything that breaks without macOS or a desktop (1Password agent or signer, pinentry-mac, gh as the only git credential helper) belongs in the macOS list, or it breaks Codespaces. Commit signing and the gh credential helper live in `.gitconfig.macos` for this reason: in `.gitconfig` they overrode Codespaces' own signing and credentials, and every commit failed.
- The playbook and `install.sh` move any existing non-symlink target to `.bak` (or `.bak.<epoch>` if a `.bak` already exists) before linking.

**Homebrew.** The `Brewfile` is macOS-only, and `.Brewfile` is a symlink to it so `brew bundle --global` finds it. `script/update`, `script/doctor` and `script/clean` skip Homebrew on Linux.

- On this Mac, Homebrew is wrapped by **Workbrew**: `brew` runs as the `workbrew` user through `/opt/workbrew/bin/brew`. The playbook detects the wrapper and skips the `geerlingguy.mac.homebrew` role, whose chown tasks break Workbrew. Brew errors about ownership or locks usually trace back to Workbrew.
- Global npm CLIs belong in `.config/mise/config.toml` as `npm:` entries, not in the Brewfile, which conflicts with Workbrew's node prefix.

**`script/update` runs headless** from a nightly launchd job with a minimal `PATH` and no TTY. Anything interactive (sudo prompts, cask upgrades, `script/audit-casks`, mole) must be guarded with `[ -t 1 ]`. Wrap each step in `step`, which records a failure without stopping the rest; the run exits 1 with a list of failed steps, and records the run in `~/.local/state/dotfiles/update-status` for `script/doctor`.

**macOS defaults.** `macos_defaults.system` entries run with `become: true`, so they must use an absolute domain path like `/Library/Preferences/com.apple.foo`. A bare domain writes to root's preferences and has no effect, yet the task still reports success. The playbook reads back each value it writes to catch this. Firewall settings go through `socketfilterfw`, not `defaults`.

**`lib/`** (`globals`, `aliases`, `auto-complete`) is sourced by interactive `.zshrc`, so never add `set -e` or `set -u` there.

**`claude/`** holds the global Claude Code config:

- `CLAUDE.md` is symlinked to `~/.claude/CLAUDE.md`.
- `settings.json` is *merged* into `~/.claude/settings.json` by the playbook's `claude` tag. It isn't symlinked because Claude Code replaces the file when it saves.
- Keep `autoMode` and `permissions` out of `claude/settings.json`. They name private hosts and this repo is public; a test enforces it.
- The folder is `claude/`, not `.claude/`, so it isn't also loaded as this repo's project config.

## Conventions

- Shell scripts are POSIX `sh` and start with `set -eu` plus the `(set -o pipefail) 2>/dev/null && set -o pipefail || true` idiom. shfmt enforces tab indentation (`-i 0 -ci`).
- Ansible uses fully qualified module names (`ansible.builtin.*`), and tasks must be idempotent: use `creates:`, `changed_when`, or a stat/check task before a command.
- BATS tests use the `fail()` from `test/test_helper.bash`. bats-support/bats-assert are deliberately not vendored, so the suite runs the same under brew bats-core and apt bats.
- Comments explain *why*, often citing the specific breakage that motivated a workaround. Keep that when editing nearby code.
- CI (`.github/workflows/ci.yml`) runs the full playbook on macOS, lint on Ubuntu, BATS on macOS and Ubuntu, and the Codespaces path on Ubuntu (`install.sh`, then zsh loads and git can commit). It also runs weekly.
- `script/lint` runs every linter and lists all failures; add new linters with its `lint` helper rather than a bare command, so one failure can't hide the rest.
- `script/update`, `script/doctor` and `script/clean` read the repo's `Brewfile` directly (not `--global`), so they work before setup links `~/.Brewfile`. Headless, `update` skips casks and `mas` apps.
- In `lib/aliases`, `clean` runs `script/clean`; the git merged-branch cleanup is `gclean`, and `git reset --hard` + `git clean` is `greset`.
