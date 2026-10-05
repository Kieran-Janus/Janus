# Milestone progress

The `/next-milestone` command reads this file. Update the Status column when a milestone is finished. Do not delete rows.

| # | Goal | Status | Needs the owner? |
| --- | --- | --- | --- |
| M1 | Round loop, map and difficulty voting, pumpkins | done | no |
| M2 | Pumpkin King, catching, ghost state | done | no |
| M3 | Proximity voice, muffle and ghost effects, noise-to-King link | done | publish + friend voice test |
| M4 | Spawn hub: decorations, NPCs, voting board, leaderboard | done | look at it, pick assets |
| M5 | Minion monsters (Skeleton Patrol, Bat Swarm, Ghost Cat) and map art pass on 2 maps | done | pick Creator Store assets |
| M6 | Shop, pumpkin currency, saving, VIP pass and products | blocked | create gamepass/product IDs in Creator Hub |
| V1 | Verify the overnight cloud work in Studio (run `/verify`): skins tab, custom models, codes, daily streak, invite, F8 admin panel, anti-teleport pumpkins | done | 2-player test (see notes) |
| M7 | UI polish, thumbnails and icon, security audit, playtest | in progress | upload thumbnails, friends playtest |
| Launch | Set the experience public on 20 October | todo | yes: only the owner does this |

Status values: `todo`, `in progress`, `done`, `blocked` (add the reason in a note below).

