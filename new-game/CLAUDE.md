# New Game - instructions for Claude

Roblox game written in Luau, synced to Studio with Rojo. This project is independent of every other game in this repo.

## Layout
- `src/shared/` -> ReplicatedStorage.Shared (Config, Remotes, Tags, Items, Lobby, shared modules)
- `src/shared/Config/` -> the Config ModuleScript: `init.luau` (the main table) plus one short file per v2 feature (`Features`, `Modes`, `Lobby`, `Parkour`, `Minigames`, `EasterEggs`, `HideSeek`, `ScareMaze`, `Rarity`, `Crates`, `Menu`), `Maps/<Id>.luau` (one per round map, listed in `Config.Maps.List`) and `Skins/` (crate skins, appended to `Config.Shop.Items`). Still required as `ReplicatedStorage.Shared.Config`.
- `src/server/` -> ServerScriptService.Server (`Main.server.luau` starts the services listed in its `ORDER`, each in `Services/`, each in its own pcall)
- `src/server/Modes/` -> one module per game mode (`KingHunt`, `HideSeek`, `ScareMaze`) with `Run(ctx) -> RoundResult` (types and contract in `Modes/Types.luau`). `GameService` runs the loop (ready players, playlist vote, map, countdowns, rewards, results, back to lobby); a mode only plays and scores the round. Playlists (mode + map) are in `Config.Modes`, helpers in `src/shared/Playlists.luau`.
- `src/client/` -> StarterPlayerScripts.Client (`Main.client.luau` mounts the modules listed in its `ORDER`, each in its own thread)
- `Packages/` -> Wally packages (git-ignored)
- `tools/ai-proxy/` -> Cloudflare Worker that proxies Claude for in-game NPCs
- `prompts/` -> reusable prompts for building features

## Rules
1. **All tunable values go in Config (`src/shared/Config/`).** Never hardcode prices, times, names, or rewards elsewhere. If asked to "tweak" something, change Config first. A feature's settings go in its own file in `src/shared/Config/` (assigned inside the table literal in `init.luau`: `Parkour = require(script.Parkour),`; strict mode seals the table, so never add keys after it). Every Config file/section starts with a short plain-English comment saying what it does and how to change it.
2. Every file starts with `--!strict`. Use Luau types.
3. **Server is authoritative.** Clients send intent through `Remotes`; the server validates type, range, ownership and cooldown on every remote. Never trust client-sent values for currency, damage, or position.
4. New remotes are created via `Remotes.Event("Name")` / `Remotes.Function("Name")`; no loose RemoteEvents in the explorer.
5. New server features = new file in `src/server/Services/` exposing `Start()`, added to `ORDER` in `Main.server.luau`. New client screens = a module with `Mount(gui)` added to `ORDER` in `Main.client.luau`.
6. Persist data only through `DataService`. Add new saved fields to `Config.Data.Template`.
7. Any AI-generated or player text shown to players must pass through `TextService` filtering.
8. Never put API keys in code. Use Roblox Secrets (`HttpService:GetSecret`).
9. Use `task.wait/spawn/delay`, never `wait/spawn/delay`. Clean up connections and instances on player leave.
10. Run `stylua src` and `selene src` before finishing a task.
11. **Feature switches live in `Config.Features`** (`src/shared/Config/Features.luau`): every v2 feature has one. When it's off, the service's `Start()` returns early and the UI's `Mount` shows nothing. A client must never call `Remotes.Event/Function` for a remote the server might not create (it waits forever): create remotes in `Start()` before the feature check, or check the flag on the client first.
12. **Functional parts are found by CollectionService tag**, using the constants in `src/shared/Tags.luau` (`Tags.ReadyPad`, ...), never by name, path or position, so they can be moved, resized or duplicated in Studio.
13. Shop prices come from rarity: use `Items.Price(item)` (`src/shared/Items.luau`), never `item.Price` directly. Lobby areas come from `Config.Lobby.Zones` via `src/shared/Lobby.luau`.
14. Owner test commands: call `AdminService.Register(name, label, fn, danger?)` from your service; the F8 panel picks it up.

## Commands
- `rokit install` - install toolchain
- `wally install` - install packages
- `rojo serve` - live-sync to Studio
- `rojo build -o NewGame.rbxl` - build a place file
- `rojo sourcemap default.project.json -o sourcemap.json` - for luau-lsp
- `lune run tests/run` - offline tests without Studio: the harness builds the DataModel from the Rojo project and runs the real code (Config checks, Items/Lobby, hub and map builders, cosmetics, every module, server + client boot, a full round). Add a `tests/specs/<name>.spec.luau` for new code; see `tests/README.md` (Runtime API, matchers, limits). Run it before finishing a task.
- `lune run tests/preview -- hub` (or `-- map <MapId>`, `-- section <Name>`) - exports a scene JSON for preview images with the cloud renderer (`tests/README.md`, "Preview images").

## Roblox Studio MCP
If the Roblox Studio MCP server is connected, use it to inspect the live DataModel, read output logs, and run playtests to verify changes instead of guessing. Instances created in Studio but not in `src/` are NOT in git; mention it when adding any.

## Customisation (docs/CUSTOMIZE.md)
- Looks are swappable: `src/shared/CustomAssets.luau` lets a model in `ReplicatedStorage.Custom.<Characters|Cosmetics>` (synced from `assets/`, ignoreUnknownInstances) replace any Part-built placeholder. Any new character, NPC or cosmetic you add must support this the same way (check `CustomAssets.Clone` first, keep the placeholder as fallback, add its size to `Config.Custom`).
- Never put scripts inside custom models; they are stripped (`Config.Custom.StripScripts`).
- Test with the F8 admin panel in Studio (`AdminService`/`AdminUI`): coins, unlock all, reset daily, rebuild hub, reset save, plus any command a service registers.
- Slash commands in `.claude/commands/` cover common jobs (`/verify`, `/add-cosmetic`, `/reskin`, `/add-npc`, `/add-monster`, `/add-map`, `/new-code`, `/new-event`, `/tweak`, `/polish-hub`, `/next-milestone`).
- Anti-exploit: positions come from the server; pumpkin pickups reject teleports (`PumpkinService.tooFast`). Keep new pickups/rewards just as strict.

