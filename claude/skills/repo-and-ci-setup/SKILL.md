---
name: repo-and-ci-setup
description: Ben's rules for GitHub repo lifecycle and CI. Covers Renovate configuration, the github-settings OpenTofu repo that owns repo settings, required status checks, and keeping Actions minutes down. Use when creating, archiving, deleting, or changing the visibility or settings of a repo, or when adding, renaming, or restructuring GitHub Actions workflows and jobs.
---

# Repo and CI setup

Visibility still follows the global CLAUDE.md: never create a public repo, or make a private one public, without my explicit approval for that repo.

## Repo settings

- My private [benbalter/github-settings](https://github.com/benbalter/github-settings) repo (OpenTofu) owns my repos' settings. Every new repo, and every archive, delete, or visibility change, gets a matching change there, following its own CLAUDE.md: an entry in `public.tf` or `private.tf` with an import block, then a plan I approve before applying.
- Never change repo settings with `gh api` against the repo itself; the next apply reverts them.

## Dependencies

- New repos get [Renovate](https://docs.renovatebot.com), not Dependabot. Keep Dependabot alerts on, since Renovate reads them, and Dependabot security updates off, since their PRs never auto-merge and Renovate opens the same fixes.
- Each repo's `renovate.json` extends the [renovate-config](https://github.com/benbalter/renovate-config#variants) variant that fits: `:private` for private repos to save CI minutes, `:instant` only where the repo has required status checks, otherwise the default.
- A repo in an org also has to be added to that org's Renovate app installation, which may cover selected repos only.

## CI

- When you rename or reshape CI jobs (matrix names included), update the required status checks that name them, or every later merge waits on a check that never runs. Look at both classic branch protection and rulesets, since each API misses the other.
- Never require a check that skips fork PRs, like CodeQL default setup: it blocks every outside contribution.
- Private repos share my account's Actions spending limit, and GitHub bills each job rounded up to a whole minute. Fold small parallel jobs into one, and cancel superseded PR runs with a `concurrency` group.
