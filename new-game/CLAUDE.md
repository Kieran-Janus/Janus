# New Game - instructions for Claude

Roblox game written in Luau, synced to Studio with Rojo. This project is independent of every other game in this repo.

## Layout
- `src/shared/` -> ReplicatedStorage.Shared (Config, Remotes, shared modules)
- `src/server/` -> ServerScriptService.Server (`Main.server.luau` starts services in `Services/`)
- `src/client/` -> StarterPlayerScripts.Client
- `Packages/` -> Wally packages (git-ignored)
- `tools/ai-proxy/` -> Cloudflare Worker that proxies Claude for in-game NPCs
- `prompts/` -> reusable prompts for building features

## Rules
1. **All tunable values go in `src/shared/Config.luau`.** Never hardcode prices, times, names, or rewards elsewhere. If asked to "tweak" something, change Config first.
2. Every file starts with `--!strict`. Use Luau types.
3. **Server is authoritative.** Clients send intent through `Remotes`; the server validates type, range, ownership and cooldown on every remote. Never trust client-sent values for currency, damage, or position.
4. New remotes are created via `Remotes.Event("Name")` / `Remotes.Function("Name")`; no loose RemoteEvents in the explorer.
5. New server features = new file in `src/server/Services/` exposing `Start()`, registered in `Main.server.luau`.
6. Persist data only through `DataService`. Add new saved fields to `Config.Data.Template`.
7. Any AI-generated or player text shown to players must pass through `TextService` filtering.
8. Never put API keys in code. Use Roblox Secrets (`HttpService:GetSecret`).
9. Use `task.wait/spawn/delay`, never `wait/spawn/delay`. Clean up connections and instances on player leave.
10. Run `stylua src` and `selene src` before finishing a task.

## Commands
- `rokit install` - install toolchain
- `wally install` - install packages
- `rojo serve` - live-sync to Studio
- `rojo build -o NewGame.rbxl` - build a place file
- `rojo sourcemap default.project.json -o sourcemap.json` - for luau-lsp

## Roblox Studio MCP
If the Roblox Studio MCP server is connected, use it to inspect the live DataModel, read output logs, and run playtests to verify changes instead of guessing. Instances created in Studio but not in `src/` are NOT in git; mention it when adding any.

## Customisation (docs/CUSTOMIZE.md)
- Looks are swappable: `src/shared/CustomAssets.luau` lets a model in `ReplicatedStorage.Custom.<Characters|Cosmetics>` (synced from `assets/`, ignoreUnknownInstances) replace any Part-built placeholder. Any new character, NPC or cosmetic you add must support this the same way (check `CustomAssets.Clone` first, keep the placeholder as fallback, add its size to `Config.Custom`).
- Never put scripts inside custom models; they are stripped (`Config.Custom.StripScripts`).
- Test with the F8 admin panel in Studio (`AdminService`/`AdminUI`): coins, unlock all, reset daily, rebuild hub, reset save.
- Slash commands in `.claude/commands/` cover common jobs (`/verify`, `/add-cosmetic`, `/reskin`, `/add-npc`, `/add-monster`, `/add-map`, `/new-code`, `/new-event`, `/tweak`, `/polish-hub`, `/next-milestone`).
- Anti-exploit: positions come from the server; pumpkin pickups reject teleports (`PumpkinService.tooFast`). Keep new pickups/rewards just as strict.

