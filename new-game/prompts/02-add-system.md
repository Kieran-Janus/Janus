# Add a gameplay system

```
Add a [SYSTEM, e.g. pet inventory with hatching eggs] to the game.
- Create src/server/Services/[Name]Service.luau with Start(), register it in Main.server.luau.
- All tunables (prices, odds, cooldowns, names) in its own file in src/shared/Config/, with a plain-English header comment.
- An on/off switch in src/shared/Config/Features.luau; when it is off, Start() and the UI do nothing.
- Saved fields added to Config.Data.Template and handled through DataService.
- Client talks to it only through Remotes; validate every argument on the server.
- Add a small client UI in src/client/ (match the existing HUD style); its button is a tile in the top-left Menu (Config.Menu.Tiles), not a loose button.
- Parts in the world that do something are found by CollectionService tag (src/shared/Tags.luau), never by name or position.
- Add a tests/specs/[name].spec.luau and run lune run tests/run.
- Explain how to test it in Studio in 3 steps, and list what a cheater could try and how you blocked it.
```
