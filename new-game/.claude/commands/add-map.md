---
description: Add a new round map. Usage: /add-map <theme and layout ideas>
---

Add a new map: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/DESIGN.md`, `Config.Maps`, `src/server/Maps/MapBase.luau` and one existing map builder (e.g. `PumpkinPatch.luau`).
2. Write `src/server/Maps/<Id>.luau` in the same style: a Floor part, a Spawns folder, Hotspots, hiding spots, a shortcut only players can use, glowing pumpkins, particles, per-map Lighting and AmbientSound in its own settings file `src/shared/Config/Maps/<Id>.luau` (copy an existing one; include `Modes = { "<ModeId>" }`), listed in `Config.Maps.List` in `src/shared/Config/init.luau`, plus a playlist in `src/shared/Config/Modes.luau`.
3. Keep part counts and lights reasonable for phones; report the totals.
4. Playtest: vote for it, play Easy and Hard, check the King can path everywhere except player-only shortcuts, and check pumpkins spawn on open floor.
5. Commit "Add map: <name>" and push.
