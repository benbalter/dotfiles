# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal dotfiles (public repo `benbalter/dotfiles`, checked out at `~/.files`) that set up macOS with Ansible and Homebrew. The only Linux target is GitHub Codespaces (and other containers), which get a symlink-only install from `install.sh`.

## Commands

```sh
script/bootstrap   # create the Python venv (env/) and install Ansible collections
script/setup       # bootstrap + run the full playbook (prompts for sudo); --work (or --personal) records the Mac's profile first
script/update      # update everything; aliased to `up`, also runs nightly headless
script/lint        # ansible-lint, yamllint, shellcheck, shfmt, actionlint, rubocop, remark
script/test        # the whole BATS suite (bats test/)
script/doctor      # read-only health check: symlinks, .bak files, brew wrapper, launch agents, last update, packages, security, defaults
script/audit-defaults   # flag config.yml Apple defaults keys that no system binary contains (likely dead)
script/bench-shell      # time zsh startup and command lag with zsh-bench, against its noticeable thresholds
script/install-git-hooks # copy the gitleaks pre-commit hook (.config/git/template) into existing repos under ~/projects
```

- Run one test file: `bats test/config.bats`. Run one test by name: `bats test/install.bats -f 'install.sh links'`.
- Run part of the playbook: `. env/bin/activate && ansible-playbook playbook.yml --tags dotfiles --ask-become-pass`. Tags: `dotfiles`, `directories`, `packages`, `homebrew`, `mise`, `claude`, `languagetool`, `ohmyzsh`, `macos`, `defaults`, `dock`, `security`, `launchagents`.
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

- This Mac runs plain Homebrew, owned by the login user. The repo still supports a **Workbrew**-managed Mac (where `brew` runs as the `workbrew` user through `/opt/workbrew/bin/brew`): the playbook, `lib/globals`, `script/update` and `script/doctor` detect the wrapper and adapt, and the playbook skips the `geerlingguy.mac.homebrew` role there, whose chown tasks break Workbrew. CI covers only the plain-Homebrew path.
- Global npm CLIs belong in `.config/mise/config.toml` as `npm:` entries, not in the Brewfile. They first moved there because Brewfile `npm` entries failed against Workbrew's node prefix; mise also keeps them independent of Homebrew's node.

**`script/update` runs headless** from a nightly launchd job with a minimal `PATH` and no TTY. Anything interactive (sudo prompts, cask upgrades, `script/audit-casks`, mole) must be guarded with `[ -t 1 ]`. Wrap each step in `step`, which records a failure without stopping the rest; the run exits 1 with a list of failed steps, and records the run in `~/.local/state/dotfiles/update-status` for `script/doctor`.

**macOS defaults.** `macos_defaults.system` entries run with `become: true`, so they must use an absolute domain path like `/Library/Preferences/com.apple.foo`. A bare domain writes to root's preferences and has no effect, yet the task still reports success. The playbook reads back each system default and fails unless it matches `config.yml`, which catches this. Unlike other system changes, these deliberately run in CI so that read-back is exercised. Some keys are stripped by their daemon after the write (`AutomaticCheckEnabled`); drive those through their CLI instead. Firewall settings go through `socketfilterfw`, not `defaults`, and automatic update checks through `softwareupdate --schedule`. A read-back can't tell when macOS has stopped reading a key altogether; `script/audit-defaults` checks for that (run it before adding a key).

`macos_defaults.user` entries marked `all_users: true` are a security baseline that's also written, as each user, for every other local login. The playbook finds those logins with [`script/other-users`](script/other-users) (`dscl`: UID ≥ 501, a login shell, not hidden) rather than listing them, so no username lands in this public repo. `script/doctor` uses the same list to warn if one becomes an admin or loses the secure token it needs to unlock FileVault. Everything else in `user` is personal taste and stays on the account that runs the playbook. CI has no second user, so that path is untested there.

**App preferences.** Third-party app settings that `osx_defaults` can't write (nested arrays, data blobs, keys with dots) live as curated XML plists in `app-preferences/<domain>.plist`, and settings an app keeps in a JSON file it also rewrites (Docker Desktop) live in `app-preferences/json/<path under $HOME>`. Both are merged key by key by `script/app-preferences` (playbook `defaults` tag; `--check` in doctor). Track only keys chosen on purpose, never window frames, license keys or account state; `test/app-preferences.bats` enforces that, since the repo is public.

**`lib/`** (`globals`, `aliases`, `auto-complete`) is sourced by interactive `.zshrc`, so never add `set -e` or `set -u` there.

