# @BenBalter's dotfiles

[![CI](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/benbalter/dotfiles/actions/workflows/ci.yml)

@BenBalter's development environment and the scripts to initialize it and keep it up to date. Uses [Ansible](https://www.ansible.com/) for configuration management and [Homebrew](https://brew.sh/) for package management on macOS.

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

The `Brewfile` manages all packages. Highlights:

| Category       | Examples                                                                 |
| -------------- | ------------------------------------------------------------------------ |
| Languages      | Ruby, Go, Rust, Node, Python (via [uv](https://github.com/astral-sh/uv)) |
| Dev tools      | git, gh, delta, fzf, ripgrep, jq, mise                                   |
| Linters        | shellcheck, shfmt, actionlint, ansible-lint, yamllint, vale, rubocop     |
| Infrastructure | tflint, tfsec, terrascan, docker, act                                    |
| Applications   | iTerm2, VS Code, 1Password, Chrome, and more                             |

## Setting up a new machine from scratch

1. `git clone https://github.com/benbalter/dotfiles ~/.files`
2. `cd ~/.files && script/setup`

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

GitHub Actions runs four parallel jobs on every push:

1. **Test** — Full Ansible playbook execution on macOS
2. **Lint** — All linters above
3. **Unit test** — BATS test suite on macOS
4. **Install Linux** — Verify `install.sh`, symlinks, and tool installation on Ubuntu
