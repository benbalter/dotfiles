# Migration Runbook

A checklist for setting up a new Mac from these dotfiles. Re-runnable: every
step is idempotent, so it's safe to start over if something goes sideways.

## 1. On the old machine (before migrating)

- [ ] Commit and push every working tree under `~/projects` and `~/github`
      (including `.env` files into a password manager — do not commit them):
      ```sh
      for dir in ~/projects/* ~/github/*; do
        [ -d "$dir/.git" ] && (cd "$dir" && git status --short && git stash list)
      done
      ```
- [ ] Refresh this repo so the new machine inherits a current state:
      ```sh
      cd ~/.files
      script/update-brewfile   # syncs Brewfile to actually-installed packages
      script/lint && script/test
      git commit -am "Pre-migration sync"
      git push
      ```
- [ ] Verify 1Password vault is fully synced (Settings → status indicator).
      All SSH keys and the git commit-signing key live here.
- [ ] Verify Dropbox is fully synced (Mackup syncs via `~/Dropbox/mackup`).
- [ ] Run Mackup backup if not already up to date: `mackup backup`.
- [ ] (Optional) Export GPG secret keys — only if you still use GPG for
      email/encryption. Git commit signing uses SSH via 1Password and does
      not need this.
      ```sh
      gpg --export-secret-keys --armor > ~/gpg-secret-keys.asc
      gpg --export-ownertrust > ~/gpg-ownertrust.txt
      # Stash both in 1Password as secure notes; delete from disk.
      ```
- [ ] Note any GUI apps installed manually (not via `Brewfile`) so you can
      decide whether to add them to `Brewfile` or reinstall by hand.

## 2. On the new machine — prerequisites

These cannot be automated by the playbook because they require GUI sign-in or
must exist before `script/setup` runs.

- [ ] Sign in to **Apple ID / iCloud** (System Settings → top of sidebar).
- [ ] Sign in to the **App Store** (required before `mas` can install ~25
      Mac App Store apps from `Brewfile`).
- [ ] Install Xcode Command Line Tools:
      ```sh
      xcode-select --install
      ```
- [ ] Install Homebrew:
      ```sh
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      ```
- [ ] Install **1Password** (App Store or `brew install --cask 1password`),
      sign in, then enable:
      - Settings → Developer → **Use the SSH agent** ✓
      - Settings → Developer → **Integrate with 1Password CLI** ✓
      - Install the **1Password browser extension** in your default browser.
- [ ] Install **Dropbox**, sign in, and let it fully sync `~/Dropbox/mackup`
      before running Mackup restore.

## 3. Clone and run setup

```sh
git clone https://github.com/benbalter/dotfiles ~/.files
cd ~/.files
script/setup
```

What to expect:

- Bootstrap creates a Python venv and installs Ansible.
- Ansible installs every formula, cask, Mac App Store app, and VS Code
  extension from `Brewfile`. **First run takes 20–60 minutes.**
- You will be prompted for `sudo` (system defaults, firewall) and may see
  App Store prompts if any `mas` app needs review.
- Re-running is safe — every task is idempotent.

## 4. Verify

- [ ] **Git commit signing** — should sign automatically via 1Password:
      ```sh
      cd /tmp && git init signtest && cd signtest
      git commit --allow-empty -S -m "test"
      git log --show-signature -1   # expect "Good signature"
      ```
- [ ] **GitHub auth**:
      ```sh
      gh auth status
      ```
- [ ] **Mac App Store apps installed**:
      ```sh
      mas list | wc -l   # expect ~25
      ```
- [ ] **VS Code extensions installed**:
      ```sh
      code --list-extensions | wc -l
      ```
- [ ] **LaunchAgents loaded** (tmpreaper for Downloads, auto-update):
      ```sh
      launchctl list | grep balter
      ```
- [ ] **Dock** matches `config.yml` (Chrome, Spotify, VS Code, Slack pinned;
      Mail / Calendar / Maps / etc. removed).
- [ ] **Shell** is zsh with oh-my-zsh + starship prompt.

## 5. Manual data transfer (after setup)

These are **not** managed by the playbook — copy or restore as needed.

- [ ] **Mackup restore** (zsh history, app-specific prefs):
      ```sh
      mackup restore
      ```
- [ ] **Working repos**: clone fresh from GitHub, or `rsync ~/projects` and
      `~/github` from the old machine.
- [ ] **`~/.ssh/known_hosts`** (optional — will rebuild as you connect):
      ```sh
      scp old-mac:~/.ssh/known_hosts ~/.ssh/
      ```
- [ ] **GPG keyring** (optional, only if exported in step 1):
      ```sh
      gpg --import ~/gpg-secret-keys.asc
      gpg --import-ownertrust ~/gpg-ownertrust.txt
      ```
- [ ] **Browser profiles** — sign in to Chrome/Safari to sync; or import
      bookmarks manually.
- [ ] **iMessage / Messages history** — handled by iCloud if enabled.
- [ ] **Photos library** — iCloud Photos.

## 6. Decommission the old machine

- [ ] One last `git push` of every working tree.
- [ ] Confirm 1Password and Dropbox say "Up to date".
- [ ] Sign out of iCloud, App Store, and iMessage (System Settings).
- [ ] Erase all content and settings.
