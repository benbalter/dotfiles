# Use hardcoded path instead of slow $(brew --prefix) subprocess
if [[ -d "/opt/homebrew/share/zsh/site-functions" ]]; then
  FPATH="/opt/homebrew/share/zsh/site-functions:${FPATH}"
elif [[ -d "/usr/local/share/zsh/site-functions" ]]; then
  FPATH="/usr/local/share/zsh/site-functions:${FPATH}"
fi
