---
description: Change the lobby: bake it into the place, lock it, move areas or tagged parts, repair or repaint it. Usage: /edit-lobby <what to change>
---

Change the lobby: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` > "Editing the lobby and maps by hand" and "Lobby areas (zones)", the header of `src/server/Tools/Bake.luau`, the header of `src/server/Services/HubService.luau`, and `src/shared/Config/Lobby.luau`.
2. Through the Studio MCP connection (edit mode, not playing), read `Workspace.Hub`'s attributes `BuildVersion` and `Locked` and compare with `Config.Hub.BuildVersion`. Tell me in one line: built from code / baked and unlocked / baked and Locked, and whether it's older than the code.
3. Pick the right way and tell me before doing it:
   - **A Config change** (moving a zone in `Config.Lobby.Zones`, sizes, colours, decorations in `Config.Hub`): edit Config, try it with F8 > "Rebuild hub" in a playtest, and raise `Config.Hub.BuildVersion` by one so unlocked saved lobbies rebuild. Paths and signposts follow the zones.
   - **A hand edit in the saved place** (best for a Locked lobby): in edit mode, move whole areas (`ReadyArea`, `Shop`, `CrateStand`, `Parkour`, `CandyRush`, `WebScour`: Folders since BuildVersion 9, so move each of their children with `PivotTo`; an older saved hub may still have Models), or move single tagged parts. Keep them on the ground (raycast down), off the paths and inside `Workspace.Hub`: a piece dragged out of the hub to the top of Workspace is removed as a loose copy when the game starts. In a hand-edited lobby the paths and signposts don't follow; move or delete them too.
4. Bake helpers (run in edit mode; each starts with `require(game.ServerScriptService.Server.Tools.Bake)`):
   - `.Hub()` builds the lobby from code into `Workspace.Hub`. It replaces an unlocked lobby, so ask me first if I edited it by hand, and tell me to back it up (right-click `Workspace.Hub` > Save to File).
   - `.Hub(true)` replaces even a Locked lobby (the old one goes to `ServerStorage.HubBackup`). Only when I agree.
   - `.Lock()` after any hand edit, so the game never rebuilds it. `.Unlock()` undoes it.
   - `.Repair()` adds back a missing spawn, Ready pad or shopkeeper. `.Repaint()` applies `Config.Hub.Palette`.
5. Find working parts by their CollectionService tag (`src/shared/Tags.luau`), never by name or position. Never delete the only `HubSpawn`, `ReadyPad` or `ShopKeeper`; check attributes stay (`Index`, `Lane`, `EggId`, `CrateId`, `PaletteRole`).
6. Playtest: spawn, the Ready pad counts me (`ReadyCount`), the shop opens, and every area I touched still works (parkour start and checkpoints, Candy Rush pads, the Web Scour lantern, crate prompts, eggs). The Output shows no "was missing" warnings.
7. Remind me the lobby lives in the place file, not in git: save the place (Ctrl+S) and back it up with Save to File. Commit only code and Config changes ("Lobby: <summary>") and push to the current branch.
