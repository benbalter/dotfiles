# Homebrew on Linux (Asahi/Fedora) installs to /home/linuxbrew; put it on PATH.
# No-op on macOS, where this path does not exist.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# HOMEBREW_PREFIX and the Homebrew site-functions FPATH entry are set in
# lib/globals, which .zshrc sources before oh-my-zsh runs compinit.
