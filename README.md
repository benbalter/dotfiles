# @BenBalter's dotfiles

[![CI](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml)

@BenBalter's development environment and the scripts to initialize it and keep it up to date. Uses [Ansible](https://www.ansible.com) and [Homebrew](https://brew.sh) to set up macOS. On Linux (GitHub Codespaces and devcontainers), `install.sh` symlinks the cross-platform dotfiles and installs a few CLI tools instead.

## What's here

### Scripts

- `script/setup` — Set up all the things (bootstrap + Ansible playbook)
- `script/update` — Update all the things (see [Updating](#updating)); aliased to `up`
- `script/doctor` — Read-only health check: symlinks and leftover `.bak` files, the brew wrapper, launch agents, the last update run, missing Brewfile and mise packages, macOS security settings, and whether the repo is ready for `up`
- `script/bootstrap` — Install Python venv and Ansible dependencies
- `script/ansible` — Run the playbook (prompts for sudo)
- `script/audit-casks` — Report casks whose apps haven't been opened lately; `--comment` proposes removals in the `Brewfile`
- `script/update-brewfile` — Sync the `Brewfile` with what's installed
- `script/clean` — Uninstall everything not in the `Brewfile` (`brew bundle cleanup --force`; destructive); aliased to `clean`
- `script/install-tools` — Install delta, zoxide and fzf on Linux without Homebrew (Codespaces, devcontainer)
- `script/lint` — Run all linters (see [Linting](#linting))
- `script/test` — Run the BATS test suite
- `install.sh` — Codespaces entry point; runs `script/setup` on macOS, a symlink-only install on Linux

### Configuration

- Dotfiles (`.gitconfig`, `.zshrc`, `.irbrc`, etc.) symlinked into `~`
- Shell aliases and globals (`lib/`)
- Launch agents to keep Downloads tidy and dependencies up to date (`Library/`)
- macOS system and user defaults (`config.yml`)
- Homebrew packages, casks, Mac App Store apps, and VS Code extensions (`Brewfile`)

### What gets installed

The `Brewfile` manages formulae, casks, Mac App Store apps, and VS Code extensions. Language runtimes and global npm CLIs are pinned in mise (`.config/mise/config.toml`). Highlights:

| Category       | Examples                                                  |
| -------------- | --------------------------------------------------------- |
| Languages      | Ruby, Node, Python (pinned via mise), Go, Rust            |
| Dev tools      | git, gh, delta, fzf, ripgrep, jq, mise, uv                |
| Linters        | shellcheck, shfmt, actionlint, vale                       |
| Infrastructure | tfsec, docker, act                                        |
| Applications   | Ghostty, VS Code, 1Password, Chrome, and more             |

## Setting up a new machine from scratch

[MIGRATION.md](MIGRATION.md) has the full checklist for moving from an old
machine. The short version:

### Before you start

Install the Xcode Command Line Tools (`xcode-select --install`). Until then
`git` and `python3` are stubs that just prompt for them. Sign in to the App
Store too: the `Brewfile` installs Mac App Store apps through `mas`, and a
failed `mas` install stops the playbook partway. Homebrew is installed by the
playbook (or, on a Workbrew-managed Mac, left to Workbrew).

### Install

Keep an authenticated sudo session open while setup runs; it covers Homebrew
and App Store installs.

```sh
git clone https://github.com/benbalter/dotfiles ~/.files
sudo -v
~/.files/script/setup
```

The playbook installs Homebrew and the `Brewfile`, Mac App Store apps, dotfile
symlinks, oh-my-zsh, mise runtimes and CLIs, Claude Code settings, the Dock,
system and user defaults, and security settings (firewall, Gatekeeper, TouchID
for `sudo`, and FileVault). It is macOS-only; on Linux, use `install.sh`.

To run part of the playbook, pass tags (`dotfiles`, `packages`, `homebrew`,
`mise`, `claude`, `macos`, `defaults`, `dock`, `security`, `ohmyzsh`, …),
and add `--check --diff` to preview:

```sh
cd ~/.files && . env/bin/activate
ansible-playbook playbook.yml --tags dotfiles --ask-become-pass
```

### After setup

- **Log out and back in.** FileVault is enabled at logout, and the launch
  agents (nightly `up`, Downloads cleanup) load at login.
- **1Password:** sign in, then turn on Settings → Developer → **Use the SSH
  agent** and **Integrate with 1Password CLI**. Git signs commits with the
  1Password SSH key and SSH uses its agent, so both fail until this is done.
- **GitHub:** `gh auth login`. Git uses it as its HTTPS credential helper.
- Run `script/doctor` to confirm everything is linked and healthy.

## GitHub Codespaces

These dotfiles are automatically applied to new Codespaces when configured in
your [GitHub settings](https://github.com/settings/codespaces). The `install.sh`
script symlinks dotfiles, installs essential CLI tools (`delta`, `zoxide`, `fzf`)
with mise, sets up oh-my-zsh, and sets zsh as the default shell. macOS-specific
configuration (SSH, GPG agent, Homebrew, commit signing through 1Password,
etc.) is skipped, so Codespaces' own commit signing and credentials apply. The
same path works in any Linux container; it's the only Linux target.

## Development

### Updating

Run `up` (alias for `script/update`). It pulls this repo (when the tree is
clean), upgrades Homebrew and installs any new `Brewfile` entries, upgrades
Mac App Store apps, mise tools (including global npm CLIs), oh-my-zsh,
and tldr pages, refreshes this repo's npm/gem/Python/Ansible dependencies, and
lists pending macOS updates without installing them.

A launch agent also runs it nightly at midnight, logging to
`~/Library/Logs/dotfiles-update.log`. With no terminal attached, it skips
anything that needs a human: cask and App Store upgrades, installing new casks
and App Store apps, the `git pull`, `script/audit-casks`, and mole. A failed step doesn't stop the rest, but the
run exits non-zero, and `script/doctor` reports which steps failed.

### Testing

A [BATS](https://github.com/bats-core/bats-core) test suite validates configuration integrity:

```sh
script/test
```

Tests cover config file validation, script syntax, permissions and strict-mode headers, shell library sourcing, install script behavior (including backups), VS Code font settings, and `script/update`, `script/doctor`, `script/audit-casks` and `script/update-brewfile` (with every external command stubbed out).

### Linting

```sh
script/lint
```

Needs `script/bootstrap` (ansible-lint and yamllint run from the venv),
`npm ci` (remark), and `bundle install` (rubocop). Runs all seven linters, even
after one fails, then lists the ones that failed:

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

1. **Test** — Full Ansible playbook execution on macOS
2. **Lint** — All linters above, on Ubuntu
3. **Unit test** — BATS test suite on macOS
4. **Install Linux** — The Codespaces path: runs `install.sh` on Ubuntu, checks the tools, that zsh loads and that git can commit, then runs the BATS suite there too
