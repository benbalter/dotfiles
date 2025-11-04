# GitHub Copilot Instructions for @BenBalter's Dotfiles

This repository contains personal dotfiles for macOS development environment setup and configuration management using Ansible.

## Repository Overview

This is a dotfiles repository that automates macOS development environment setup using:
- Ansible playbooks for configuration management
- Homebrew for package management
- Shell scripts for setup and maintenance
- Configuration files symlinked to appropriate locations

## Build & Test Process

### Setup
- Run `script/bootstrap` to set up the Python virtual environment and install dependencies
- Run `script/setup` to initialize the entire development environment
- Run `script/update` to update all dependencies

### Linting
- Always lint before committing: `script/lint`
- Ansible linting: Uses `ansible-lint` for playbook validation
- YAML linting: Uses `yamllint` for all `.yml` files
- Ruby linting: Uses `rubocop` for Ruby files
- Markdown linting: Uses `remark` for documentation

### CI/CD
- All changes are tested via GitHub Actions (`.github/workflows/ci.yml`)
- Linting and playbook execution are verified on macOS runners
- Changes must pass both test and lint jobs before merging

## Coding Standards

### Ansible
- Follow Ansible best practices and lint rules (`.ansible-lint`)
- Use fully qualified collection names (e.g., `ansible.builtin.file`)
- Keep playbooks idempotent
- Use variables from `config.yml` and `config_ci.yml`

### Shell Scripts
- Use POSIX-compliant shell scripts (`#!/bin/sh`)
- Include `set -e` for error handling
- Make scripts executable with proper permissions

### YAML
- Follow `.yamllint` configuration
- Use 2-space indentation
- Keep files properly formatted

### Ruby
- Follow `.rubocop.yml` configuration
- Use frozen string literals
- Keep code clean and readable

### Markdown
- Follow `.remarkrc` configuration
- Use proper heading structure
- Validate links with `remark-validate-links`

## Dependencies

### Adding Dependencies
- Homebrew packages: Add to `Brewfile`
- Python packages: Add to `requirements.txt`
- Ansible roles: Add to `requirements.yml`
- Ruby gems: Add to `Gemfile`
- Node packages: Add to `package.json`

### Updating Dependencies
- Run `script/update` or the `up` alias to update all dependencies
- Keep dependencies up to date and secure

## File Organization

- Configuration files in repository root (symlinked to appropriate locations)
- Scripts in `script/` directory
- Ansible playbook: `playbook.yml`
- Library files: `lib/`
- macOS-specific: `Library/`

## Security & Best Practices

- Never commit secrets or credentials
- Use proper file permissions (0755 for directories, executable bit for scripts)
- Keep the `.gitignore` updated to exclude sensitive files
- Follow macOS security best practices for system defaults

## Testing Changes

- Test Ansible playbooks locally before committing
- Verify scripts work correctly in a clean environment
- Ensure all linters pass before pushing
- Check CI status after pushing changes

## Common Tasks

- **Add new Homebrew package**: Update `Brewfile`
- **Add system preference**: Update `config.yml` under `macos_defaults`
- **Add new script**: Place in `script/` directory with executable permissions
- **Modify setup process**: Update relevant files in `script/` or `playbook.yml`
