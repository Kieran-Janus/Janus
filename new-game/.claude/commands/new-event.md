---
description: Add a limited-time event. Usage: /new-event <theme, dates and what changes>
---

Add a limited-time event: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/VIRAL.md` and `docs/DESIGN.md`.
2. Add `Config.Events` (if it doesn't exist) with this event's Start and End as UTC "YYYY-MM-DD HH:MM", and everything it changes: reward multipliers, lighting/sky override, King tweaks, a limited cosmetic (add it to the shop with `EventOnly = "<event id>"` so it's only for sale during the event), an event code.
3. Make the server switch the event on and off by time (check every minute), and show a banner on the HUD while it's on. Everything must go back to normal when it ends.
4. Add a way to force it on in Studio for testing (an F8 admin button).
5. Playtest with it forced on and off.
6. Commit "Event: <name>" and push. Write me a short update log and a social post for it.
