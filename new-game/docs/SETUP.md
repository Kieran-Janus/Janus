# Step-by-step: connect everything

Do the parts in order. Each part ends with a **Check** so you know it worked before moving on.
Time: about 45 minutes the first time. Parts 1-5 get you a working AI-coding loop; Part 6 onward are the in-game AI and publishing.

> Items marked **(verify)** come from docs I could not open directly. Roblox's pages move often, so if a menu name differs, search the exact term in the Creator Hub docs.

---

## Part 1 - Accounts you need

| Account | Link | Why |
| --- | --- | --- |
| Roblox | roblox.com | The game itself |
| GitHub | github.com | You already have it; this repo is your backup |
| Anthropic Console | console.anthropic.com | API key for in-game AI NPCs (separate from a Claude subscription) |
| Cloudflare (free) | dash.cloudflare.com | Hosts the AI proxy |
| Claude (Pro/Max or API access) | claude.ai | Claude Code, which writes your code |

**Check:** you can log in to all five.

---

## Part 2 - Install the toolchain on your computer

You build on your own machine (Windows or Mac). The cloud session this repo was created in cannot run Studio.

1. **Roblox Studio** - download from create.roblox.com -> Studio. Log in.
2. **Git** - git-scm.com (Windows) or `xcode-select --install` (Mac).
3. **Node.js LTS** - nodejs.org (needed for the AI proxy deploy).
4. **VS Code** - code.visualstudio.com. Install extensions: **Luau Language Server** (JohnnyMorganz.luau-lsp), **StyLua**, **Selene**.
5. **Claude Code** - follow the install steps at docs.claude.com (Claude Code -> Quickstart). Then run `claude` once and log in.
6. **Clone this repo:**
   ```sh
   git clone https://github.com/kieran-janus/janus.git
   cd janus
   git checkout claude/clever-clarke-3zqgma
   cd new-game
   ```
7. **Rokit** (installs Rojo and friends):
   - Mac/Linux: `curl -fsSL https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | sh`
   - Windows: download `rokit-*-windows-x86_64.exe` from github.com/rojo-rbx/rokit/releases, run it, then in PowerShell `rokit self-install`.
   - Restart your terminal, then: `rokit trust rojo-rbx/rojo` (and the other tools if prompted), then `rokit install`.

**Check:** `rojo --version`, `stylua --version`, `selene --version`, `claude --version` all print a version. If a version in `rokit.toml` is rejected, run `rokit update` and re-install.

---

## Part 3 - Connect your files to Studio (Rojo)

1. In Studio: **File -> New -> Baseplate**. Save it as `NewGame.rbxl` (anywhere outside the repo; `*.rbxl` is git-ignored anyway).
2. Install the Rojo plugin: Studio -> **Toolbox -> Creator Store**, search **Rojo** (publisher: Rojo / "rojo-rbx"), install. Or run `rojo plugin install` in the terminal.
3. In the terminal, inside `new-game/`:
   ```sh
   wally install        # fine if there are no packages yet
   rojo serve
   ```
   It prints `Listening on port 34872`. Leave it running.
4. In Studio: **Plugins tab -> Rojo -> Connect**. Click Connect.
5. First connect: Rojo shows a diff of what it will sync. Accept it.

**Check:** In Explorer you now see `ServerScriptService > Server > Main`, `ReplicatedStorage > Shared > Config`, and `StarterPlayer > StarterPlayerScripts > Client > Main`. Press **Play**: a bar at the top shows "Waiting for players" (needs 2 players; set `Round.MinPlayers = 1` in `Config/init.luau` for solo testing, save, and watch it update in Studio live).

---

## Part 4 - Connect Claude Code to your files

1. New terminal tab (keep `rojo serve` running), then:
   ```sh
   cd janus/new-game
   claude
   ```
2. Claude reads `CLAUDE.md` automatically. Test it:
   > Set Round.MinPlayers to 1 and IntermissionSeconds to 5.
3. Claude edits `src/shared/Config/` (`init.luau` plus one file per v2 feature); Rojo pushes it into Studio within a second.

**Check:** the change appears in Studio's Explorer under `ReplicatedStorage.Shared.Config` without you doing anything. Press Play and the round starts after 5 seconds.

---

## Part 5 - Connect Claude Code to the live Studio session (MCP)

This is what lets Claude look inside the running game, read errors, and playtest.

**Which server:** Roblox's older open-source server (`Roblox/studio-rust-mcp-server`) is **no longer maintained**. Use the **MCP server built into Roblox Studio**.

### Option A - Quick connect (recommended)
1. Install Claude Code first (Part 2), **then** open Studio. (If Studio was already open, fully quit and reopen it.)
2. In Studio: open the **Assistant** panel -> **Settings -> MCP Servers**.
3. Expand **Quick connect**. You should see **Claude Code** listed. Switch it on.

