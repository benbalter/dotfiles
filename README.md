# @BenBalter's dotfiles

[![CI](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml)

@BenBalter's development environment and the scripts to initialize it and keep it up to date. Uses [Ansible](https://www.ansible.com/) for configuration management, with [Homebrew](https://brew.sh/) for package management on both macOS and Fedora Asahi Remix (Apple Silicon). The same `Brewfile` drives both; `dnf` is used only to bootstrap Homebrew and install the GUI apps Homebrew Cask can't provide on Linux.

## What's here

### Scripts

- `script/setup` — Set up all the things (bootstrap + Ansible playbook)
- `script/update` — Update all the things (Homebrew, gems, npm, pip, Ansible)
- `script/bootstrap` — Install Python venv and Ansible dependencies
- `script/lint` — Run all linters (see [Linting](#linting))
- `script/test` — Run the BATS test suite
- `install.sh` — Codespaces / Linux installer

### Configuration

- Dotfiles (`.gitconfig`, `.zshrc`, `.irbrc`, etc.) symlinked into `~`
- Shell aliases and globals (`lib/`)
- Launch agents to keep Downloads tidy and dependencies up to date (`Library/`)
- macOS system and user defaults (`config.yml`)
- Homebrew packages, casks, Mac App Store apps, and VS Code extensions (`Brewfile`)

### What gets installed

The `Brewfile` manages packages on both macOS and Fedora Asahi Remix ([Homebrew on Linux aarch64 is Tier 1](https://brew.sh/2025/11/12/homebrew-5.0.0/) as of Homebrew 5.0). On Asahi, `dnf` installs only Homebrew's build prerequisites, `zsh`, and the 1Password desktop app (`fedora_packages` in `config.yml`); everything else comes from the Brewfile. Three macOS-only formulae (`dockutil`, `mas`, `pinentry-mac`) have no Linux bottle and are skipped via `HOMEBREW_BUNDLE_BREW_SKIP`, and `cask`/`mas` entries are skipped automatically by `brew bundle` on Linux. Highlights:

| Category       | Examples                                                                 |
| -------------- | ------------------------------------------------------------------------ |
| Languages      | Ruby, Go, Rust, Node, Python (via [uv](https://github.com/astral-sh/uv)) |
| Dev tools      | git, gh, delta, fzf, ripgrep, jq, mise                                   |
| Linters        | shellcheck, shfmt, actionlint, ansible-lint, yamllint, vale, rubocop     |
| Infrastructure | tflint, tfsec, terrascan, docker, act                                    |
| Applications   | iTerm2, VS Code, 1Password, Chrome, and more                             |

## Setting up a new machine from scratch

Works on both macOS and Fedora:

1. `git clone https://github.com/benbalter/dotfiles ~/.files`
2. `cd ~/.files && script/setup`

The playbook detects the OS and runs the appropriate tasks: Mac App Store apps, Dock, and system defaults on macOS; `dnf` bootstrap packages, the 1Password repo, and the default shell on Fedora Asahi. Homebrew and the `Brewfile` run on both. Dotfile symlinks and oh-my-zsh are set up on both. On Fedora, configs that live under `~/Library` on macOS (VS Code, Ghostty) are symlinked to their XDG paths under `~/.config`, and Linux variants of OS-specific files (`.gitconfig.linux`, `.ssh/config.linux`) are used.

Keep an authenticated sudo session open while setup runs. On macOS this covers
Homebrew and App Store installs; on Fedora Asahi the Homebrew installer runs its
own `sudo` to create `/home/linuxbrew`, which `--ask-become-pass` does not cover,
so an active session is required there too:

```sh
sudo -v
cd ~/.files && script/setup
```

## GitHub Codespaces

These dotfiles are automatically applied to new Codespaces when configured in
your [GitHub settings](https://github.com/settings/codespaces). The `install.sh`
script symlinks dotfiles, installs essential CLI tools (`delta`, `zoxide`, `fzf`),
sets up oh-my-zsh, and sets zsh as the default shell. macOS-specific configuration
(SSH, Homebrew, etc.) is skipped in Codespaces.

## Development

### Updating dependencies

Run `up` (alias for `script/update`), which updates Homebrew, Ruby gems, npm packages, Python packages, and Ansible roles/collections.

### Testing

A [BATS](https://github.com/bats-core/bats-core) test suite validates configuration integrity:

```sh
script/test
```

Tests cover config file validation, script syntax and permissions, shell library sourcing, and install script behavior.

### Linting

```sh
script/lint
```

Runs seven linters in sequence:

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

GitHub Actions runs six parallel jobs on every push:

1. **Test** — Full Ansible playbook execution on macOS
2. **Test Fedora** — Full Ansible playbook execution in a Fedora container (dnf bootstrap path)
3. **Test Asahi Brew** — Runs the `Brewfile` under `brew bundle` on Linux as a non-root user, verifying it parses and skips macOS-only entries
4. **Lint** — All linters above
5. **Unit test** — BATS test suite on macOS
6. **Install Linux** — Verify `install.sh`, symlinks, and tool installation on Ubuntu
