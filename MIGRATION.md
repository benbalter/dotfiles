# Migration Runbook

A checklist for setting up a new Mac from these dotfiles. Re-runnable: every step is idempotent, so it's safe to start over if something goes sideways.

Setting up an employer-managed Mac alongside the personal one, rather than replacing it? Skip section 1, follow [Work Mac](#work-mac) first, then sections 2–5.

## 1. On the old machine (before migrating)

- [ ] Commit and push every working tree under `~/projects` and `~/github` (including `.env` files into a password manager — do not commit them):
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
- [ ] Verify 1Password vault is fully synced (Settings → status indicator). All SSH keys and the git commit-signing key live here.
- [ ] Verify Google Drive is fully synced.
- [ ] (Optional) Export GPG secret keys — only if you still use GPG for email/encryption. Git commit signing uses SSH via 1Password and does not need this.
  ```sh
  gpg --export-secret-keys --armor > ~/gpg-secret-keys.asc
  gpg --export-ownertrust > ~/gpg-ownertrust.txt
  # Stash both in 1Password as secure notes; delete from disk.
  ```
- [ ] Note any GUI apps installed manually (not via `Brewfile`) so you can decide whether to add them to `Brewfile` or reinstall by hand.
- [ ] Capture custom `/etc/hosts` entries (not managed by dotfiles):
  ```sh
  grep -v '^#' /etc/hosts | grep -vE '^(127\.|255\.|::1)' > ~/hosts-custom.txt
  ```
  Expect one for the home DNS server.
- [ ] Nothing to do for VS Code: the playbook installs extensions and links `settings.json`, `keybindings.json` and `mcp.json`. Snippets and UI state aren't tracked; turn on Settings Sync if you want those.

## 2. On the new machine — prerequisites

These cannot be automated by the playbook because they require GUI sign-in or must exist before `script/setup` runs.

- [ ] Sign in to **Apple ID / iCloud** (System Settings → top of sidebar).
- [ ] Sign in to the **App Store** (required before `mas` can install ~25 Mac App Store apps from `Brewfile`).
- [ ] Install Xcode Command Line Tools:
  ```sh
  xcode-select --install
  ```
- [ ] Nothing to do for Homebrew: the playbook installs it (or, on a Workbrew-managed Mac, leaves it to Workbrew).
- [ ] Install **1Password** (App Store or `brew install --cask 1password`), sign in, then enable:
  - Settings → Developer → **Use the SSH agent** ✓
  - Settings → Developer → **Integrate with 1Password CLI** ✓
  - Install the **1Password browser extension** in your default browser.
- [ ] Install **Google Drive** and sign in with the Workspace account (Stream mode).

## 3. Clone and run setup

```sh
git clone https://github.com/benbalter/dotfiles ~/.files
cd ~/.files
script/setup
```

What to expect:

- Bootstrap creates a Python venv and installs Ansible.
- Ansible installs every formula, cask, Mac App Store app, and VS Code extension from `Brewfile`. **First run takes 20–60 minutes.**
- You will be prompted for `sudo` (system defaults, firewall) and may see App Store prompts if any `mas` app needs review.
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
- [ ] **Everything else checks out** (symlinks, launch agents for tmpreaper and auto-update, packages, security settings):
  ```sh
  script/doctor
  ```
- [ ] **Dock** matches `config.yml` (Chrome, Spotify, VS Code, Slack pinned; Mail / Calendar / Maps / etc. removed).
- [ ] **Shell** is zsh with oh-my-zsh + starship prompt.

## 5. Manual data transfer (after setup)

These are **not** managed by the playbook — copy or restore as needed.

- [ ] **`/etc/hosts` custom entries** — append from `~/hosts-custom.txt`:
  ```sh
  sudo sh -c "cat ~/hosts-custom.txt >> /etc/hosts"
  ```
- [ ] **Working repos**: clone fresh from GitHub, or `rsync ~/projects` and `~/github` from the old machine.
- [ ] **`~/.ssh/known_hosts`** (optional — will rebuild as you connect):
  ```sh
  scp old-mac:~/.ssh/known_hosts ~/.ssh/
  ```
- [ ] **GPG keyring** (optional, only if exported in step 1):
  ```sh
  gpg --import ~/gpg-secret-keys.asc
  gpg --import-ownertrust ~/gpg-ownertrust.txt
  ```
- [ ] **Browser profiles** — sign in to Chrome/Safari to sync; or import bookmarks manually.
- [ ] **iMessage / Messages history** — handled by iCloud if enabled.
- [ ] **Photos library** — iCloud Photos.

## 6. Decommission the old machine

- [ ] One last `git push` of every working tree.
- [ ] Confirm 1Password and Google Drive say "Up to date".
- [ ] Sign out of iCloud, App Store, and iMessage (System Settings).
- [ ] Erase all content and settings.

## Work Mac

An employer-managed Mac runs the same playbook with `DOTFILES_PROFILE=work` ([`lib/profile`](lib/profile)). That profile:

- Skips the [`Brewfile.work-skip`](Brewfile.work-skip) entries: personal apps, network filters, Docker Desktop and every Mac App Store app.
- Leaves security, update policy, the login window and the computer name to the MDM. On a work Mac, `script/doctor` only warns about those settings.
- Refuses `script/update-brewfile`, because a dump would delete the skipped entries from the shared Brewfile.

### Before `script/setup`

- [ ] Check the account name (`whoami`). The launch agent plists spell out `/Users/benbalter`, and the playbook stops if the home directory differs. If the name isn't `benbalter`, update the plists' paths first.
- [ ] Check for admin rights (`sudo -v`). The playbook needs sudo. If IT grants it only for a while at a time, elevate just before running setup.
- [ ] Set the profile:
  ```sh
  mkdir -p ~/.config/dotfiles
  echo 'DOTFILES_PROFILE=work' >> ~/.config/dotfiles/env
  ```
- [ ] Skip section 2's App Store sign-in, Apple ID and Google Drive steps. Use the managed Apple Account if IT issues one.
- [ ] Decide where the SSH and commit-signing keys come from. The tracked config uses the personal 1Password SSH agent and signing key. If policy keeps personal keys off this Mac, override `user.signingkey` in `~/.gitconfig.local` and add the key to GitHub.

### After setup

- [ ] Give work repos their own identity in the untracked `~/.gitconfig.local`, so personal commits keep the personal email:
  ```ini
  [includeIf "gitdir:~/work/"]
  	path = ~/.gitconfig.work
  ```
  Put `[user] email = …` in `~/.gitconfig.work`.
- [ ] Add the work GitHub account alongside the personal one: `gh auth login`, then `gh auth switch` between them.
- [ ] Check for TLS inspection. If the issuer below is the employer's secure web gateway instead of a public CA, tools that bring their own CA list (Node, Python, Homebrew's curl and git, mise downloads) will fail until they trust its root certificate:
  ```sh
  curl -sv https://github.com -o /dev/null 2>&1 | grep -i issuer
  ```
  If it is inspected, export the system keychain's roots to one bundle and point those tools at it from `~/.config/dotfiles/env`. Interactive shells and the nightly `script/update` both read that file.
  ```sh
  security find-certificate -a -p /Library/Keychains/System.keychain \
  	/System/Library/Keychains/SystemRootCertificates.keychain > ~/.config/dotfiles/ca-bundle.pem
  cat >> ~/.config/dotfiles/env <<'EOF'
  export SSL_CERT_FILE="$HOME/.config/dotfiles/ca-bundle.pem"
  export NODE_EXTRA_CA_CERTS="$SSL_CERT_FILE"
  export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
  EOF
  ```
  Containers in Colima's VM need the certificate as well.
- [ ] Use Colima for containers (`colima start`). The docker CLI then talks to its VM, with no Docker Desktop license needed.
- [ ] If IT installs Workbrew, nothing changes: the playbook and scripts detect its wrapper.
- [ ] Don't copy `~/.claude.json` or `~/.claude/` from the personal Mac. They hold personal MCP servers and their tokens. The playbook sets up the shared Claude Code config.
- [ ] Run `script/doctor`. Anything it warns is "managed by IT" is the MDM's call. Ask IT before changing it.

