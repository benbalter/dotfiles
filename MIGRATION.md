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

On a work Mac, do the [Work Mac](#work-mac) "Before `script/setup`" steps first. A work Mac skips this section's Apple ID, App Store and Google Drive steps.

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
sudo -v               # keep a sudo session open for Homebrew and App Store installs
script/setup          # personal Mac
script/setup --work   # employer-managed Mac: do the Work Mac "Before setup" steps first
```

What to expect:

- Bootstrap creates a Python venv and installs Ansible.
- Ansible installs every formula, cask, Mac App Store app, and VS Code extension from `Brewfile` (a work Mac installs only the casks `Brewfile.work-skip` opts in, and no App Store apps). **First run takes 20–60 minutes.**
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
- [ ] **Mac App Store apps installed** (personal Mac; a work Mac skips them):
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
- [ ] **Privacy settings no script can set.** The playbook covers the rest (firewall and stealth mode, analytics sharing, Siri audio, Safari fingerprint protection, Chrome policy). These stay manual on a personal Mac because only an MDM can manage them, or Apple offers no interface at all:
  - **Private Wi-Fi address → Rotating** for public networks (System Settings → Wi-Fi → network → Details). It's set per network in a root-owned plist keyed by network name, and network names don't belong in this public repo.
  - **Location Services** (Privacy & Security): turn off apps that don't need it, and under System Services turn off at least Mac Analytics and Significant Locations & Routes. locationd's settings are protected.
  - **Camera, Microphone, Local Network, Full Disk Access and Files & Folders** (Privacy & Security): revoke what isn't used day to day. TCC, the permission database, is protected by System Integrity Protection, and Local Network permission isn't stored in TCC at all.
  - **Advanced Data Protection** (System Settings → your name → iCloud): an iCloud account setting with no API. Set up a recovery contact or key first.
  - **iPhone and iPad:** install [`ios/privacy.mobileconfig`](ios/privacy.mobileconfig) and work through [the iOS checklist](ios/README.md).

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
- [ ] **Browser profiles** — sign in to Chrome/Safari to sync; or import bookmarks manually. Chrome policy for balter.com ([`script/chrome-policy`](script/chrome-policy)) applies at sign-in, with nothing to run on the new Mac.
- [ ] **iMessage / Messages history** — handled by iCloud if enabled.
- [ ] **Photos library** — iCloud Photos.

## 6. Decommission the old machine

- [ ] One last `git push` of every working tree.
- [ ] Confirm 1Password and Google Drive say "Up to date".
- [ ] Sign out of iCloud, App Store, and iMessage (System Settings).
- [ ] Erase all content and settings.

## Work Mac

An employer-managed Mac runs the same playbook with `DOTFILES_PROFILE=work` ([`lib/profile`](lib/profile)). That profile:

- Installs only the casks opted in with `!cask` lines in [`Brewfile.work-skip`](Brewfile.work-skip) and no Mac App Store apps, and skips the formulae and mise tools it lists (hobby and network-probing tools, Caddy, and file-sync tools like rclone and restic that data-loss prevention watches for). To add an app, add a `!cask` line there. An app already installed by hand needs `brew install --cask --adopt <name>` once, or brew bundle fails on it.
- Leaves the firewall, FileVault, remote-access and System Settings lockdowns, update policy, the login window and the computer name to the MDM, and `script/doctor` only warns about them. Gatekeeper, TouchID for `sudo`, and turning off automatic login still apply.
- Keeps the nightly update job (`com.balter.ben.update`) disabled, since an agent that pulls a public repo and upgrades packages unattended looks like persistence to endpoint security. Run `up` by hand. The tmpreaper job, which deletes week-old files from `~/Downloads`, stays off too.
- Gives repos whose remote is the employer's the work email, through [`script/git-work-identity`](script/git-work-identity), which writes `~/.config/git/work` from the env file. Every other repo keeps the personal email. With `DOTFILES_WORK_GH_USER` set, HTTPS pushes to the org's github.com repos also use the work GitHub account.
- Blocks employer details (the work email's domain, the work git hosts and org, and `DOTFILES_WORK_LEAK_TERMS`) from commits and commit messages in any repo that isn't a work repo, through the gitleaks `pre-commit` and `commit-msg` hooks in [`.config/git/template`](.config/git/template). PR and issue bodies never pass through git, so they aren't covered. Run [`script/install-git-hooks`](script/install-git-hooks) once to add the hooks to repos cloned before setup.
- Signs commits and tags with a local SSH key instead of 1Password, which a work Mac doesn't install, once `DOTFILES_SSH_SIGNING_KEY` is set (see below), by writing the key to `~/.gitconfig.local`. Until then, signing is off and `script/doctor` warns.
- Leaves other local accounts alone, because on a work Mac that's usually IT's admin account.
- Switches back with `script/setup --personal`.
- Refuses `script/update-brewfile`, because a dump would delete the skipped entries from the shared Brewfile.

### Before `script/setup`

- [ ] Check for admin rights (`sudo -v`). The playbook needs sudo. If IT grants it only for a while at a time, elevate just before running setup.
- [ ] Tell the playbook which repos are work repos, in `~/.config/dotfiles/env`. Matching is by remote URL (HTTPS, `git@host:` and `ssh://`, with or without a port), and each entry is a host or a host and path prefix. Every other repo, including a new one with no remote yet, keeps the personal email. Setup fails on a work Mac without these, rather than commit to work repos with the personal email:
  ```sh
  DOTFILES_WORK_EMAIL=<work-email>
  DOTFILES_WORK_GIT_REMOTES="<gitlab-host> github.com/<org>"
  # Optional: the work GitHub login, so HTTPS pushes to github.com/<org>
  # use it without `gh auth switch`
  DOTFILES_WORK_GH_USER=<work-github-login>
  # Optional: more words the leak guard blocks outside work repos (the
  # employer's name, internal tool names), on top of the domain and hosts
  DOTFILES_WORK_LEAK_TERMS="<employer> <internal-tool>"
  ```
- [ ] Run setup as `~/.files/script/setup --work` (in section 3), which writes `DOTFILES_PROFILE=work` to `~/.config/dotfiles/env` before anything else runs. Plain `script/setup` would apply the personal profile's security and update settings over the MDM's.
- [ ] Skip section 2's App Store sign-in, Apple ID and Google Drive steps. Use the managed Apple Account if IT issues one.
- [ ] Decide where the SSH keys come from. Without 1Password, `.ssh/config` falls back to the system agent, so keys added with `ssh-add --apple-use-keychain` work there.
- [ ] Create a local commit-signing key, held by the system agent with its passphrase in the Keychain, and point the env file at its public key. Use `$HOME`, not `~`, so the path expands when the file is sourced:
  ```sh
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_signing -C "work-mac signing"
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519_signing
  echo 'DOTFILES_SSH_SIGNING_KEY="$HOME/.ssh/id_ed25519_signing.pub"' >> ~/.config/dotfiles/env
  ```
  Add it as a signing key to each GitHub account this Mac commits as (`gh ssh-key add ~/.ssh/id_ed25519_signing.pub --type signing`, once per account). Interactive shells reload it into the agent after a reboot. It stays out of the tracked `allowed_signers`, whose line would carry the work email, so local `git log --show-signature` calls these commits unverified while GitHub verifies them.

### After setup

- [ ] On a work Mac set up before the work email existed (or after a change to the two variables above), apply it without a full setup. `up` won't, since it reruns only the playbook's `defaults,security` tags:
  1. Add `DOTFILES_WORK_EMAIL` and `DOTFILES_WORK_GIT_REMOTES` to `~/.config/dotfiles/env`, as above.
  2. Run `~/.files/script/git-work-identity`. It prints `changed` when it writes `~/.config/git/work`.
  3. In a work repo and in `~/.files`, run `git config --show-origin user.email`. Expect the work email, then the personal one.
  4. Check for commits already made with the wrong email (`git log --format='%h %ae %s' @{u}..` in each repo touched since setup). Amend unpushed ones with `git commit --amend --reset-author`. Decide case by case before rewriting a pushed commit that has the work email in a public repo.

  `script/doctor`'s Git identity section warns until this is done.
- [ ] Add the work GitHub account alongside the personal one with `gh auth login`. Git pushes pick the account by remote once `DOTFILES_WORK_GH_USER` is set, but `gh` commands themselves (`gh pr create`) still use the active account, so `gh auth switch` before those.
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
- [ ] Run `script/doctor`. Anything it flags as managed by IT's MDM is the MDM's call. Ask IT before changing it.

