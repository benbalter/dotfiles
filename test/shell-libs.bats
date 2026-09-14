#!/usr/bin/env bats
# Validate that shell library files source without errors.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "lib/globals sources without error" {
	# Provide a minimal environment so the file can be sourced safely
	HOME="$(mktemp -d)"
	touch "$HOME/.token"
	run bash -c ". '$REPO_ROOT/lib/globals'"
	rm -rf "$HOME"
	[ "$status" -eq 0 ]
}

@test "lib/aliases sources without error" {
	# aliases depends on globals for DOTFILES_ROOT
	HOME="$(mktemp -d)"
	mkdir -p "$HOME/.files/script"
	touch "$HOME/.token"
	run bash -c "
		DOTFILES_ROOT='$REPO_ROOT'
		. '$REPO_ROOT/lib/aliases'
	"
	rm -rf "$HOME"
	[ "$status" -eq 0 ]
}

@test "lib/auto-complete sources without error when gh is missing" {
	run bash -c "
		# Hide gh so the conditional is exercised
		gh() { return 1; }
		. '$REPO_ROOT/lib/auto-complete'
	"
	[ "$status" -eq 0 ]
}

@test "lib/globals sets HOMEBREW_PREFIX without invoking brew" {
	# Regression: .zprofile and oh-my-zsh's brew plugin used to call
	# `brew --prefix`. Under Workbrew that wrapper can fail outright, leaving
	# HOMEBREW_PREFIX empty and silently skipping the fzf-tab /
	# zsh-autosuggestions / zsh-syntax-highlighting source lines in .zshrc.
	# Sabotage `brew` and assert the prefix still resolves.
	run bash -c "
		brew() { echo 'Error: brew is broken' >&2; return 1; }
		export -f brew
		PATH='/usr/bin:/bin'
		. '$REPO_ROOT/lib/globals'
		test -x \"\$HOMEBREW_PREFIX/bin/brew\" || { echo \"FAIL: HOMEBREW_PREFIX=[\$HOMEBREW_PREFIX]\"; exit 1; }
		echo \"\$HOMEBREW_PREFIX\"
	"
	[ "$status" -eq 0 ]
}
