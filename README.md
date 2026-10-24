# @BenBalter's dotfiles

[![CI](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml)

@BenBalter's development environment and the scripts to initialize it and keep it up to date. Uses [Ansible](https://www.ansible.com) and [Homebrew](https://brew.sh) to set up macOS. On Linux (GitHub Codespaces and devcontainers), `install.sh` symlinks the cross-platform dotfiles and installs a few CLI tools instead.

## What's here

### Scripts

- `script/setup` — Set up all the things (bootstrap + Ansible playbook); `--work` (or `--personal`) first records the Mac's profile (see [Personal and work Macs](#personal-and-work-macs))
- `script/update` — Update all the things (see [Updating](#updating)); aliased to `up`
- `script/doctor` — Read-only health check: symlinks and leftover `.bak` files, the brew wrapper, launch agents, the last update run, missing Brewfile and mise packages, macOS security settings and `config.yml` defaults, and whether the repo is ready for `up`
- `script/bootstrap` — Install Python venv and Ansible dependencies
- `script/ansible` — Run the playbook (prompts for sudo)
- `script/audit-defaults` — Flag `config.yml` Apple defaults keys that no system binary contains anymore (likely dead); run it before adding a key
- `script/bench-shell` — Time zsh's startup and per-command lag with [zsh-bench](https://github.com/romkatv/zsh-bench) and flag anything past its noticeable thresholds
- `script/install-git-hooks` — Copy the gitleaks pre-commit hook into existing repos (`~/projects/*` by default); new clones get it through `init.templateDir`. Leaves other tools' hooks alone
- `script/audit-casks` — Report casks whose apps haven't been opened lately; `--comment` proposes removals in the `Brewfile`
- `script/update-brewfile` — Sync the `Brewfile` with what's installed (personal Mac only: on a work Mac the dump would drop every skipped entry)
- `script/clean` — Uninstall everything not in the `Brewfile` (`brew bundle cleanup --force`; destructive); aliased to `clean`
- `script/install-tools` — Install delta, zoxide and fzf on Linux without Homebrew (Codespaces, devcontainer)
- `script/app-preferences` — Merge the settings in `app-preferences/<domain>.plist` into each app's defaults (CleanShot X, Thaw, keyboard shortcuts), and `app-preferences/json/<path>` into JSON settings files under `$HOME` (Docker Desktop); `--check` shows drift. The playbook's `defaults` tag runs it
- `script/github-settings` — Apply this repo's GitHub settings and `main` branch protection from `.github/settings/`; `--check` shows drift without changing anything
- `script/lint` — Run all linters (see [Linting](#linting))
- `script/test` — Run the BATS test suite
- `install.sh` — Codespaces entry point; runs `script/setup` on macOS, a symlink-only install on Linux

### Configuration

- Dotfiles (`.gitconfig`, `.zshrc`, `.irbrc`, etc.) symlinked into `~`
- Shell aliases and globals (`lib/`)
- Launch agents to keep Downloads tidy and dependencies up to date (`Library/`)
- macOS system and user defaults (`config.yml`)
- Homebrew packages, casks, Mac App Store apps, and VS Code extensions (`Brewfile`), minus `Brewfile.work-skip` on a work Mac
- Per-machine profile and environment (untracked `~/.config/dotfiles/env`, read by `lib/profile`)

### What gets installed

The `Brewfile` manages formulae, casks, Mac App Store apps, and VS Code extensions. Language runtimes and global npm CLIs are pinned in mise (`.config/mise/config.toml`). Highlights:

| Category       | Examples                                       |
| -------------- | ---------------------------------------------- |
| Languages      | Ruby, Node, Python (pinned via mise), Go, Rust |
| Dev tools      | git, gh, delta, fzf, ripgrep, jq, mise, uv     |
| Linters        | shellcheck, shfmt, actionlint, vale            |
| Infrastructure | tfsec, docker, act                             |
| Applications   | Ghostty, VS Code, 1Password, Chrome, and more  |

## Personal and work Macs

The same repo sets up two kinds of Mac. Each machine's profile lives in the untracked `~/.config/dotfiles/env`, and [`lib/profile`](lib/profile) reads it for shells, `up`, `script/doctor` and the playbook.

| | Personal (default) | Work (`DOTFILES_PROFILE=work`) |
| --- | --- | --- |
| Apps | Everything in the `Brewfile` | Skips [`Brewfile.work-skip`](Brewfile.work-skip): personal apps, network filters, Docker Desktop (use Colima), and all Mac App Store apps |
| Security and update policy | Set and verified by the playbook | Firewall, FileVault, remote access, System Settings lockdown and update policy left to IT's MDM (`script/doctor` only warns); Gatekeeper, TouchID for `sudo`, no auto-login and no wake for network still applied |
| Login window, computer name | From `config.yml` | Left to IT |
| `script/update-brewfile` | Runs | Refuses, so a dump can't delete the skipped entries |

MDM enrollment can't tell the two apart, because the personal Mac is enrolled too, so the profile is set explicitly: `script/setup --work` (or `--personal` to switch back). If a Mac looks company-enrolled but isn't on the work profile, `script/doctor` warns.

## Setting up a new machine from scratch

[MIGRATION.md](MIGRATION.md) has the full checklist, for replacing the personal Mac or [adding a work Mac](MIGRATION.md#work-mac). The short version:

### Before you start

Install the Xcode Command Line Tools (`xcode-select --install`). Until then `git` and `python3` are stubs that just prompt for them. On a personal Mac, sign in to the App Store too: the `Brewfile` installs Mac App Store apps through `mas`, and a failed `mas` install stops the playbook partway. A work Mac skips them. Homebrew is installed by the playbook (or, on a Workbrew-managed Mac, left to Workbrew).

### Install

Keep an authenticated sudo session open while setup runs; it covers Homebrew and App Store installs.

```sh
git clone https://github.com/benbalter/dotfiles ~/.files
sudo -v
~/.files/script/setup          # personal Mac
~/.files/script/setup --work   # employer-managed Mac
```

The playbook installs Homebrew and the `Brewfile`, Mac App Store apps, dotfile symlinks, oh-my-zsh, mise runtimes and CLIs, Claude Code settings, the Dock, system and user defaults, and security settings (firewall, Gatekeeper, TouchID for `sudo`, and FileVault). On a work Mac it leaves the firewall, FileVault, remote-access and System Settings lockdowns, update policy, the login window and the computer name to IT. Gatekeeper, TouchID for `sudo`, and turning off automatic login and wake for network access still apply. Setup then runs `up` (`script/update`) once. It is macOS-only; on Linux, use `install.sh`.

To run part of the playbook, pass tags (`dotfiles`, `packages`, `homebrew`, `mise`, `claude`, `macos`, `defaults`, `dock`, `security`, `ohmyzsh`, …), and add `--check --diff` to preview:

```sh
cd ~/.files && . env/bin/activate
ansible-playbook playbook.yml --tags dotfiles --ask-become-pass
```

### After setup

- **Log out and back in.** FileVault is enabled at logout (personal Mac), and the launch agents (nightly `up`, Downloads cleanup) load at login.
- **1Password:** sign in, then turn on Settings → Developer → **Use the SSH agent** and **Integrate with 1Password CLI**. Git signs commits with the 1Password SSH key and SSH uses its agent, so both fail until this is done.
- **GitHub:** `gh auth login`. Git uses it as its HTTPS credential helper.
- **Work Mac:** set up a separate git identity for work repos, the work GitHub account, and a CA bundle if the network inspects TLS. See [MIGRATION.md](MIGRATION.md#after-setup).
- Run `script/doctor` to confirm everything is linked and healthy.

## GitHub Codespaces

These dotfiles are automatically applied to new Codespaces when configured in your [GitHub settings](https://github.com/settings/codespaces). The `install.sh` script symlinks dotfiles, installs essential CLI tools (`delta`, `zoxide`, `fzf`) with mise, sets up oh-my-zsh, and sets zsh as the default shell. macOS-specific configuration (SSH, GPG agent, Homebrew, commit signing through 1Password, etc.) is skipped, so Codespaces' own commit signing and credentials apply. The same path works in any Linux container; it's the only Linux target.

## Development

### Updating

Run `up` (alias for `script/update`). It pulls this repo (when the tree is clean), upgrades Homebrew and installs any new `Brewfile` entries, upgrades Mac App Store apps, mise tools (including global npm CLIs), oh-my-zsh, and tldr pages, refreshes this repo's npm/gem/Python/Ansible dependencies, and lists pending macOS updates without installing them.

A launch agent also runs it nightly at midnight, logging to `~/Library/Logs/dotfiles-update.log`. It reads `~/.config/dotfiles/env` too, so machine-specific settings like a CA bundle apply headless. With no terminal attached, it skips anything that needs a human: cask and App Store upgrades, installing new casks and App Store apps, the `git pull`, `script/audit-casks`, and mole. A failed step doesn't stop the rest, but the run exits non-zero, and `script/doctor` reports which steps failed.

### Testing

A [BATS](https://github.com/bats-core/bats-core) test suite validates configuration integrity:

```sh
script/test
```

Tests cover config file validation, script syntax, permissions and strict-mode headers, shell library sourcing, the machine profile and its Brewfile skips, launch agents' paths, install script behavior (including backups), VS Code font settings, and `script/update`, `script/doctor`, `script/audit-casks` and `script/update-brewfile` (with every external command stubbed out).

### Linting

```sh
script/lint
```

Needs `script/bootstrap` (ansible-lint and yamllint run from the venv), `npm ci` (remark), and `bundle install` (rubocop). Runs all seven linters, even after one fails, then lists the ones that failed:

| Linter       | What it checks           |
| ------------ | ------------------------ |
| ansible-lint | Playbook best practices  |
| yamllint     | YAML syntax              |
| shellcheck   | Shell script correctness |
| shfmt        | Shell formatting         |
| actionlint   | GitHub Actions workflows |
| rubocop      | Ruby files               |
| remark       | Markdown files           |

### CI

GitHub Actions runs four parallel jobs on pushes to `main`, on pull requests, and weekly (to catch upstream breakage):

1. **Test** — Full Ansible playbook execution on macOS, a second run to prove it's idempotent, and a `--check` run on the work profile
2. **Lint** — All linters above, on Ubuntu
3. **Unit test** — BATS test suite on macOS
4. **Install Linux** — The Codespaces path: runs `install.sh` on Ubuntu, checks the tools, that zsh loads and that git can commit, then runs the BATS suite there too
