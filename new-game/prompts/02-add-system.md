# Add a gameplay system

```
Add a [SYSTEM, e.g. pet inventory with hatching eggs] to the game.
- Create src/server/Services/[Name]Service.luau with Start(), register it in Main.server.luau.
- All tunables (prices, odds, cooldowns, names) in Config.luau.
- Saved fields added to Config.Data.Template and handled through DataService.
- Client talks to it only through Remotes; validate every argument on the server.
- Add a small client UI in src/client/ (match the existing HUD style).
- Explain how to test it in Studio in 3 steps, and list what a cheater could try and how you blocked it.
```
