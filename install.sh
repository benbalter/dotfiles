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
	if [ -e "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
		echo "Backing up $HOME/$file to $HOME/$file.bak"
		mv "$HOME/$file" "$HOME/$file.bak"
	fi
	ln -sf "$DOTFILES_DIR/$file" "$HOME/$file"
done

# Symlink directories that need parent dirs
mkdir -p "$HOME/.bundle" "$HOME/.gnupg"
[ -f "$DOTFILES_DIR/.bundle/config" ] && ln -sf "$DOTFILES_DIR/.bundle/config" "$HOME/.bundle/config"
[ -f "$DOTFILES_DIR/.gnupg/gpg.conf" ] && ln -sf "$DOTFILES_DIR/.gnupg/gpg.conf" "$HOME/.gnupg/gpg.conf"
[ -f "$DOTFILES_DIR/.gnupg/gpg-agent.conf" ] && ln -sf "$DOTFILES_DIR/.gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"

# Skip .ssh/config on Linux — it contains macOS-specific directives
# (UseKeychain, 1Password IdentityAgent) that break SSH on Linux.
# Codespaces manages its own SSH and credential configuration.

# Install oh-my-zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

# Install essential CLI tools (delta, zoxide, fzf)
if [ "${DOTFILES_SKIP_TOOLS:-}" != "1" ]; then
	"$DOTFILES_DIR/script/install-tools"
fi

# Set zsh as default shell if available
if command -v zsh >/dev/null && [ "$SHELL" != "$(command -v zsh)" ]; then
	if ! sudo chsh -s "$(command -v zsh)" "$(whoami)" 2>/dev/null; then
		echo "Warning: could not set zsh as default shell"
	fi
fi
