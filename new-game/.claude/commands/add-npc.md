---
description: Add a new NPC to the lobby. Usage: /add-npc <who they are and what they do>
---

Add a lobby NPC: $ARGUMENTS

1. Read `CLAUDE.md`, `Config.Npcs` (in `src/shared/Config/init.luau`), `src/server/Hub/Npcs.luau` (builders and `Npcs.Build`), `src/server/Hub/NpcLooks.luau` and `src/client/NpcDialogUI.luau`.
2. Add an entry to `Config.Npcs.List` (Id, Kind, DisplayName, Prompt text, Lines, and where it stands: `Offset` from the hub centre that doesn't overlap other NPCs, decorations, paths or `Config.Lobby.Zones`, or `Zone` = a lobby zone). The Pumpkin Shop is the only shopkeeper: only use `OpensShop` if I ask for a second shop. Don't reuse the Ids `WitchWanda` or `BooGuide` (v2 removed them and deletes their old models from saved lobbies).
3. If no existing Kind fits, add a Part-built builder to `src/server/Hub/Npcs.luau` / `NpcLooks.luau` in the same style (parts with a `PaletteRole`, decorations through `Kit.prop`) and register it in `builders`. If it is a character, add its Kind to `CHARACTER_KINDS` and its Id to `Config.Custom.Heights` so a custom model can replace it later.
4. Raise `Config.Hub.BuildVersion` by one so saved lobbies pick the NPC up, rebuild the hub in the playtest (F8 > Rebuild hub), talk to the NPC, check the dialog, and run `lune run tests/run` (the hub budget test checks the part count).
5. Commit "Add NPC: <name>" and push. Remind me that a Locked lobby keeps its hand edits and doesn't get the NPC: either drag it in by hand or run `require(game.ServerScriptService.Server.Tools.Bake).Hub(true)` in the command bar (that replaces my hand edits).
