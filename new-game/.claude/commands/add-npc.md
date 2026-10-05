---
description: Add a new NPC to the spawn hub. Usage: /add-npc <who they are and what they do>
---

Add a hub NPC: $ARGUMENTS

1. Read `CLAUDE.md`, `Config.Npcs`, `src/server/Hub/Npcs.luau` (builders and `Npcs.Build`) and `src/client/NpcDialogUI.luau`.
2. Add an entry to `Config.Npcs.List` (Id, Kind, DisplayName, Prompt text, Lines, and where it stands: `Offset` from the hub centre that doesn't overlap other NPCs, decorations or `Config.Lobby.Zones`, or `Zone` = a lobby zone). If it opens the shop, use `OpensShop`.
3. If no existing Kind fits, add a Part-built builder to `src/server/Hub/Npcs.luau` in the same style (parts with a `PaletteRole`, decorations through `Kit.prop`) and register it in `builders`. If it is a character, add its Kind to `CHARACTER_KINDS` and its Id to `Config.Custom.Heights` so a custom model can replace it later.
4. Raise `Config.Hub.BuildVersion` by one so saved hubs pick the NPC up, rebuild the hub in the playtest (F8 > Rebuild hub), talk to the NPC, check the dialog, and run `lune run tests/run`.
5. Commit "Add NPC: <name>" and push. Remind me that a Locked hub keeps its hand edits and doesn't get the NPC: either drag it in by hand or run `require(game.ServerScriptService.Server.Tools.Bake).Hub(true)` in the command bar.
