---
description: Make the spawn hub bigger and richer.
---

Polish the spawn hub (Workspace.Hub, built by HubBuilder from Config.Hub). $ARGUMENTS

1. Surround it with Terrain: gentle hills, a ring of dead-tree forest, a distant haunted mansion silhouette on a hill. No flat empty void.
2. Make the plaza about 1.5x larger so 32 players fit, and add a graveyard path and a small pumpkin patch corner.
3. Add a large Pumpkin King statue or throne as the centrepiece near the clock tower.
4. Cobblestone in the plaza and grass or mud outside, with warm orange light pools under lanterns against the purple night.
5. Remove or disable the default Baseplate and SpawnLocation if the hub has its own spawn.
6. Keep lights and parts reasonable for phones and report the counts. New numbers go in Config.Hub.
7. Follow the hub structure in `src/server/Hub/HubBuilder.luau`'s header: decorations go in `Decor` groups, skip `Config.Lobby.Zones` (`HubLayout.Blocked`), use `Kit.prop` for reusable props and `PaletteRole` colours from `Config.Hub.Palette`; lobby areas are `src/server/Hub/Sections/`.
8. Raise `Config.Hub.BuildVersion` by one, rebuild the hub (F8 > Rebuild hub), look from the spawn point, run `lune run tests/run`, and remind me to bake it into the place (`require(game.ServerScriptService.Server.Tools.Bake).Hub()` in edit mode, then save; a Locked hub needs `.Hub(true)`). Commit and push.