**Per-machine settings** that shouldn't be in this public repo go in untracked `~/.zshrc.local` and `~/.gitconfig.local`, which `.zshrc` and `.gitconfig` load last. Environment that the headless `script/update` also needs (a CA bundle) goes in `~/.config/dotfiles/env`, which [`lib/profile`](lib/profile) sources for shells, `update`, `doctor` and the playbook.

**Machine profile.** `DOTFILES_PROFILE=work` in that env file marks an employer-managed Mac; the default is `personal`. MDM enrollment can't tell them apart, because a personal Mac may be enrolled too (one was, in an anti-theft service's MDM, until Find My replaced it). On a work Mac the playbook (`is_work`) skips `macos_defaults.system`, the computer name and the security setters (FileVault, firewall, update schedule, remote-access daemons, authorizationdb), all of which belong to the MDM. `brew bundle` also skips the [`Brewfile.work-skip`](Brewfile.work-skip) entries via `dotfiles_bundle_skip`, and `script/update-brewfile` refuses to run, since a dump would delete those entries. The skip list is a separate file because a dump would wipe conditionals inside the Brewfile. The setup steps are in [MIGRATION.md](MIGRATION.md#work-mac).

**`claude/`** holds the global Claude Code config:

- `CLAUDE.md` is symlinked to `~/.claude/CLAUDE.md`.
- `settings.json` is *merged* into `~/.claude/settings.json` by the playbook's `claude` tag. It isn't symlinked because Claude Code replaces the file when it saves.
- Install third-party skills as plugins when they ship one: add them to `enabledPlugins` and `extraKnownMarketplaces` in `claude/settings.json`, and the playbook installs them while `script/update` keeps them current. Vendor installers like `npx impeccable install` copy files into `~/.claude` that nothing tracks or updates, and write their hooks into whichever project you ran them from.
- Keep `autoMode` and `permissions` out of `claude/settings.json`. They name private hosts and this repo is public; a test enforces it.
- The folder is `claude/`, not `.claude/`, so it isn't also loaded as this repo's project config.
- `claude/hooks/guard-bash` is a global PreToolUse hook, wired up in `claude/settings.json` by its `~/.files` path. It denies the Bash commands the global CLAUDE.md forbids (`sudo brew`, chowning `/opt/homebrew`, `npm install -g`, disabling signing, `git add -A`). The playbook's merge replaces lists, so a hook event array here overwrites any local-only hooks for that event.

**`.claude/`** is this repo's own project config, and its hooks fire only when working in this repo. `.claude/hooks/lint-file` (PostToolUse) runs `script/lint`'s per-file checks on each edited file, and fixes shfmt formatting in place. `.claude/hooks/check-drift` (Stop) runs `test/config.bats` when `config.yml`, `install.sh`, `.config/mise/config.toml`, `claude/` or `.claude/` changed. `test/hooks.bats` covers all three hooks.

## Conventions

- Shell scripts are POSIX `sh` and start with `set -eu` plus the `(set -o pipefail) 2>/dev/null && set -o pipefail || true` idiom. shfmt enforces tab indentation (`-i 0 -ci`).
- Ansible uses fully qualified module names (`ansible.builtin.*`), and tasks must be idempotent: use `creates:`, `changed_when`, or a stat/check task before a command.
- BATS tests use the `fail()` from `test/test_helper.bash`. bats-support/bats-assert are deliberately not vendored, so the suite runs the same under brew bats-core and apt bats.
- Comments explain *why*, often citing the specific breakage that motivated a workaround. Keep that when editing nearby code.
- CI (`.github/workflows/ci.yml`) runs the full playbook on macOS (plus a `--check` run with `DOTFILES_PROFILE=work`), lint on Ubuntu, BATS on macOS and Ubuntu, and the Codespaces path on Ubuntu (`install.sh`, then zsh loads and git can commit). It also runs weekly.
- Launch agents run through `/bin/sh -c` so the shell expands `$HOME`. launchd doesn't expand `~` or `$HOME` in a plist, and literal `/Users/<name>` paths broke under any other account name. A test rejects `/Users/` in them, and `script/doctor` finds each log from its `>>` redirect.
- `script/lint` runs every linter and lists all failures; add new linters with its `lint` helper rather than a bare command, so one failure can't hide the rest.
- `script/update`, `script/doctor` and `script/clean` read the repo's `Brewfile` directly (not `--global`), so they work before setup links `~/.Brewfile`. Headless, `update` skips casks and `mas` apps.
- In `lib/aliases`, `clean` runs `script/clean`; the git merged-branch cleanup is `gclean`, and `git reset --hard` + `git clean` is `greset`.