### Option B - Manual (if Claude Code isn't listed)
Run in your terminal (paths come from Roblox's docs; **(verify)** they match your install):
- **Windows (PowerShell):**
  ```powershell
  claude mcp add Roblox_Studio -- "$env:LOCALAPPDATA\Roblox\mcp.bat"
  ```
- **Mac:**
  ```sh
  claude mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
  ```
Then restart Claude Code.

### Check
- In Claude Code run `/mcp` - `Roblox_Studio` should show as connected.
- Ask: *"Using Studio, list everything in Workspace and tell me if there are any errors in the output."* It should answer from your open place.

Keep Studio open with your place loaded whenever you want Claude to use it. **Rule of thumb:** code lives in `src/` (Rojo); Claude uses MCP for things Rojo doesn't cover: placing parts and models, lighting, UI layout, playtesting, reading logs. Anything it builds only in Studio is **not in git**, so save the place file and ask Claude to describe or script important builds.

---

## Part 6 - Connect the AI NPCs (Anthropic API -> Cloudflare -> Roblox)

The chain is: **Player -> your Roblox server -> Cloudflare Worker -> Anthropic -> back**. Your Anthropic key only ever lives in Cloudflare.

### 6a. Anthropic key
1. console.anthropic.com -> **Settings -> API Keys -> Create Key**. Name it `new-game`. Copy it (shown once).
2. Add billing credit and set a **monthly spend limit** (Settings -> Limits) so a bug can't run up a bill.

### 6b. Make a proxy password
Generate a long random string (this is not your Anthropic key), e.g. `openssl rand -hex 32` or a password manager. Call it `PROXY_KEY`.

### 6c. Deploy the Worker
```sh
cd janus/new-game/tools/ai-proxy
npx wrangler login                      # opens browser, log in to Cloudflare
npx wrangler deploy                     # prints https://newgame-ai-proxy.<you>.workers.dev
npx wrangler secret put ANTHROPIC_API_KEY   # paste the Anthropic key
npx wrangler secret put PROXY_KEY           # paste the random string
```
Test it:
```sh
curl -X POST https://newgame-ai-proxy.<you>.workers.dev/chat \
  -H "x-proxy-key: YOUR_PROXY_KEY" -H "content-type: application/json" \
  -d '{"system":"You are a pirate.","messages":[{"role":"user","content":"hi"}],"max_tokens":50}'
```
**Check:** you get `{"reply":"..."}`. A 401 means the PROXY_KEY doesn't match; a 502 means the Anthropic key or credit is the problem.

### 6d. Publish the place (Secrets need a published experience)
Studio -> **File -> Publish to Roblox** -> create a new experience, name it, leave it private.

### 6e. Turn on HTTP + add the secret
1. Studio -> **Home -> Game Settings -> Security -> Allow HTTP Requests = On**. (Rojo cannot set this for you; turn it on by hand.)
2. Creator Hub (create.roblox.com) -> **Creations -> your experience -> Secrets** **(verify menu name)** -> **Create secret**:
   - Name: `AI_PROXY_KEY` (must match `Config.AI.SecretName`)
   - Value: your `PROXY_KEY`
   - Allowed domain: `newgame-ai-proxy.<you>.workers.dev`

### 6f. Point the game at the Worker
Ask Claude: *"Set Config.AI.ProxyUrl to https://newgame-ai-proxy.<you>.workers.dev/chat"* (or edit `Config/init.luau` yourself).

### 6g. Test in Studio
Secrets work in Studio for your own published place. Run this in the Studio command bar while playing a server (Test -> Start/Server) or have Claude add a ProximityPrompt using `prompts/05-ai-npc.md`:
```lua
print(require(game.ServerScriptService.Server.Services.AIService).Ask(game.Players:GetPlayers()[1], "Guide", "Hello!"))
```
**Check:** a filtered, in-character reply prints. Errors appear as `[AIService] request failed: ...` in Output (most common: HTTP disabled, secret name mismatch, or domain not allow-listed).

---

## Part 7 - Open Cloud API (optional but powerful)

For publishing from the command line, remote DataStore edits, asset uploads.

1. Creator Hub -> **Open Cloud -> API Keys -> Create API Key** **(verify path)**.
2. Name it, then **Add API System** and pick only what you need (for example *Place Publishing* or *Universe Datastores*), and select your experience.
3. Add an IP allow-list if you can, and set an expiry.
4. Copy the key into a local `.env` file (git-ignored): `ROBLOX_API_KEY=...`. **Never commit or paste it into chat.**
5. Ask Claude to write a Lune/Node script that uses it (for example `rojo build` then publish).

---

## Part 8 - AI art and audio tools

These are independent web tools. None need wiring; you generate files and import them.

| Task | Steps |
| --- | --- |
| **3D props** | Studio Assistant (Cube / mesh generation) for quick props; or Meshy / Tripo -> export FBX/OBJ -> Studio **Asset Manager -> Bulk Import** |
| **Textures/decals** | Generate image -> Asset Manager -> Import -> copy the asset ID -> put it in Config |
| **Thumbnails** | `cd ../../thumbnails` - see its README. `generate.mjs` needs `OPENAI_API_KEY` in your environment |
| **Sound** | ElevenLabs/other -> download MP3 -> Asset Manager -> Import (audio is moderated; takes minutes) |

Tip: store asset IDs in `Config/init.luau` (an `Assets` table) so swapping art is a one-line change.

---

## Part 9 - Everyday workflow

```
Terminal 1:  rojo serve
Terminal 2:  claude                  (inside new-game/)
Studio:      Rojo connected, MCP on, press Play to test
```
1. Tell Claude what you want (use `prompts/`).
2. Press Play in Studio and test.
3. Happy? `git add -A && git commit -m "..." && git push` (or ask Claude to commit).
4. Publish: Studio **File -> Publish to Roblox**.

### If something breaks
| Symptom | Fix |
| --- | --- |
| Rojo plugin can't connect | Is `rojo serve` running? Same machine? Port 34872 not blocked by firewall? |
| Explorer is empty after connect | Check the diff dialog was accepted; run `rojo serve` from `new-game/`, not the repo root |
| `Packages` path error | `Packages/` must exist (it has a `.gitkeep`); run `wally install` |
| Claude can't see Studio | Part 5 check: `/mcp`; restart Studio fully, then Claude Code |
| AI NPC says "brain is buffering" | Output window: HTTP off, secret name mismatch, domain not allow-listed, or the Worker returned 401/502 |
| Data not saving in Studio | Game Settings -> Security -> **Enable Studio Access to API Services**; the place must be published |
