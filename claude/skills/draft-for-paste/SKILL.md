---
name: draft-for-paste
description: How to hand Ben text he'll paste somewhere else (email, text message, Slack, LinkedIn post, PR or issue comment) or an event he'll add to his calendar. Covers clipboard copies, LinkedIn formatting, skimmable structure, and prefilled Gmail and Google Calendar links. Use whenever you draft or revise such a message or event.
---

# Drafting text for me to paste

Load the `writing-style` skill too when the draft is in my voice.

- The terminal's quote bar comes along when I copy a draft, so whenever you show one, also put it on my clipboard with `pbcopy` (macOS only), and again after every revision.
- LinkedIn collapses the blank lines in pasted plain text, so for a LinkedIn draft put both `public.html` (a `<p>` per paragraph, `<p><br></p>` between) and `public.utf8-plain-text` on the pasteboard with JXA's `NSPasteboard` instead of `pbcopy`.
- Break every drafted message up for skimming, even a quick text or DM: one idea per short paragraph, a blank line between paragraphs, the ask on its own line, and a list when there are several items or steps.
- When drafting an email, new or reply, also give me a Gmail compose link that prefills it whenever you know the recipient: `https://mail.google.com/mail/?view=cm&fs=1&to=…&cc=…&bcc=…&su=…&body=…`, with every value URL-encoded (newlines as `%0A`). Omit empty fields.
- For events, give me a Google Calendar link that prefills it: `https://calendar.google.com/calendar/render?action=TEMPLATE&text=…&dates=…&details=…&location=…`, URL-encoded, with `dates` as `YYYYMMDDTHHMMSS/YYYYMMDDTHHMMSS` (or `YYYYMMDD/YYYYMMDD` for all-day). If you write an `.ics` file, link it too.
