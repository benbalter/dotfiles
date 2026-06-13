# Homebrew on Linux (Asahi/Fedora) installs to /home/linuxbrew; put it on PATH.
# No-op on macOS, where this path does not exist.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

if command -v brew > /dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi
