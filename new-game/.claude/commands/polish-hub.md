---
description: Add more detail and life to the lobby, within the phone budget. Usage: /polish-hub <what to improve>
---

Polish the lobby ("Spooky Town Square", `Workspace.Hub`, built by `src/server/Hub/HubBuilder.luau` from `Config.Hub`). $ARGUMENTS

The v2 redesign already has the town square layout, terrain hills, the forest ring, the haunted mansion, the King statue, the pumpkin patch, the clock tower, the cauldron and paths to every area. Build on it; don't start again.

1. Read `CLAUDE.md`, the header of `src/server/Hub/HubBuilder.luau`, `src/server/Build/Props.luau`, `src/server/Hub/HubExtras.luau`, `Config.Hub` and `Config.Lobby.Zones`. Look at the lobby in Studio first (through the Studio connection) and tell me in 3 lines what you'll change.
2. Keep the structure: decorations go in `Decor` groups and skip every lobby zone (`HubLayout.Blocked`) and the paths; reusable decorations go through `Kit.prop` (so a model in `ReplicatedStorage.Custom.Props` can replace them); colours come from `Config.Hub.Palette` with a `PaletteRole`; lobby areas are `src/server/Hub/Sections/`. New numbers go in `Config.Hub` with a short comment.
3. Spooky-cute, never gory. Nothing may block a path, the spawn, the Ready circle or a lobby area, or trip players.
4. Stay within `Config.Hub.Budget` (parts and lights, checked by `tests/specs/HubLook.spec.luau`); report the counts before and after.
5. Raise `Config.Hub.BuildVersion` by one, rebuild the hub (F8 > Rebuild hub), look from the spawn and from above, and run `stylua src`, `selene src` and `lune run tests/run`.
6. Remind me to bake it into the place (`require(game.ServerScriptService.Server.Tools.Bake).Hub()` in edit mode, then save; a Locked lobby needs `.Hub(true)`, which replaces my hand edits). Commit and push.
