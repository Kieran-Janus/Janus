# Hand-edited round maps

This folder is `ServerStorage > Maps` in Studio. A Model here named after a map's Id (for
example `PumpkinPatch`) is loaded for rounds instead of the map the code builds.

- Make an editable copy of a built map: in Studio's command bar (edit mode) run
  `require(game.ServerScriptService.Server.Tools.Bake).Map("PumpkinPatch")`.
- Keep it in git: right-click the map in `ServerStorage > Maps` > **Save to File...** and save
  it here as `PumpkinPatch.rbxm`. Then, with Rojo connected, delete the copy in Studio so
  there is only one (Rojo adds the file's version) and save the place.

It is not inside `assets/` on purpose: everything in `assets/` is sent to every player, while
maps in ServerStorage stay on the server until a round loads them.

Full guide: `docs/CUSTOMIZE.md` > "Editing the lobby and maps by hand".
