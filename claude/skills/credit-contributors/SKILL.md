---
name: credit-contributors
description: Credit and thank external contributors to Ben's projects. Use when writing a changelog, release notes, or a GitHub release, and when merging a pull request from someone outside the project's maintainers.
---

# Credit contributors

An external contributor is anyone outside the project's maintainers.

- Changelogs and release notes credit every external contributor, docs-only ones included, even if they need a line of their own. Check each PR's author (`gh pr view <n> --json author`), not the merge commit's branch name, and link their handle the way the project already does (e.g. "Thanks to [@handle](https://github.com/handle).").
- After merging an external contributor's PR, post a brief, friendly comment thanking them by handle, but only once `gh pr view <n> --json state` confirms the merge; a blocked merge leaves a premature thank-you behind.
