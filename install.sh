#!/bin/sh
# Codespaces-compatible dotfiles installer
# Symlinks dotfiles to $HOME and sets up the shell environment.
# On macOS, delegates to the full Ansible-based setup via script/setup.

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(uname)" = "Darwin" ]; then
	exec "$DOTFILES_DIR/script/setup"
fi

# --- Linux / Codespaces setup ---

# Symlink dotfiles
for file in \
	.asdfrc .digrc .gemrc .gitconfig .gitignore .hushlogin \
	.irbrc .pryrc .remarkrc .yamllint .zprofile .zshrc; do
	ln -sf "$DOTFILES_DIR/$file" "$HOME/$file"
done

# Symlink directories that need parent dirs
mkdir -p "$HOME/.bundle" "$HOME/.gnupg" "$HOME/.ssh"
[ -f "$DOTFILES_DIR/.bundle/config" ] && ln -sf "$DOTFILES_DIR/.bundle/config" "$HOME/.bundle/config"
[ -f "$DOTFILES_DIR/.gnupg/gpg.conf" ] && ln -sf "$DOTFILES_DIR/.gnupg/gpg.conf" "$HOME/.gnupg/gpg.conf"
[ -f "$DOTFILES_DIR/.gnupg/gpg-agent.conf" ] && ln -sf "$DOTFILES_DIR/.gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"
[ -f "$DOTFILES_DIR/.ssh/config" ] && ln -sf "$DOTFILES_DIR/.ssh/config" "$HOME/.ssh/config"

# Install oh-my-zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

# Set zsh as default shell if available
if command -v zsh >/dev/null && [ "$SHELL" != "$(command -v zsh)" ]; then
	sudo chsh -s "$(command -v zsh)" "$(whoami)" 2>/dev/null || true
fi
