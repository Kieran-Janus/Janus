# New Game (AI-built Roblox project)

A fresh, self-contained Roblox project, separate from the other games in this repo. Claude writes the Luau in your editor, Rojo syncs it into Studio, and every gameplay number lives in one file so tweaks take seconds.

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

## What's already built

| Piece | File | Purpose |
| --- | --- | --- |
| Config | `src/shared/Config.luau` | **All** tweakable values: rounds, rewards, economy, AI personas |
| Remotes | `src/shared/Remotes.luau` | One place to declare networking |
| Data | `src/server/Services/DataService.luau` | Load/autosave/save with retries, leaderstats |
| Rounds | `src/server/Services/GameService.luau` | Intermission -> Play -> Reward loop (drop your mode in `runRound`) |
| AI NPCs | `src/server/Services/AIService.luau` | Claude chat with cooldown, history, TextService filtering |
| AI proxy | `tools/ai-proxy/worker.js` | Cloudflare Worker that hides your Anthropic key |
| HUD | `src/client/Main.client.luau` | Round state + timer |

## Easy changes

- **Numbers/names/prices/NPC personalities:** edit `src/shared/Config.luau`, nothing else.
- **New feature:** use `prompts/02-add-system.md`.
- **Reset all player saves:** bump `Config.Data.StoreName` (`PlayerData_v1` -> `v2`).
- **Turn AI off instantly:** `Config.AI.Enabled = false`.

## Turning on AI NPCs

1. `cd tools/ai-proxy && npx wrangler deploy`
2. `npx wrangler secret put ANTHROPIC_API_KEY` and `npx wrangler secret put PROXY_KEY` (make up a long random string).
3. Studio -> Game Settings -> Security -> enable **Allow HTTP Requests**; Creator Hub -> your experience -> **Secrets** -> add `AI_PROXY_KEY` = the same `PROXY_KEY`, allowed domain = your worker domain.
4. Set `Config.AI.ProxyUrl` to `https://<your-worker>.workers.dev/chat`.

Detailed click-by-click connection guide: [`docs/SETUP.md`](docs/SETUP.md).

Full tool/API list and what each is for: [`docs/TOOLS.md`](docs/TOOLS.md).
