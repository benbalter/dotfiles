# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal dotfiles (public repo `benbalter/dotfiles`, checked out at `~/.files`) that set up macOS and Fedora Asahi Remix with Ansible, with Homebrew as the package manager on both.

## Commands

```sh
script/bootstrap   # create the Python venv (env/) and install Ansible roles/collections
script/setup       # bootstrap + run the full playbook (prompts for sudo)
script/update      # update everything; aliased to `up`, also runs nightly headless
script/lint        # ansible-lint, yamllint, shellcheck, shfmt, actionlint, rubocop, remark
script/test        # the whole BATS suite (bats test/)
```

- Run one test file: `bats test/config.bats`. Run one test by name: `bats test/config.bats -f 'install.sh links'`.
- Run part of the playbook: `. env/bin/activate && ansible-playbook playbook.yml --tags dotfiles --ask-become-pass`. Tags include `dotfiles`, `packages`, `mise`, `claude`, `macos`, `defaults`, `security`, `fedora`, `homebrew`.
- Preview playbook changes without applying them: add `--check --diff`.
- ansible-lint and yamllint run from the venv, so run `script/bootstrap` first on a fresh checkout.

## Architecture

**Entry points.** `install.sh` is the Codespaces entry point. On macOS, and on Fedora unless `DOTFILES_SIMPLE_INSTALL=1` or in Codespaces, it just `exec`s `script/setup`, which runs `playbook.yml`. Otherwise it runs its own symlink-only path. That makes `install.sh` a second, hand-maintained copy of the dotfile list.

**`config.yml` drives the playbook.** It holds the dotfile lists, macOS defaults, Fedora packages and directories. Lists are split `*_common` / `*_macos` / `*_linux` and combined using `is_macos`, which the playbook sets in `pre_tasks`. `config_ci.yml` is layered on top when `CI` is set. Tasks that shouldn't run in CI are guarded with `when: not is_ci`.

**Adding a dotfile** touches several places, and `test/config.bats` fails if they drift apart:

- If it sits at the same path in the repo and in `$HOME`, add it to `dotfiles_files_common`, `_macos` or `_linux`.
- If the paths differ, add a `src`/`dest` pair to `dotfile_links_common` or `linux_dotfile_links`. For example, configs under `Library/Application Support/...` on macOS go to `~/.config/...` on Linux.
- Every common entry must also be linked in `install.sh`.
- The playbook moves any existing non-symlink target to `.bak` before linking.

**Homebrew.** One `Brewfile` serves both platforms, and `.Brewfile` is a symlink to it so `brew bundle --global` finds it.

- On Linux, `cask`/`mas` entries are skipped automatically, and macOS-only formulae are skipped via `HOMEBREW_BUNDLE_BREW_SKIP` (`homebrew_linux_brew_skip` in `config.yml`).
- On this Mac, Homebrew is wrapped by **Workbrew**: `brew` runs as the `workbrew` user through `/opt/workbrew/bin/brew`. The playbook detects the wrapper and skips the `geerlingguy.mac.homebrew` role, whose chown tasks break Workbrew. Brew errors about ownership or locks usually trace back to Workbrew.
- Global npm CLIs belong in `.config/mise/config.toml` as `npm:` entries, not in the Brewfile, which conflicts with Workbrew's node prefix.

**`script/update` runs headless** from a nightly launchd job with a minimal `PATH` and no TTY. Anything interactive (sudo prompts, cask upgrades, `script/audit-casks`, mole) must be guarded with `[ -t 1 ]`. Each step ends with `|| true` so one failure doesn't stop the rest.

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
- CI (`.github/workflows/ci.yml`) runs the full playbook on macOS and in a Fedora container, runs `brew bundle` on x86_64 and aarch64 Linux, and runs lint, BATS, and an `install.sh` check on Ubuntu.
