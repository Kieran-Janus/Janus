---
description: Tune or change anything from a plain-English request. Usage: /tweak <what you want>
---

Make this change: $ARGUMENTS

1. Read `CLAUDE.md` and `docs/CUSTOMIZE.md` (the "I want to change" table). Find the right place, which is nearly always `src/shared/Config/` (`init.luau` plus one file per v2 feature).
2. If the value isn't in Config yet, move it into Config first, then change it.
3. Before/after: tell me the old and new values in one short list.
4. Playtest the affected part.
5. Commit "Tweak: <summary>" and push.