## Notes
- M4: "Spooky Town Square" built from Parts by `src/server/Hub/HubBuilder.luau` (rebuilt at runtime only if `Workspace.Hub` is missing), with dusk lighting, particles, 5 NPCs plus a photo spot with emotes, a live Voting Board and a Leaderboard Gravestone; all tested in Studio. Save the place to keep the Studio copy. Hub lighting also darkens the maps, so M5 needs per-map lighting.
- M5: `MinionService` adds Skeleton Patrols (slow + knockback + noise), Bat Swarms (zig-zag dart, slow) and Ghost Cats (steal a pumpkin that drops back later), all in `Config.Monsters`. Both maps are now themed builds in `src/server/Maps/` (Pumpkin Patch: corn maze, barn shortcut, risky pumpkin field, graveyard; Mansion: 9 furnished rooms, secret doors the King can't path through) with hiding spots, jump fences, hotspots, glowing pumpkins, particles and per-map lighting/ambient sound switched on the client (`ZoneLighting`); tested Easy and Hard in Studio. Still Part-built art: the owner can swap in Creator Store models and set `AmbientSound.SoundId` per map.
- M6: Witch Wanda's shop (B key, Shop button, Witch Wanda, Pumpkin Vendor) sells 12 Part-built hats, trails and pets (`Config.Shop`, `src/shared/Cosmetics.luau`); buying/equipping is server-validated in `ShopService` and saved (Owned, Equipped). `MonetizationService` handles the VIP gamepass (+10% speed, King tracker on T, chat tag, 3 VIP-only cosmetics) and 3 coin packs with receipt-safe granting. Saving tested in Studio across sessions; all IDs are 0, so Robux buttons show "Coming soon".
- **M6 blocked: owner steps.** In Creator Hub (create.roblox.com) > this experience > Monetization:
  1. Passes > Create a Pass named "VIP" (icon optional) > set it On Sale with a price (suggested 249 Robux). Copy its Pass ID into `Config.Monetization.VipGamePassId`.
  2. Developer Products > create "Pumpkin Pouch" (suggested 25 R$), "Pumpkin Cart" (99 R$) and "Pumpkin Mountain" (249 R$). Copy each Product ID into the matching `Id` in `Config.Monetization.Products`.
  3. Publish the place (File > Publish to Roblox) and test one purchase in a live server: Studio test purchases don't charge but also don't prove ProcessReceipt on Roblox's servers.
  Then set this row to `done`. Real prices are whatever you set in Creator Hub; the shop reads them live.
- **Overnight (cloud session, not yet run in Studio):** written and statically checked (luau-lsp with Roblox types, StyLua, Rojo build), but nobody has pressed Play on it yet, so V1 must run first.
  - Customisation: `src/shared/CustomAssets.luau` + `assets/` → `ReplicatedStorage.Custom` (ignoreUnknownInstances). Custom models replace the King (plain model or animated R15 rig), minions, the Witch/Boo/Vendor NPCs (also on a hub saved in Studio) and any cosmetic. Guide: `docs/CUSTOMIZE.md`.
  - New Skins shop tab (Skeleton, Pumpkin Head, Zombie, Ghost, Mummy, VIP Pumpkin King): recolour, hide clothes, head pieces; restores the avatar when removed; hats sit on top of head pieces.
  - Viral features (`docs/VIRAL.md`): Codes (button above Shop; `Config.Codes`), daily streak toast (`Config.Daily`), +10% round coins per friend in the server (cap 50%) and optional group bonus (`Config.Social`), Invite button, one-time favourite prompt after the first round.
  - F8 admin panel in Studio (`AdminService`, `AdminUI`).
  - M7 security audit done; fixes: pumpkin anti-teleport check, AI chat off until it has a UI plus a whole-server request cap, vote spam guard 0.5 s, admin check uses the server-set attribute, three small leaks on players leaving mid-load.
  - M7 art: `thumbnails/output/pumpkin-panic/thumbnail-1920x1080.png` and `icon-512x512.png` (`ONLY=pumpkin-panic node thumbnails/render.mjs` to re-render).
  - Fixed `stylua.toml` (the `syntax` key broke StyLua 0.20, the pinned version).
  - Clip moment: "THE KING HEARD YOU!" banner + flash when the King turns to your noise; nearby players see "The King heard X!" (`Config.King.Heard`, `KingHeardUI`).
  - Skins re-apply after `CharacterAppearanceLoaded` so late-loading clothes don't cover them.
  - Claude Code commands added: `/verify`, `/add-cosmetic`, `/reskin`, `/add-npc`, `/add-monster`, `/add-map`, `/new-code`, `/new-event`, `/tweak`, `/polish-hub`.
- **V1 /verify (5 Oct, Studio, solo playtest):** Output clean on server and client from the start.
  - Pass: spawn on hub pad; all 6 NPC prompts (Witch → shop Skins tab, Vendor → Packs & VIP, Boo tips, Voting Board dialog + live board, Gravestone top list, Photo Spot emote bar, wave plays); voting → map loads → teleport; pumpkins spawn and collect by walking; anti-teleport is a speed limit since the last pickup (~34 studs/s + 20) and works as designed; King appears at 15.0 s, switches Wander → Chase and catches; caught player turns ghost; results screen and return to hub; minions spawn (Easy 2/1/5) and move.
  - Pass: Shop all 5 tabs incl. Skins; all 19 items equip/unequip, VIP-only refused without VIP; buy one per slot from a fresh save; skins hide clothes/colours and restore the avatar exactly; hat sits on top of a skin head piece and drops back when the skin is removed.
  - Pass: Codes (PUMPKIN once then "already used", unknown/empty refused, SPOOKY gives the item); daily toast on rejoin after F8 > Reset daily; Invite opens Roblox's invite prompt; F8 panel: + Coins, Unlock all, Reset daily, Rebuild hub (board re-attaches), Reset my save (asks twice).
  - Pass: custom models: test models in ReplicatedStorage.Custom replaced a hat, the King (scaled to 10 studs) and skeletons; scripts inside them were stripped.
  - Fixed: GameUI used Global ZIndexBehavior, so the raised Shop panel (and the King-heard banner) drew over their own text; now Sibling. Shop panel made nearly opaque so the vote panel doesn't show through.
  - Not tested (needs a 2-player local server: Studio Test tab > Clients and Servers > 2 players): ghost modes (Spectate / Haunt / Ghost chat) and haunting, catching with others still alive, friend bonus, voice routing. With one player, being caught ends the round instantly.
  - M7 polish done: the HUD detail line stays on one line (bar 500 px wide; text shrinks 15 to 10 px to fit, then ends in "...").
  - Note: the test reset my Studio save (F8 > Reset my save) and redeemed PUMPKIN on it.

## Overnight list (6 Oct)
- **Task 1, Sounds: done.** `Config.Sounds` holds every sound (SoundId, Volume, optional PitchMin/PitchMax, RollOffMin/RollOffMax for 3D). Hub music `Config.Hub.Music`, map ambience `Config.Maps.List[i].AmbientSound`, King roar `Config.King.Heard.RoarSoundId` are filled in. All ids are free Creator Store audio (Pro Sound Effects, APM, DistroKid and public uploads), each checked to load in Studio. Client: `src/client/Sounds.luau` (UI click/hover on every button, pickup with random pitch, coins, round-start gong, last-10-second ticks in Voting/Intermission/Playing, caught + ghost whoosh, purchase, daily, code). Server: `SfxService` (3D King footsteps that speed up when chasing, roar, skeleton rattle / bat squeak / cat meow on hits and now and then on their own). Settings button: Music and Sounds on/off, saved per player (`Config.Data.Template.Settings`). Tested solo in Studio: every sound fired, settings saved across rejoin, Output clean.
- **Task 2, Mobile pass: done.** New `src/client/Layout.luau` (tunables in `Config.UI`): the UI scales up on big screens (never down, so phone text stays readable), panels shrink only when they don't fit (`Layout.Fit`), and panels along the bottom keep clear of the thumbstick and jump button on touch screens. Shop, Codes, Invite and Settings live in one side column: bottom-left on PC, top-left on phones and tablets (the thumbstick is bottom-left). Phones get a compact shop (taller panel, shorter cards). Touch: Admin gets a top-right button (no F8 on phones); Sprint, Shout and Tracker already have touch buttons; voting, ghost modes, NPC prompts, codes and invite are all tap targets. Checked with a test harness that mounts the real UI into a 740x300 phone screen and a 1024x710 tablet screen (screenshots: side column, HUD, shop, vote panel, all clear of the thumbstick/jump).
- **Task 3, Results screen: done.** Slides in with a bounce; MVP spotlight (avatar headshot via GetUserThumbnailAsync, spinning gold glow, "X collected N pumpkins!"); rows appear one by one with Survived! / Caught / MVP badges; everyone's coins count up (your count plays the coin sound); your row is highlighted and scrolled into view even outside the top 10; "Next round in X" follows the server timer. Tweak timings, text and colours in `Config.Results` (how long it stays: `Config.Round.ResultsSeconds`). Tested with a real round end and a 12-player sample.
- **Task 4, Round juice: done.** `src/client/RoundJuiceUI.luau`: "RUN!" banner when the King appears, red heartbeat pulse at the screen edges (with a heartbeat sound) while a King within 45 studs is chasing you (the server now tags each King with `TargetUserId`), "+1" floating up from you on pickups, "Last 30 seconds!" warning, "X survivors left" pop when someone is caught. All text, colours, distances and timings in `Config.Juice`. Tested in a round: every moment fired, Output clean.

## Needs Kieran
- **Listen to the sounds.** I could check that every sound loads but not hear them. Play a round with sound on and swap any you don't like in `Config.Sounds` (and Hub.Music, Maps AmbientSound, King.Heard.RoarSoundId).
- **Rojo plugin was disconnected** after Studio restarted, so I synced scripts into Studio through Rojo's local API. Reconnect the Rojo plugin (Plugins > Rojo > Connect) when you're back and save the place.
- **Device emulator check:** I couldn't drive Studio's device emulator, so I tested phone/tablet layouts with a harness. Please open Test > Device (e.g. iPhone 14 landscape, iPad) once and check the side buttons, shop and vote panel, and that Roblox's Sprint/Shout/Track touch buttons don't sit on top of a panel.
- **2-player tests:** the Studio connection can only start solo playtests. Multiplayer checks (3D sounds heard by others, ghost modes, friend bonus, voice) need Test > Clients and Servers > 2 players.
