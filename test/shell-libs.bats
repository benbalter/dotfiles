#!/usr/bin/env bats
# Validate that shell library files source without errors.

load test_helper

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

@test "gclean deletes merged branches but keeps main and the current branch" {
	# Not the user's ~/.gitconfig: its commit signing goes through 1Password,
	# so the fixture commit failed whenever the signing prompt timed out, and
	# on a Mac without that 1Password account it could never pass.
	export GIT_CONFIG_GLOBAL=/dev/null
	repo=$(mktemp -d)
	git -C "$repo" init -q -b main
	git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
	git -C "$repo" branch merged
	git -C "$repo" checkout -q -b feature
	run bash -c "
		cd '$repo'
		. '$REPO_ROOT/lib/aliases'
		gclean
	"
	branches=$(git -C "$repo" branch --format='%(refname:short)' | sort | tr '\n' ' ')
	rm -rf "$repo"
	[ "$status" -eq 0 ] || fail "$output"
	[ "$branches" = "feature main " ] || fail "branches left: $branches"
}

@test "lib/auto-complete sources without error when gh is missing" {
	# Not a gh() stub: `command -v` finds functions, so that ran the gh branch
	# against the real HOME. A PATH holding only a bare shell hides gh.
	bin=$(mktemp -d) home=$(mktemp -d)
	ln -s "$(command -v bash)" "$bin/bash"
	run env -i HOME="$home" PATH="$bin" "$bin/bash" -c ". '$REPO_ROOT/lib/auto-complete'"
	cache=$(find "$home" -type f)
	rm -rf "$bin" "$home"
	[ "$status" -eq 0 ] || fail "$output"
	[ -z "$cache" ] || fail "wrote $cache without gh"
}

@test "lib/auto-complete caches gh's completion under ZSH_CACHE_DIR" {
	bin=$(mktemp -d) home=$(mktemp -d)
	printf '#!/bin/sh\necho "# gh completion"\n' >"$bin/gh"
	chmod +x "$bin/gh"
	run env HOME="$home" ZSH_CACHE_DIR="$home/cache" PATH="$bin:$PATH" \
		bash -c "compdef() { :; }; . '$REPO_ROOT/lib/auto-complete'"
	cached=$(cat "$home/cache/gh-completion.zsh" 2>/dev/null)
	rm -rf "$bin" "$home"
	[ "$status" -eq 0 ] || fail "$output"
	[ "$cached" = "# gh completion" ] || fail "cache holds: $cached"
}

@test "lib/globals sets HOMEBREW_PREFIX without invoking brew" {
	# Regression: .zprofile and oh-my-zsh's brew plugin used to call
	# `brew --prefix`. Under Workbrew that wrapper can fail outright, leaving
	# HOMEBREW_PREFIX empty and silently skipping the fzf-tab /
	# zsh-autosuggestions / zsh-syntax-highlighting source lines in .zshrc.
	# Sabotage `brew` and assert the prefix still resolves. macOS only: Linux
	# (Codespaces) has no Homebrew to find.
	[ "$(uname)" = Darwin ] || skip "Homebrew is macOS-only"
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

@test "lib files never set -e or -u" {
	# They're sourced into interactive zsh, where set -e closes the shell on
	# the first failing command and set -u on the first unset variable.
	! grep -nE '^[[:space:]]*set -[a-zA-Z]*[eu]' "$REPO_ROOT"/lib/* ||
		fail "lib/ must not use set -e or set -u"
}

@test "npm() refuses to save credentials into the linked .npmrc" {
	# A stub npm records whether the wrapper let the call through.
	bin=$(mktemp -d)
	printf '#!/bin/sh\necho "ran npm $*"\n' >"$bin/npm"
	chmod +x "$bin/npm"
	for args in login adduser 'config set //registry.npmjs.org/:_authToken=abc' 'set //registry.npmjs.org/:_authToken=abc'; do
		run bash -c "PATH='$bin':\$PATH; NPM_TOKEN=x; . '$REPO_ROOT/lib/aliases'; npm $args"
		[ "$status" -eq 1 ] || fail "npm $args: expected 1, got $status: $output"
		case "$output" in *"ran npm"*) fail "npm $args reached npm: $output" ;; esac
	done
	run bash -c "PATH='$bin':\$PATH; NPM_TOKEN=x; . '$REPO_ROOT/lib/aliases'; npm config get registry"
	rm -rf "$bin"
	[ "$output" = "ran npm config get registry" ] || fail "$output"
}

@test "lib/profile defaults to personal and skips nothing" {
	home=$(mktemp -d)
	run env -i HOME="$home" PATH="$PATH" sh -c "
		. '$REPO_ROOT/lib/profile'
		dotfiles_bundle_skip '$REPO_ROOT'
		echo \"\$DOTFILES_PROFILE|\${HOMEBREW_BUNDLE_CASK_SKIP:-}|\${HOMEBREW_BUNDLE_MAS_SKIP:-}\"
	"
	rm -rf "$home"
	[ "$status" -eq 0 ] || fail "$output"
	[ "$output" = "personal||" ] || fail "$output"
}

@test "lib/profile reads the env file and skips Brewfile.work-skip on a work Mac" {
	home=$(mktemp -d) root=$(mktemp -d)
	mkdir -p "$home/.config/dotfiles"
	echo 'DOTFILES_PROFILE=work' >"$home/.config/dotfiles/env"
	printf "cask 'kept'\ncask 'game'\nmas 'App', id: 1_234_567\n" >"$root/Brewfile"
	printf '# comment\ncask game # why\nmas *\n' >"$root/Brewfile.work-skip"
	run env -i HOME="$home" PATH="$PATH" HOMEBREW_BUNDLE_CASK_SKIP=already sh -c "
		. '$REPO_ROOT/lib/profile'
		dotfiles_bundle_skip '$root'
		echo \"\$DOTFILES_PROFILE|\$HOMEBREW_BUNDLE_CASK_SKIP|\$HOMEBREW_BUNDLE_MAS_SKIP\"
	"
	rm -rf "$home" "$root"
	[ "$status" -eq 0 ] || fail "$output"
	# Whitespace is irrelevant to brew bundle, which splits on it.
	[ "$(echo "$output" | tr -s ' ')" = "work|already game |1234567 " ] || fail "$output"
}

@test "Brewfile.work-skip names only entries the Brewfile has" {
	while read -r type name _; do
		case "$type" in '' | '#'*) continue ;; esac
		[ "$name" = '*' ] && continue
		grep -q "^$type '$name'" "$REPO_ROOT/Brewfile" || fail "$type $name is not in the Brewfile"
	done <"$REPO_ROOT/Brewfile.work-skip"
}

@test "dotfiles_set_profile replaces the profile and keeps the rest of the env file" {
	home=$(mktemp -d)
	mkdir -p "$home/.config/dotfiles"
	printf 'export SSL_CERT_FILE=/ca.pem\nDOTFILES_PROFILE=personal\n' >"$home/.config/dotfiles/env"
	run env -i HOME="$home" PATH="$PATH" sh -c "
		. '$REPO_ROOT/lib/profile'
		dotfiles_set_profile work && echo \"now=\$DOTFILES_PROFILE\"
		dotfiles_set_profile bogus
	"
	env_file=$(cat "$home/.config/dotfiles/env")
	rm -rf "$home"
	[ "$status" -eq 1 ] || fail "a bogus profile should fail: $output"
	echo "$output" | grep -qx 'now=work' || fail "$output"
	[ "$env_file" = "$(printf 'export SSL_CERT_FILE=/ca.pem\nDOTFILES_PROFILE=work')" ] || fail "$env_file"
}
