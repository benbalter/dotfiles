#!/usr/bin/env bats
# Test script/backup against a local restic repository in a temp $HOME, with a
# fixed password instead of the Keychain, so nothing touches real backups.

load test_helper

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	TMP="$(mktemp -d)"
	HOME_DIR="$TMP/home"
	mkdir -p "$HOME_DIR/.claude/plans" "$HOME_DIR/.claude/projects/-p/memory" \
		"$HOME_DIR/.claude/projects/-p/transcripts" \
		"$HOME_DIR/Library/Application Support/com.elgato.StreamDeck/ProfilesV3"
	echo plan >"$HOME_DIR/.claude/plans/plan.md"
	echo memory >"$HOME_DIR/.claude/projects/-p/memory/MEMORY.md"
	echo pasted-secret >"$HOME_DIR/.claude/projects/-p/transcripts/session.jsonl"
	echo deck >"$HOME_DIR/Library/Application Support/com.elgato.StreamDeck/ProfilesV3/manifest.json"
	export RESTIC_REPOSITORY="$TMP/repo" RESTIC_PASSWORD=test-only
}

teardown() {
	rm -rf "$TMP"
}

# backup [args]: run script/backup against the test repository.
backup() {
	run env HOME="$HOME_DIR" XDG_CONFIG_HOME="$TMP/config" XDG_STATE_HOME="$TMP/state" \
		DOTFILES_BACKUP_REPOSITORY="$TMP/repo" DOTFILES_BACKUP_PASSWORD_COMMAND="echo test-only" \
		"$REPO_ROOT/script/backup" "$@"
}

@test "backup skips quietly where it isn't set up" {
	run env HOME="$HOME_DIR" XDG_CONFIG_HOME="$TMP/config" DOTFILES_BACKUP_REPOSITORY= "$REPO_ROOT/script/backup"
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	echo "$output" | grep -q "not set up" || fail "$output"
}

@test "backup stores the configured paths, never transcripts, and restores them" {
	command -v restic >/dev/null || skip "restic not installed"
	restic init --quiet
	backup
	[ "$status" -eq 0 ] || fail "exit $status: $output"
	files=$(restic ls latest)
	echo "$files" | grep -q '/.claude/plans/plan.md$' || fail "$files"
	echo "$files" | grep -q '/.claude/projects/-p/memory/MEMORY.md$' || fail "$files"
	echo "$files" | grep -q 'ProfilesV3/manifest.json$' || fail "$files"
	! echo "$files" | grep -q 'transcripts' || fail "transcripts were backed up: $files"
	[ -s "$TMP/state/dotfiles/backup-last" ] || fail "no success timestamp"

	backup --restore "$TMP/out"
	[ "$status" -eq 0 ] || fail "restore exit $status: $output"
	diff "$HOME_DIR/.claude/plans/plan.md" "$TMP/out/.claude/plans/plan.md" || fail "plan differs"
	diff "$HOME_DIR/Library/Application Support/com.elgato.StreamDeck/ProfilesV3/manifest.json" \
		"$TMP/out/Library/Application Support/com.elgato.StreamDeck/ProfilesV3/manifest.json" || fail "deck differs"
}

@test "an unchanged backup adds no snapshot" {
	command -v restic >/dev/null || skip "restic not installed"
	restic init --quiet
	backup
	backup
	[ "$(restic snapshots --json | jq length)" -eq 1 ] || fail "$(restic snapshots)"
	echo more >>"$HOME_DIR/.claude/plans/plan.md"
	backup
	[ "$(restic snapshots --json | jq length)" -eq 2 ] || fail "$(restic snapshots)"
}

@test "backup_paths are relative and never include transcripts or session history" {
	paths=$(yq -r '.backup_paths[]' "$REPO_ROOT/config.yml")
	! echo "$paths" | grep -E '^(/|~)' || fail "absolute path in backup_paths"
	! echo "$paths" | grep -E 'transcripts|history\.jsonl|\.jsonl$|^\.claude/projects/\*$|^\.claude$' ||
		fail "backup_paths would include session transcripts or history"
}
