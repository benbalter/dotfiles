# The repo is wherever this file's symlink points (~/.files, Codespaces'
# persisted share, or any other checkout install.sh was run from).
export DOTFILES_ROOT="${${(%):-%x}:A:h}"

# Keep PATH and fpath free of duplicates: lib/globals prepends and this file
# appends on every start, so each nested shell used to add another copy. -U
# only dedupes assignments to the arrays, not to the PATH scalar that
# lib/globals and mise write, so the arrays are re-assigned at the end too.
typeset -U path fpath

# shellcheck source=lib/globals
source "$DOTFILES_ROOT/lib/globals"

typeset -a plugins
plugins=(
  ansible
  bgnotify
  colored-man-pages
  command-not-found
  common-aliases
  cp
  dotenv
  extract
  zoxide
  gem
  git
  golang
  node
  npm
  safe-paste
  sudo
  vscode
)

if [[ $OSTYPE == darwin* ]]; then
  plugins+=(
    brew
    bundler
    macos
  )
fi

# Workbrew installs apps (e.g. Docker.app) as the `workbrew` user, so their
# bundled completion files are owned by workbrew rather than us. compinit's
# audit flags those as insecure and skips them. They are trusted local files,
# so disable the audit (oh-my-zsh's sanctioned escape hatch for this case).
ZSH_DISABLE_COMPFIX="true"

# script/update runs oh-my-zsh's upgrade nightly. Left on, the built-in check
# ran a `git pull` as a new shell started, which could race that job.
zstyle ':omz:update' mode disabled

source "$ZSH/oh-my-zsh.sh"

# common-aliases opens notes.txt and friends with '$EDITOR', which zsh doesn't
# word-split, so EDITOR="code --wait" failed with "command not found: code
# --wait". ${=EDITOR} splits it.
(( ${+_editor_fts} )) && for ft in $_editor_fts; do alias -s $ft='${=EDITOR}'; done

# shellcheck source=lib/auto-complete
source "$DOTFILES_ROOT/lib/auto-complete"

# shellcheck source=lib/aliases
source "$DOTFILES_ROOT/lib/aliases"

# Before the mise check: install-tools puts mise itself in ~/.local/bin.
export PATH="$PATH:$HOME/.local/bin"

# _cached_init <name> <command>...: source a tool's shell init script from a
# cache instead of forking mise, starship, fzf and atuin on every start (about
# 25ms). The cache's first line records the binary's resolved path, which
# includes Homebrew's Cellar version, and the command: an upgrade or a changed
# flag regenerates it. (Not an mtime check: bottles keep their build time.) It
# is written to a temp file first, so a failed run can't leave a truncated
# cache behind.
_cached_init() {
  local cache="${ZSH_CACHE_DIR:-$HOME/.cache}/init-$1.zsh" bin=${commands[$2]} first
  [[ -n $bin ]] || return 0
  local stamp="# ${bin:A} ${(j: :)@[2,-1]}"
  [[ -s $cache ]] && read -r first <"$cache"
  if [[ $first != "$stamp" ]]; then
    mkdir -p "${cache:h}"
    { print -r -- "$stamp" && "${@:2}"; } >|"$cache.tmp" && mv -f "$cache.tmp" "$cache" ||
      { rm -f "$cache.tmp"; return 1; }
  fi
  source "$cache"
}

_cached_init mise mise activate zsh

# 1Password SSH agent. Only if it's running, and not over SSH: exporting it
# unconditionally replaced a forwarded agent, or pointed at a dead socket.
if [[ $OSTYPE == darwin* ]]; then
  _op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  [[ -S $_op_sock && -z $SSH_CONNECTION ]] && export SSH_AUTH_SOCK="$_op_sock"
  unset _op_sock

  # Added by LM Studio CLI (lms)
  [[ -d "$HOME/.lmstudio/bin" ]] && export PATH="$PATH:$HOME/.lmstudio/bin"
fi

# --print-full-init: plain `init zsh` prints a stub that forks starship again.
_cached_init starship starship init zsh --print-full-init

# fzf: Ctrl-T (files), Alt-C (cd). Sourced BEFORE atuin so atuin keeps Ctrl-R.
# Each helper only if installed: install-tools (Codespaces) provides fzf but
# not fd, bat or eza, and fzf's defaults beat a command that doesn't exist.
# Only on a terminal: fzf's script saves and restores every option, and
# without a terminal (`zsh -ic` in CI) zsh can't set zle back, so it printed
# "can't change option: zle" twice. Its key bindings need a terminal anyway.
if [[ -t 0 ]] && command -v fzf >/dev/null; then
  if command -v fd >/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  fi
  command -v bat >/dev/null &&
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
  command -v eza >/dev/null &&
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
  _cached_init fzf fzf --zsh
fi

# Better shell history (Ctrl-R). Leave the up-arrow to history-substring-search.
_cached_init atuin atuin init zsh --disable-up-arrow

# ── Loaded shell (ORDER MATTERS) ──────────────────────────────────
# Notify when a >Ns command finishes in an unfocused terminal (bgnotify plugin).
bgnotify_threshold=8

# fzf-tab: fuzzy completion menu. Then autosuggestions, then
# syntax-highlighting (from Homebrew formulae), and finally oh-my-zsh's
# history-substring-search, whose README says to load it after
# syntax-highlighting. It was an oh-my-zsh plugin, which loaded it first.
[[ -f $HOMEBREW_PREFIX/share/fzf-tab/fzf-tab.zsh ]] && source $HOMEBREW_PREFIX/share/fzf-tab/fzf-tab.zsh
[[ -f $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f $ZSH/plugins/history-substring-search/history-substring-search.plugin.zsh ]] &&
  source $ZSH/plugins/history-substring-search/history-substring-search.plugin.zsh

unfunction _cached_init

# Apply -U to everything added through the PATH/FPATH scalars above.
path=("${path[@]}")
fpath=("${fpath[@]}")
