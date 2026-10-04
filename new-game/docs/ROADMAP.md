# Roadmap: from here to launch and beyond

Written 4 October 2026 (night). Launch target: **20 October**. Halloween: **31 October**.

## Where the framework is
| Area | State |
| --- | --- |
| Round loop, voting, pumpkins, results | Done (M1) |
| Pumpkin King AI, ghosts | Done (M2) |
| Proximity voice, muffle, ghost echo, King hears voice | Done (M3), needs a friend voice test on the published place |
| Spawn hub with NPCs, board, leaderboard | Done (M4) |
| Minions and themed maps | Done (M5) |
| Shop, saving, VIP, coin packs | Done (M6), blocked on your Robux IDs |
| Skins, custom models, codes, daily, friends bonus, admin panel | Written overnight, **verify first (V1)** |
| Thumbnails/icon, security audit | Done (M7 part) |
| UI polish, friends playtest, launch | To do |

## Your next steps (in order)
1. **Get the overnight work on your PC.** In the `powershell` terminal (not `rojo`): `git pull`. Restart Claude Code (Ctrl+C twice, then `claude`) so it sees the new commands. Keep `rojo serve` running and Studio connected.
2. **Verify it:** in Claude Code run `/next-milestone` (it picks V1) or `/verify`. It playtests everything and fixes what's broken. Expect a couple of small fixes: I couldn't press Play from the cloud.
3. **Unblock M6 (10 minutes, you only):** Creator Hub > your experience > Monetization: create the VIP pass and 3 developer products, paste the IDs into `Config.Monetization` (steps are in `docs/PROGRESS.md` under M6). Or tell Claude Code: "here are my IDs: ...".
4. **Upload the art:** Creator Hub > experience > Places > Thumbnails: upload `thumbnails/output/pumpkin-panic/thumbnail-1920x1080.png`; Basic Info > Icon: `icon-512x512.png`. Rename the experience (fix "Haloween"), write the description from `docs/VIRAL.md`.
5. **Make it look like yours:** `/polish-hub`, then reskin the King and NPCs (`/reskin PumpkinKing ...`, or build/insert models in Studio, see `docs/CUSTOMIZE.md`). Add a few more cosmetics with `/add-cosmetic`.
6. **M7 finish:** `/next-milestone` for the UI polish pass. Then a friends playtest on the private published build with voice.
7. **Soft launch 18-19 Oct, public 20 Oct.** Launch checklist: `docs/VIRAL.md`.

## Plan by date
| Dates | Goal |
| --- | --- |
| 5-6 Oct | V1 verify + fixes; Robux IDs; upload thumbnail/icon; rename |
| 7-9 Oct | Visual pass: polish hub, reskin King/NPCs/minions, 4-6 new cosmetics |
| 10-12 Oct | UI polish (M7): consistent buttons, mobile layout, results screen juice, sounds |
| 13-15 Oct | Clip moments: King roar sound (banner is done), ghost "haunt cam" |
| 16-17 Oct | Friends playtest (voice), fix list, performance check on a phone |
| 18-19 Oct | Soft launch to friends; creators get personal codes |
| 20 Oct | Public launch; post codes; watch analytics daily |
| 24 Oct | Update 1: new map (Graveyard Party), new cosmetics, new code |
| 31 Oct | Halloween night event: Blood Moon round, double pumpkins, limited cosmetic |
| Nov | Session locking (ProfileStore) before any trading; then winter reskin idea |

## Framework next steps (for Claude Code)
These are the remaining engineering items, roughly by value. Paste one at a time or let `/next-milestone` take M7.
1. ~~"The King heard you" moment~~ **done overnight**: banner + red flash for the heard player, "The King heard X!" for players nearby (`Config.King.Heard`). Add a roar: put a Creator Store sound id in `Config.King.Heard.RoarSoundId`.
2. **Mobile pass:** every button reachable on a phone (Sprint/Shout/Tracker/Codes/Invite/Shop), text readable at 360 px wide, no overlap with Roblox's own buttons.
3. **Sounds:** pickup, King footsteps, King roar, ghost whoosh, UI clicks (all `SoundId`s in Config so you can swap them).
4. **Results screen juice:** coin count-up, MVP spotlight, "Play again" auto-continues.
5. **AI NPC chat (optional):** a chat box on Boo Guide using AIService (proxy in `tools/ai-proxy`), then `Config.AI.Enabled = true`. Needs your Anthropic key and Cloudflare (SETUP Part 6).
6. **Server-wide anti-teleport:** a Heartbeat movement validator (the pumpkin check covers the main exploit today).
7. **ProfileStore** session locking for saves (before any trading or gifting).
8. **Events framework** (`/new-event`) for the Halloween night event.

## Infinite customisation, in one place
- Numbers, text, prices, colours, codes, rewards: `src/shared/Config.luau`
- Looks: models in `ReplicatedStorage > Custom` (or `assets/` in git)
- Maps: models in `ServerStorage > Maps`
- UI colours/font: `src/client/Theme.luau`
- New behaviour: the slash commands in `docs/CUSTOMIZE.md`
