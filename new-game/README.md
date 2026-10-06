# New Game (AI-built Roblox project)

A fresh, self-contained Roblox project, separate from the other games in this repo. Claude writes the Luau in your editor, Rojo syncs it into Studio, and every gameplay number lives in one Config folder (`src/shared/Config/`) so tweaks take seconds.

## Quick start

```sh
cd new-game
curl -fsSL https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | sh   # or: brew install rokit
rokit install          # rojo, wally, selene, stylua, luau-lsp, lune
wally install          # packages (optional until you add some)
rojo serve             # then Studio -> Plugins -> Rojo -> Connect
```

1. Open Roblox Studio, create a blank Baseplate, install the **Rojo** plugin (Creator Store), click Connect.
2. In another terminal run `claude` inside `new-game/`. It reads `CLAUDE.md` automatically.
3. Ask for changes (see `prompts/`). Rojo pushes them into Studio live. Press Play to test.

## What's new in v2
Pumpkin Panic v2 adds a Ready pad, two new modes (Pumpkin Hide & Seek, ScareMaze) and three new maps, a redesigned lobby with parkour, Candy Rush, Web Scour and secret pumpkins, rarity prices, 126 skins and 10 crates, and a top-left Menu. Plain-English guide, update steps, on/off switches and undo steps: [`docs/V2-CHANGES.md`](docs/V2-CHANGES.md). Test it in Studio with `/verify-v2` in Claude Code.

## What's already built

| Piece | File | Purpose |
| --- | --- | --- |
| Config | `src/shared/Config/` (`init.luau` plus one file per v2 feature) | **All** tweakable values: rounds, rewards, economy, AI personas |
| Feature switches | `src/shared/Config/Features.luau` | Turn any v2 feature on or off with one line |
| Remotes | `src/shared/Remotes.luau` | One place to declare networking |
| Data | `src/server/Services/DataService.luau` | Load/autosave/save with retries, leaderstats |
| Rounds | `src/server/Services/GameService.luau` | Ready players -> playlist vote -> map -> the mode plays -> results -> back to the lobby |
| Game modes | `src/server/Modes/` | `KingHunt`, `HideSeek`, `ScareMaze` (mode + map pairs in `Config/Modes.luau`) |
| Lobby | `src/server/Hub/` | "Spooky Town Square": one file per area in `Hub/Sections/`, bake and edit by hand with `src/server/Tools/Bake.luau` |
| Shop and crates | `ShopService`, `CrateService`, `src/client/ShopUI.luau`, `CrateUI.luau` | Rarity prices, skins, crates with an odds preview |
| AI NPCs | `src/server/Services/AIService.luau` | Claude chat with cooldown, history, TextService filtering |
| AI proxy | `tools/ai-proxy/worker.js` | Cloudflare Worker that hides your Anthropic key |
| UI | `src/client/Main.client.luau` | Mounts every screen; buttons live in the top-left Menu |
| Tests | `tests/` | `lune run tests/run`: 1,100+ offline tests, no Studio needed |

## Easy changes

- **Numbers/names/prices/NPC personalities:** edit `src/shared/Config/` (`init.luau` plus one file per v2 feature), nothing else. Recipes: [`docs/CUSTOMIZE.md`](docs/CUSTOMIZE.md).
- **Turn a feature off:** `src/shared/Config/Features.luau`, change its line to `false`.
- **New feature:** use `prompts/02-add-system.md`, or a slash command (`/add-skin`, `/add-crate`, `/add-map`, ... listed in `docs/CUSTOMIZE.md`).
- **Reset all player saves:** bump `Config.Data.StoreName` (`PlayerData_v1` -> `v2`).
- **Turn AI off instantly:** `Config.AI.Enabled = false`.

## Turning on AI NPCs

1. `cd tools/ai-proxy && npx wrangler deploy`
2. `npx wrangler secret put ANTHROPIC_API_KEY` and `npx wrangler secret put PROXY_KEY` (make up a long random string).
3. Studio -> Game Settings -> Security -> enable **Allow HTTP Requests**; Creator Hub -> your experience -> **Secrets** -> add `AI_PROXY_KEY` = the same `PROXY_KEY`, allowed domain = your worker domain.
4. Set `Config.AI.ProxyUrl` to `https://<your-worker>.workers.dev/chat`.

Detailed click-by-click connection guide: [`docs/SETUP.md`](docs/SETUP.md).

Full tool/API list and what each is for: [`docs/TOOLS.md`](docs/TOOLS.md).
