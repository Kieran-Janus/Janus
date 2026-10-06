# Roadmap: from here to launch and beyond

First written 4 October 2026; updated 6 October for v2. Launch target: **20 October**. Halloween: **31 October**.

## Where the game is
| Area | State |
| --- | --- |
| Round loop, pumpkins, results, King, ghosts, voice | Done (M1-M3), voice needs a friend test on the published place |
| Shop, saving, VIP, coin packs | Done (M6), blocked on your Robux IDs |
| Skins, custom models, codes, daily, friends bonus, admin panel | Done and verified in Studio (V1) |
| Thumbnails/icon, security audit | Done (M7 part) |
| **v2**: Ready pad, Hide & Seek, ScareMaze, 5 maps, lobby redesign, parkour, Candy Rush, Web Scour, secret pumpkins, rarity prices, 126 skins and 10 crates, top-left Menu, Pumpkin Vendor fix | Built and tested offline, **needs a Studio check** (`/verify-v2`). What changed: `docs/V2-CHANGES.md` |
| Real art for the King and the maps, friends playtest, launch | To do |

## Your next steps (in order)
1. **Get v2 on your PC** (10 minutes). Follow `docs/V2-CHANGES.md` > "First time after updating": `git pull`, `rokit install`, restart `rojo serve` and reconnect Rojo, restart Claude Code, set Lighting > Technology = Future, press Play.
2. **Verify v2 in Studio:** in Claude Code run `/verify-v2`. It playtests every feature solo, then asks you to start a 2-player test (Test > Clients and Servers) and a phone check (Test > Device), fixes what's broken, runs the tests and pushes. Expect a few small fixes: nobody has pressed Play on v2 yet.
3. **Robux IDs (15 minutes, you only):** Creator Hub > Pumpkin Panic > Monetization: the VIP pass, 3 coin packs and the crates you want to sell for Robux. Paste the IDs into Config (`docs/V2-CHANGES.md` > "Robux setup"), or tell Claude Code "here are my IDs: ...".
4. **Real art:** the Pumpkin King and the round maps are still built from Parts. Put a King model in `ReplicatedStorage > Custom > Characters` (`/reskin PumpkinKing ...`), swap decorations with props (`docs/CUSTOMIZE.md` > props), and bake + hand-edit the maps you want to polish (`Bake.Map("PumpkinFarm")`). Then bake and **Lock** the lobby once you edit it by hand (`/edit-lobby`).
5. **Upload the art:** Creator Hub > experience > Places > Thumbnails: upload `thumbnails/output/pumpkin-panic/thumbnail-1920x1080.png`; Basic Info > Icon: `icon-512x512.png`. Rename the experience (fix "Haloween"), write the description from `docs/VIRAL.md`.
6. **Friends playtest:** publish privately (File > Publish to Roblox), invite 4-8 friends for 30 minutes: every mode, the minigames, crates, voice. Note what's confusing or too hard (parkour jumps, Hide & Seek balance, ScareMaze timing) and fix it with `/tweak`.
7. **Soft launch 18-19 Oct** to friends and a couple of creators (each with their own code: `/new-code`), **public 20 Oct**. Launch checklist: `docs/VIRAL.md`.

## Plan by date
| Dates | Goal |
| --- | --- |
| 6-7 Oct | Pull v2, `/verify-v2` (solo, 2 players, phones), fixes |
| 8 Oct | Robux IDs (VIP, packs, crates); upload thumbnail/icon; rename |
| 9-12 Oct | Real art: King model, map polish (bake + hand edits), props; lock the lobby |
| 13-15 Oct | Balance pass from your own play: parkour difficulty, Hide & Seek and ScareMaze timings, crate prices; sounds you don't like |
| 16-17 Oct | Friends playtest on the private published build (voice, 4-8 players), fix list, phone frame rate |
| 18-19 Oct | Soft launch to friends; creators get personal codes |
| 20 Oct | Public launch; post codes; watch analytics daily |
| 24 Oct | Update 1: new map or playlist (`/add-map`, `/new-playlist`), a new crate (`/add-crate`), new code |
| 31 Oct | Halloween night event: Blood Moon round, double pumpkins, limited cosmetic (`/new-event`) |
| Nov | Session locking (ProfileStore) before any trading; then a winter reskin |

## Framework next steps (for Claude Code)
Remaining engineering items, roughly by value. Paste one at a time or let `/next-milestone` pick them up.
1. **Studio verification of v2** (`/verify-v2`), then fix whatever the 2-player and phone checks find.
2. **"X unboxed a CRAZY skin!"** server-wide announcement (clip moment, small).
3. **Server-wide anti-teleport:** a Heartbeat movement check for every player (pickups, parkour, ScareMaze and rewards already check speed).
4. **Menu > Skins opens "owned only"** and the classic 6 skins get the new rarity effects.
5. **AI NPC chat (optional):** a chat box on an NPC using AIService (proxy in `tools/ai-proxy`), then `Config.AI.Enabled = true`. Needs your Anthropic key and Cloudflare (SETUP Part 6).
6. **ProfileStore** session locking for saves (before any trading or gifting).
7. **Events framework** (`/new-event`) for the Halloween night event.

## Infinite customisation, in one place
- On/off switches: `src/shared/Config/Features.luau`
- Numbers, text, prices, colours, codes, rewards: `src/shared/Config/` (`init.luau` plus one file per v2 feature)
- Looks: models in `ReplicatedStorage > Custom` (or `assets/` in git), props by name
- Lobby: bake, edit by hand, Lock (`docs/CUSTOMIZE.md` > "Editing the lobby and maps by hand")
- Maps: models in `ServerStorage > Maps` (`maps/` in git)
- UI colours/font: `src/client/Theme.luau`
- New behaviour: the slash commands in `docs/CUSTOMIZE.md`
