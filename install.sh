#!/bin/sh
# Codespaces-compatible dotfiles installer
# Symlinks dotfiles to $HOME and sets up the shell environment.
# On macOS, delegates to the full Ansible-based setup via script/setup.

set -eu
# shellcheck disable=SC3040
(set -o pipefail) 2>/dev/null && set -o pipefail || true

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(uname)" = "Darwin" ]; then
	exec "$DOTFILES_DIR/script/setup"
fi

# On Fedora (and derivatives like Asahi Remix), delegate to the full
# Ansible-based setup. Set DOTFILES_SIMPLE_INSTALL=1 to force the simple
# symlink-only installer (used by tests and containers).
if [ "${DOTFILES_SIMPLE_INSTALL:-}" != "1" ] && [ -z "${CODESPACES:-}" ] &&
	grep -qsE '^(ID|ID_LIKE)=.*fedora' /etc/os-release; then
	exec "$DOTFILES_DIR/script/setup"
fi

# --- Linux / Codespaces setup ---

# link <repo path> [<path under $HOME>]: symlink a repo file into $HOME,
# first moving any real file there aside (to .bak, or .bak.<epoch> if a .bak
# already exists) so a plain `ln -sf` never silently destroys it.
link() {
	src="$DOTFILES_DIR/$1"
	dest="$HOME/${2:-$1}"
	[ -e "$src" ] || return 0
	if [ -e "$dest" ] && [ ! -L "$dest" ]; then
		bak="$dest.bak"
		[ ! -e "$bak" ] || bak="$bak.$(date +%s)"
		echo "Backing up $dest to $bak"
		mv "$dest" "$bak"
	fi
	ln -sf "$src" "$dest"
}

# Symlink dotfiles
for file in \
	.default-gems .digrc .gemrc .gitconfig .gitignore .hushlogin \
	.irbrc .npmrc .pryrc .remarkrc .ripgreprc .yamllint .zprofile .zshrc; do
	link "$file"
done

# Symlink directories that need parent dirs
mkdir -p "$HOME/.bundle" "$HOME/.gnupg" "$HOME/.config/mise" \
	"$HOME/.config/git" "$HOME/.config/bat" "$HOME/.config/atuin" "$HOME/.config/zed" \
	"$HOME/.claude"
# gpg warns "unsafe permissions on homedir" unless ~/.gnupg is private
# (config.yml's private_directories does the same for the playbook).
chmod 700 "$HOME/.gnupg"
for file in \
	.bundle/config .gnupg/gpg.conf .config/mise/config.toml .config/starship.toml \
	.config/git/attributes .config/git/allowed_signers .config/bat/config \
	.config/atuin/config.toml .config/zed/settings.json; do
	link "$file"
done
link claude/CLAUDE.md .claude/CLAUDE.md

# Skip .gitconfig.linux and linux_dotfile_links (config.yml) here: this path
# serves Codespaces and containers, not a Linux desktop. .gitconfig.linux only
# points commit signing at 1Password's op-ssh-sign, and the Code/ghostty
# configs are for GUI apps a container doesn't have.

# Skip .gnupg/gpg-agent.conf on Linux: it points pinentry-program at
# /opt/homebrew/bin/pinentry-mac, so gpg fails the moment it needs a passphrase.

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
if command -v zsh >/dev/null && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
	if ! sudo chsh -s "$(command -v zsh)" "$(whoami)" 2>/dev/null; then
		echo "Warning: could not set zsh as default shell"
	fi
fi
