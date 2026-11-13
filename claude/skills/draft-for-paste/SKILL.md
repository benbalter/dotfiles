---
name: draft-for-paste
description: How to hand Ben text he'll paste somewhere else (email, text message, Slack, LinkedIn post, PR or issue comment) or an event he'll add to his calendar. Covers clipboard copies, LinkedIn formatting, skimmable structure, and prefilled Gmail and Google Calendar links. Use whenever you draft or revise such a message or event.
---

# Drafting text for me to paste

Load the `writing-style` skill too when the draft is in my voice.

- The terminal's quote bar comes along when I copy a draft, so whenever you show one, also put it on my clipboard with `pbcopy` (macOS only), and again after every revision.
- LinkedIn collapses the blank lines in pasted plain text, so for a LinkedIn draft put both `public.html` (a `<p>` per paragraph, `<p><br></p>` between) and `public.utf8-plain-text` on the pasteboard with JXA's `NSPasteboard` instead of `pbcopy`.
- Follow "Drafting text for me to paste" in `~/.claude/rules/preferences.md` (already in context, since Claude Code loads user rules every session) for skimmable structure and the prefilled Gmail and Google Calendar links. Those rules live there because claude.ai shares them.
