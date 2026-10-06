---
description: Add a new round map. Usage: /add-map <mode, theme and layout ideas>
---

Add a new map: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/DESIGN.md`, `docs/CUSTOMIZE.md` ("Modes and playlists", "Maps"), `Config.Maps`, `src/server/Maps/MapBase.luau` and an existing builder for the same mode (King Hunt: `PumpkinPatch.luau`; Hide & Seek: `PumpkinFarm.luau` or `HedgeMaze.luau`; ScareMaze: `ScareMaze.luau`). If I didn't say which mode, ask.
2. Write `src/server/Maps/<Id>.luau` in the same style: a `Floor` part and a `Spawns` folder, plus what the mode needs (King Hunt: hotspots, hiding spots, a player-only shortcut, glowing pumpkins; Hide & Seek: tagged `SeekerSpawn`, `HiderSpawn`, plenty of `HidingDecoy` pumpkins, a `SeekerDoor`; ScareMaze: `MazeExit`, `SurvivorSpawn`, `HauntSpawn`, `ScareTrigger` traps). Every repeated decoration goes through `Kit.prop` with the existing prop name for that kind of thing (`Pumpkin`, `JackOLantern`, `Lamppost`, `Lantern`, `HayBale`, `Gravestone`, `DeadTree`... the table in `docs/CUSTOMIZE.md` > "Swap every copy of something at once"; a new name goes in that table), sized through its size argument, so one model in `ReplicatedStorage.Custom.Props` swaps every copy. Draw random numbers before `Kit.prop` (not inside its build function), so a custom model never moves the rest of the map. A part that does something keeps working with any model: use `Kit.look` (look only) or a `Hitbox` (see the header of `src/server/Build/Kit.luau`).
3. Add its settings file `src/shared/Config/Maps/<Id>.luau` (copy an existing one: `Id`, `Name`, `Builder`, `Modes = { "<ModeId>" }`, `Lighting`, `AmbientSound`, `Layout`), list it in `Config.Maps.List` in `src/shared/Config/init.luau`, and add a playlist in `src/shared/Config/Modes.luau` (see `/new-playlist`).
4. Keep part counts and lights reasonable for phones; report the totals.
5. Run `stylua src`, `selene src` and `lune run tests/run` (update the expected playlists in `tests/specs/Rounds.spec.luau`).
6. Playtest: F8 > "<mode>: force next round" until it's this map, then play it (King Hunt: Easy and Hard, the King can path everywhere except player-only shortcuts, pumpkins spawn on open floor; Hide & Seek and ScareMaze: 2 players through Test > Clients and Servers).
7. Commit "Add map: <name>" and push.
