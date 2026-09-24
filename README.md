# @BenBalter's dotfiles

[![CI](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml)

@BenBalter's development environment and the scripts to initialize it and keep it up to date. Uses [Ansible](https://www.ansible.com/) for configuration management, with [Homebrew](https://brew.sh/) for package management on both macOS and Fedora Asahi Remix (Apple Silicon). The same `Brewfile` drives both; `dnf` is used only to bootstrap Homebrew and install the GUI apps Homebrew Cask can't provide on Linux.

## What's here

### Scripts

- `script/setup` — Set up all the things (bootstrap + Ansible playbook)
- `script/update` — Update all the things (see [Updating](#updating)); aliased to `up`
- `script/doctor` — Read-only health check: symlinks, leftover `.bak` files, the brew wrapper, and the last update run
- `script/bootstrap` — Install Python venv and Ansible dependencies
- `script/ansible` — Run the playbook (prompts for sudo)
- `script/audit-casks` — Report casks whose apps haven't been opened lately; `--comment` proposes removals in the `Brewfile`
- `script/update-brewfile` — Sync the `Brewfile` with what's installed
- `script/clean` — Uninstall everything not in the `Brewfile` (`brew bundle cleanup --force`; destructive)
- `script/lint` — Run all linters (see [Linting](#linting))
- `script/test` — Run the BATS test suite
- `install.sh` — Codespaces entry point; runs `script/setup` on macOS and Fedora, a symlink-only install elsewhere

### Configuration

- Dotfiles (`.gitconfig`, `.zshrc`, `.irbrc`, etc.) symlinked into `~`
- Shell aliases and globals (`lib/`)
- Launch agents to keep Downloads tidy and dependencies up to date (`Library/`)
- macOS system and user defaults (`config.yml`)
- Homebrew packages, casks, Mac App Store apps, and VS Code extensions (`Brewfile`)

### What gets installed

The `Brewfile` manages packages on both macOS and Fedora Asahi Remix ([Homebrew on Linux aarch64 is Tier 1](https://brew.sh/2025/11/12/homebrew-5.0.0/) as of Homebrew 5.0). On Asahi, `dnf` installs only Homebrew's build prerequisites, `bubblewrap`, and `zsh` (`fedora_packages` in `config.yml`), plus VS Code and 1Password from their vendor repos (the 1Password desktop app comes from its tarball on aarch64); everything else comes from the Brewfile. Language runtimes and global npm CLIs are pinned in mise (`.config/mise/config.toml`). Three macOS-only formulae (`dockutil`, `mas`, `pinentry-mac`) have no Linux bottle and are skipped via `HOMEBREW_BUNDLE_BREW_SKIP`, and `cask`/`mas` entries are skipped automatically by `brew bundle` on Linux. Highlights:

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

- **macOS:** install the Xcode Command Line Tools (`xcode-select --install`).
  Until then `git` and `python3` are stubs that just prompt for them. Sign in
  to the App Store too: the `Brewfile` installs Mac App Store apps through
  `mas`, and a failed `mas` install stops the playbook partway. Homebrew is
  installed by the playbook (or, on a Workbrew-managed Mac, left to Workbrew).
- **Fedora Asahi:** `sudo dnf install -y git python3`.

### Install

Works on both macOS and Fedora. Keep an authenticated sudo session open while
setup runs: on macOS it covers Homebrew and App Store installs; on Fedora
Asahi the Homebrew installer runs its own `sudo` to create `/home/linuxbrew`,
which `--ask-become-pass` does not cover.

```sh
git clone https://github.com/benbalter/dotfiles ~/.files
sudo -v
~/.files/script/setup
```

The playbook detects the OS and runs the appropriate tasks. Both get Homebrew
and the `Brewfile`, dotfile symlinks, oh-my-zsh, mise runtimes and CLIs, and
Claude Code settings. macOS also gets Mac App Store apps, the Dock, system and
user defaults, and security settings (firewall, Gatekeeper, TouchID for
`sudo`, and FileVault). Fedora gets the `dnf` bootstrap packages, the VS Code
and 1Password repos, and zsh as the login shell. On Fedora, configs that live
under `~/Library` on macOS (VS Code, Ghostty) are symlinked to their XDG paths
under `~/.config`, and Linux variants of OS-specific files
(`.gitconfig.linux`, `.ssh/config.linux`) are used.

To run part of the playbook, pass tags (`dotfiles`, `packages`, `homebrew`,
`mise`, `claude`, `macos`, `defaults`, `dock`, `security`, `fedora`,
`ohmyzsh`, …), and add `--check --diff` to preview:

```sh
cd ~/.files && . env/bin/activate
ansible-playbook playbook.yml --tags dotfiles --ask-become-pass
```

### After setup

- **Log out and back in.** FileVault is enabled at logout, the launch agents
  (nightly `up`, Downloads cleanup) load at login, and on Fedora zsh becomes
  the login shell.
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
configuration (SSH, GPG agent, Homebrew, etc.) is skipped in Codespaces.

## Development

### Updating

Run `up` (alias for `script/update`). It pulls this repo (when the tree is
clean), upgrades Homebrew and installs any new `Brewfile` entries, upgrades
`dnf`, Mac App Store apps, mise tools (including global npm CLIs), oh-my-zsh,
and tldr pages, refreshes this repo's npm/gem/Python/Ansible dependencies, and
lists pending macOS updates without installing them.

A launch agent also runs it nightly at midnight, logging to
`~/Library/Logs/dotfiles-update.log`. With no terminal attached, it skips
anything that needs a human: cask upgrades, the `git pull`,
`script/audit-casks`, and mole. A failed step doesn't stop the rest, but the
run exits non-zero, and `script/doctor` reports which steps failed.

### Testing

A [BATS](https://github.com/bats-core/bats-core) test suite validates configuration integrity:

```sh
script/test
```

Tests cover config file validation, script syntax and permissions, shell library sourcing, install script behavior, and `script/update` and `script/doctor` (with every external command stubbed out).

### Linting

```sh
script/lint
```

Needs `script/bootstrap` (ansible-lint and yamllint run from the venv),
`npm ci` (remark), and `bundle install` (rubocop). Runs seven linters in sequence:

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

GitHub Actions runs seven parallel jobs on pushes to `main` and on pull requests:

1. **Bootstrap** — `script/bootstrap` (venv and Ansible dependencies) on macOS
2. **Test** — Full Ansible playbook execution on macOS
3. **Test Fedora** — Full Ansible playbook execution in a Fedora container (dnf bootstrap path)
4. **Test Asahi Brew** — Runs the `Brewfile` under `brew bundle` on x86_64 and native aarch64 Linux runners as a non-root user, verifying it parses, skips macOS-only entries, and installs Linux bottles (the aarch64 leg matches Asahi)
5. **Lint** — All linters above
6. **Unit test** — BATS test suite on macOS
7. **Install Linux** — Verify `install.sh`, symlinks, and tool installation on Ubuntu
