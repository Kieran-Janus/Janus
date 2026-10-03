# Everything you need - tools, APIs, add-ons

Grouped by job. **Bold = install first.** Check each tool's own docs for current versions and pricing; these move fast.

## 1. Core (required)

| Tool | What for |
| --- | --- |
| **Roblox Studio** | Build, playtest, publish |
| **Claude Code** (CLI / desktop / web) | Writes and refactors your Luau, runs tools, reads your repo |
| **Rojo** | Syncs files on disk to Studio so Claude can edit real files and git tracks everything |
| **Rokit** | Installs and pins Rojo/Wally/Selene/StyLua versions (`rokit.toml`) |
| **VS Code + Luau Language Server** (or `luau-lsp`) | Autocomplete, type checking, go-to-definition |
| **Git + GitHub** | History, backups, rollbacks, collaboration |

## 2. Connecting Claude to Studio (so it sees the live game)

- **Roblox Studio MCP server**: Roblox ships an official MCP integration, and there is an open-source server (`Roblox/studio-mcp` on GitHub). It lets Claude read the DataModel, insert/edit instances, run code and read output. Add it to Claude Code with `claude mcp add` (follow the repo's README for the exact command for your OS).
- **Roblox Open Cloud API**: server-side HTTP API with API keys. Publish places, read/write DataStores and OrderedDataStores, MessagingService, upload assets, manage users/groups, run Luau remotely ("Luau Execution"). Create keys at Creator Hub -> Open Cloud -> API Keys; scope them minimally.
- **Roblox Assistant** (built into Studio): good for quick in-Studio edits and asset search; use Claude Code for multi-file work.

## 3. AI inside the game

| Tool | What for |
| --- | --- |
| **Anthropic API** (Claude Haiku for speed/cost, a larger Claude model for smarter NPCs) | NPC dialogue, quest generation, announcers, tutorials |
| **Cloudflare Workers** (free tier) | Proxy at `tools/ai-proxy` - protects your key, caps cost |
| **Roblox Secrets store** (`HttpService:GetSecret`) | Holds the proxy key safely |
| **TextService:FilterStringAsync** | Mandatory filtering of any AI/player text |

Tip: cache common replies and keep `max_tokens` low. Hundreds of concurrent players can make AI cost real, so keep `CooldownSeconds` and `MaxMessageLength` in Config.

## 4. AI for assets & art

| Need | Options |
| --- | --- |
| 3D meshes / props | Roblox **Cube / Mesh generation** (Studio Assistant & Open Cloud), Meshy, Tripo, Luma Genie -> clean up in Blender |
| Textures / decals / icons | Roblox Material Generator & texture tools, an image model (this repo's `thumbnails/generate.mjs` already wraps OpenAI image generation), Scenario |
| Thumbnails / icon | `../thumbnails/` tooling, Canva, Photopea |
| Music / SFX | ElevenLabs (SFX + voice), Suno / Udio (check licence terms before uploading), Roblox Creator Store audio |
| NPC voices | ElevenLabs -> upload audio via Creator Hub (audio uploads are moderated) |
| Animation | Roblox Animation Editor, Moon Animator 2 (plugin), Cascadeur / Blender |

## 5. Studio plugins (Creator Store)

Rojo, Moon Animator 2, F3X Building Tools, Tag Editor, Studio Bridge-style debug tools (e.g. "Script Analyzer" is built in), Terrain Tools (built in), Stravant's GapFill/ResizeAlign, Icon Editor, Fusion/React-lua devtools if you adopt them.

## 6. Libraries (Wally)

| Package | What for |
| --- | --- |
| ProfileStore (MadStudioRoblox) | Session-locked data saving, upgrade path from `DataService` |
| Promise (evaera) | Async flow |
| Signal / Trove / Janitor | Events and cleanup |
| Knit or Matter (ECS) | Architecture at scale |
| Fusion / React-lua | Declarative UI |
| TopbarPlus (1ForeverHD) | Topbar buttons/menus |
| ZonePlus | Detect players in zones |
| Lune | Run Luau scripts outside Roblox (build scripts, data tooling) |

## 7. Quality & ops

- **Selene** (lint) and **StyLua** (format) - run before each commit.
- **GitHub Actions**: lint + `rojo build` on every push (add `.github/workflows/ci.yml`).
- **Roblox Creator Analytics**: retention, funnels, custom events via `AnalyticsService`.
- **Discord webhook + Open Cloud MessagingService**: alert on errors, announce updates, global events.
- **Roblox Developer Forum + DevRel docs (create.roblox.com/docs)**: ground truth for APIs.

## 8. Growth

Experience settings (genre, tags, age questionnaire) -> thumbnail A/B (Creator Hub supports testing) -> Roblox Ads / sponsored experiences -> UGC/Influencer codes -> Discord + short-form video clips. Update every 1-2 weeks; the algorithm rewards retention and return visits.

## 9. Suggested build order

1. Rojo + Claude loop working (this repo).
2. Core loop playable in `GameService.runRound` with placeholder parts.
3. One progression + one reward (Config).
4. Art pass using AI-generated meshes/textures, UI pass.
5. AI NPC + one AI-driven feature.
6. `prompts/06-review.md` audit, private-server playtest with friends.
7. Soft launch, watch retention, iterate weekly.
