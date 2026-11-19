#!/usr/bin/env bats
# Test script/git-work-identity against a temp HOME holding the repo's
# .gitconfig, and resolve user.email with real git, so the includeIf patterns
# are checked by the thing that reads them.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	TMP="$(mktemp -d)"
	export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config"
	export GIT_CONFIG_NOSYSTEM=1
	unset GIT_CONFIG_GLOBAL
	mkdir -p "$XDG_CONFIG_HOME/dotfiles"
	# The macOS and local includes would pull in this Mac's own settings.
	grep -v 'gitconfig\.\(macos\|local\)' "$REPO_ROOT/.gitconfig" >"$HOME/.gitconfig"
	ENV_FILE="$XDG_CONFIG_HOME/dotfiles/env"
	cat >"$ENV_FILE" <<'ENV'
DOTFILES_PROFILE=work
DOTFILES_WORK_EMAIL=me@work.example
DOTFILES_WORK_GIT_REMOTES="gitlab.work.example github.com/work-org/"
ENV
	REPO="$TMP/repo"
	git init -q "$REPO"
}

teardown() {
	rm -rf "$TMP"
}

run_script() {
	run "$REPO_ROOT/script/git-work-identity" "$@"
}

# email_for <remote URL, or "" for none>
email_for() {
	git -C "$REPO" remote remove origin 2>/dev/null || true
	[ -z "$1" ] || git -C "$REPO" remote add origin "$1"
	git -C "$REPO" config user.email
}

personal=$(sed -n 's/^[[:space:]]*email = //p' "$BATS_TEST_DIRNAME/../.gitconfig" | head -1)

@test "git-work-identity gives the employer's remotes the work email" {
	run_script
	[ "$status" -eq 0 ] || fail "$output"
	[ "$output" = changed ] || fail "expected changed, got: $output"
	for url in \
		https://gitlab.work.example/team/app.git \
		git@gitlab.work.example:team/app.git \
		ssh://git@gitlab.work.example/team/app.git \
		ssh://git@gitlab.work.example:2222/team/app.git \
		https://github.com/work-org/app.git \
		git@github.com:work-org/app.git \
		ssh://git@github.com/work-org/app.git; do
		[ "$(email_for "$url")" = me@work.example ] || fail "$url got $(email_for "$url")"
	done
}

@test "git-work-identity leaves other repos on the personal email" {
	run_script
	[ "$status" -eq 0 ] || fail "$output"
	for url in "" \
		https://github.com/benbalter/dotfiles.git \
		git@github.com:benbalter/dotfiles.git \
		https://github.com/work-org-fork/app.git \
		https://gitlab.com/team/app.git; do
		[ "$(email_for "$url")" = "$personal" ] || fail "'$url' got $(email_for "$url")"
	done
}

@test "git-work-identity changes nothing on a second run" {
	run_script
	before=$(ls -l "$HOME/.config/git")
	run_script
	[ "$status" -eq 0 ] || fail "$output"
	[ -z "$output" ] || fail "expected no output, got: $output"
	[ "$(ls -l "$HOME/.config/git")" = "$before" ] || fail "files were rewritten"
}

@test "git-work-identity --check reports drift and changes nothing" {
	run_script --check
	[ "$status" -eq 1 ] || fail "expected drift before the first run"
	[ ! -e "$HOME/.config/git/work" ] || fail "--check wrote a file"
	run_script
	run_script --check
	[ "$status" -eq 0 ] || fail "$output"
	echo 'DOTFILES_WORK_EMAIL=new@work.example' >>"$ENV_FILE"
	run_script --check
	[ "$status" -eq 1 ] || fail "expected drift after the email changed"
}

@test "git-work-identity fails on a work Mac without the env-file inputs" {
	echo 'DOTFILES_PROFILE=work' >"$ENV_FILE"
	run_script
	[ "$status" -eq 1 ] || fail "expected failure, got $status: $output"
	[[ "$output" == *DOTFILES_WORK_EMAIL* ]] || fail "$output"
}

@test "git-work-identity removes the files on the personal profile" {
	run_script
	echo 'DOTFILES_PROFILE=personal' >"$ENV_FILE"
	run_script --check
	[ "$status" -eq 1 ] || fail "expected leftover files to count as drift"
	run_script
	[ "$status" -eq 0 ] || fail "$output"
	[ "$output" = changed ] || fail "$output"
	[ ! -e "$HOME/.config/git/work" ] && [ ! -e "$HOME/.config/git/work-identity" ] || fail "files left behind"
	[ "$(email_for https://github.com/work-org/app.git)" = "$personal" ] || fail "work email still applies"
	run_script
	[ -z "$output" ] || fail "expected no output once clean, got: $output"
}
