---
description: Add a mode + map pair (a playlist) to the vote. Usage: /new-playlist <mode> on <map>
---

Add a playlist: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` > "Modes and playlists" and "Maps", `src/shared/Config/Modes.luau`, `src/shared/Playlists.luau`, the map's settings file `src/shared/Config/Maps/<MapId>.luau`, `src/shared/Tags.luau` and the mode's module in `src/server/Modes/`.
2. Check the map can host the mode, and tell me what's missing:
   - King Hunt: a `Floor`, the `Spawns` folder, room for the King to walk, hotspots and hiding spots help.
   - Hide & Seek: parts tagged `SeekerSpawn` (inside a seeker hut), `HiderSpawn`, lots of `HidingDecoy` pumpkins and a `SeekerDoor`.
   - ScareMaze: a `MazeExit`, `SurvivorSpawn`, `HauntSpawn` and `ScareTrigger` traps (attribute `Kind`).
   Without the spawn tags everyone starts at `Spawns`. Add what's missing to the map's builder in `src/server/Maps/` (the same style as the existing maps), or tell me how to add the tagged parts by hand to a baked map in `ServerStorage.Maps`.
3. Add the mode to the map file's `Modes` list, and add a playlist to `Playlists` in `Modes.luau`: `{ Id = "<Mode><Map>", Mode = "<Mode>", Map = "<MapId>", Name = "<what the vote button says>", MinPlayers = <n> }`. The `Id` is the vote option id: never rename it once live.
4. Run `stylua src`, `selene src` and `lune run tests/run`. The config spec checks every playlist points at a real map and mode. `tests/specs/Rounds.spec.luau` checks exactly which playlists the vote offers for 1, 2 and more ready players: add the new playlist to those expected lists.
5. Playtest in Studio: press F8 > "<mode>: force next round" until the next round is this playlist, step on the Ready pad and play a full round (2 players through Test > Clients and Servers if the mode needs them). Check spawns, the mode's own parts, results and the return to the lobby.
6. Commit "Playlist: <name>" and push to the current branch.
