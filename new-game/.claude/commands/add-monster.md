---
description: Add a new minion monster type. Usage: /add-monster <what it does>
---

Add a new minion: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/DESIGN.md`, `Config.Monsters` and `src/server/Services/MinionService.luau` (how Skeleton, Bat and Cat are built, updated and posed).
2. Design it so it never catches players (only the King does). It should slow, steal, scare or make noise, and it must be fair for players without voice.
3. Add `Config.Monsters.<Kind>` with Count per difficulty, speeds, ranges, cooldowns, colours and the hit message. Add a Part-built body, its update function, spawning and posing, all server-side. Add `customBody("<Kind>", ...)` support like the others and a height in `Config.Custom.Heights`.
4. Client feedback goes through the existing MinionHit event and `src/client/MinionFeedback.luau`.
5. Playtest Easy and Hard with 2 players. Check performance (total NPC count) and that it ignores ghosts.
6. Commit "Add monster: <name>" and push.
