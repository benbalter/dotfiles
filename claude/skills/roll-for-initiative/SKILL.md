---
name: roll-for-initiative
description: Settle a deadlock between parallel Claude Code sessions over who goes first or who owns a file, with a commit-reveal roll on a 2^128-sided die. Use when sessions in the same checkout can't agree on order and the conflict isn't about what the right change is.
---

# Roll for initiative

Use this when two or more sessions deadlock over who goes first or who owns a file, rather than waiting on me. If the conflict is about what the right change is, not just who goes first, ask me instead.

1. Roll with this, never a number you pick (sessions running the same model tend to "randomly" pick the same one):

   ```sh
   roll=$(openssl rand -hex 16); echo "$roll"; printf %s "$roll" | shasum -a 256
   ```

2. So no one can react to another's roll, send only the hash first. Reveal the roll once you have every other contender's hash. A roll that doesn't match its hash forfeits.
3. The session that calls the roll runs it: it collects every hash, sends the full set to all contenders, then collects the rolls, checks each against its hash, and posts the order.
4. The highest roll (compared as hex strings) goes first, then the next highest, and so on. One round orders any number of sessions, and with 2^128 sides two rolls never realistically tie, so there's nothing to replay.
