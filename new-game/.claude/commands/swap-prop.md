---
description: Swap every copy of a prop (every pumpkin, jack-o'-lantern, lantern, tree...) for one model, in the lobby AND every map, also in a saved lobby or baked map. Usage: /swap-prop <prop name or what it is> [Creator Store id, a model already in Studio, or what it should look like]
---

Swap every copy of a prop: $ARGUMENTS

I (Kieran) am a beginner: tell me in plain words what you're doing, and exactly what to click when you need my hands.

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` > "Swap every copy of something at once" (the table of prop names, where each appears and its size), the header of `src/server/Build/Kit.luau` and of `src/server/Tools/Swap.luau`.
2. **Pick the name.** Match what I asked for to a name in the table (e.g. "every pumpkin" = `Pumpkin`; carved/glowing ones are `JackOLantern`; the King Hunt pickups `CollectPumpkin`; Hide & Seek pumpkins `HidingPumpkin`; parkour jumps `ParkourPumpkin`). If it could mean several (e.g. "all pumpkins"), list them and ask which ones (or all). If it isn't in the table, find the thing I mean through the Studio MCP connection (ask me where it is) and read its `PropName` attribute. If it has none, it can be swapped with `Swap.Replace` (step 6) instead.
3. **Get the model** through the Studio MCP connection (edit mode, not playing):
   - A Creator Store id or search words: insert it, then remove every Script/LocalScript/ModuleScript inside (the game strips them anyway, but keep the place clean) and tell me its creator so I can check the licence.
   - A model I already have in Studio (e.g. `workspace.MyPumpkin`): use a copy of it.
   - A description: build it from Parts/MeshParts, spooky-cute and kid-friendly (never gory), or tell me how to make it with Studio's AI 3D generation (Assistant) and wait.
   It must be ONE Model (group loose parts into a Model). Its front is its pivot's LookVector: check it faces the right way (a jack-o'-lantern's face to the front). Name it exactly the prop name.
4. **Put it in place:** move it into `ReplicatedStorage.Custom.Props` (create `Custom`/`Props` folders only if missing; Rojo normally makes them). Several names (e.g. `Pumpkin` and `JackOLantern`) = one model each.
5. **Saved lobby / baked maps:** read `Workspace.Hub`'s `Locked` attribute and list `ServerStorage.Maps`. If the hub is Locked or there are baked maps, run in edit mode:
   `require(game.ServerScriptService.Server.Tools.Swap).Props()`
   and read the Output line ("Swapped JackOLantern x29, ..."). Tell me the counts. (Built-from-code lobbies and maps swap by themselves on Play; this only makes edit mode show it and keeps it in the place file.)
6. **Things that aren't props** (a part or model I placed by hand many times, no `PropName`): `require(game.ServerScriptService.Server.Tools.Swap).Replace("<Name>", <model>)`, optionally a third argument to limit it (e.g. `workspace.Hub`). Tell me how many it replaced. It never replaces tagged working parts, props, or parts inside a prop (a jack-o'-lantern's core is a part called `Pumpkin`, a gravestone's slab `Tombstone`); given a prop name it refuses and says to use `Custom.Props` + `Swap.Props()` (steps 4-5) instead.
7. **Playtest** (start the game through the MCP connection): look at the lobby, then F8 > force a round on a map where the prop appears (see the "Where it appears" column). Check: it shows everywhere, sized and facing right, not floating or sunk; for gameplay pieces it still works (King Hunt: pick a pumpkin up; Hide & Seek: a hider's pumpkin matches the decoys and candy hits it; parkour: you can stand on the pumpkins; haystacks still hide you). Read the Output: no errors or warnings from `Kit`, `Swap`, `MapService`. Take a screenshot if you can.
8. **If it looks wrong:** too big/small in some places is expected when its shape differs a lot (it's scaled to each copy's height; a `KeepSize` attribute keeps the built size); facing: rotate the model and edit its pivot, then run step 5 again (it replaces the copies with fresh ones). To undo: Ctrl+Z right after, or take the model out of `Custom.Props` and run `Swap.Props({ Revert = true })`.
9. **Keep it in git:** export the model as `assets/Props/<Name>.rbxmx` (XML, readable diffs) if the MCP connection can save files; otherwise tell me: right-click it > Save to File... > `new-game/assets/Props/<Name>.rbxm`. Remind me to save the place (Ctrl+S): a swapped Locked lobby or baked map lives in the place file, not in git.
10. Only if you changed code: run `stylua src`, `selene src` and `lune run tests/run`, then commit and push. A model-only swap needs no commit unless you exported it to `assets/` (then commit "Props: custom <Name>" and push).
