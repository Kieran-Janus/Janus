---
description: Add a new NPC to the spawn hub. Usage: /add-npc <who they are and what they do>
---

Add a hub NPC: $ARGUMENTS

1. Read `CLAUDE.md`, `Config.Npcs`, `src/server/Hub/HubBuilder.luau` (builders and `buildNpcs`) and `src/client/NpcDialogUI.luau`.
2. Add an entry to `Config.Npcs.List` (Id, Kind, DisplayName, Offset that doesn't overlap other NPCs or decorations, Prompt text, Lines). If it opens the shop, use `OpensShop`.
3. If no existing Kind fits, add a Part-built builder to HubBuilder in the same style and register it. Add its Id to `Config.Custom.Heights` so a custom model can replace it later.
4. Rebuild the hub in the playtest (F8 > Rebuild hub), talk to the NPC, check the dialog.
5. Commit "Add NPC: <name>" and push. Remind me to save the place (or delete Workspace.Hub and save) so the Studio copy has the new NPC.
