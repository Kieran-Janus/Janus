# Overnight report (6 October)

Nine tasks, one commit each, all pushed to `claude/clever-clarke-3zqgma`. Every task was formatted (StyLua), linted (Selene: 0 errors, 0 warnings) and playtested in Studio with a clean Output window. Every new number, sound, colour and line of text is in `src/shared/Config.luau`.

## Look at these first

1. **Save the place in Studio (Ctrl+S).** The hub was rebuilt with the new decorations and terrain in edit mode and isn't saved yet.
2. **Reconnect Rojo** (Plugins > Rojo > Connect). It was disconnected after Studio restarted; I synced the scripts through Rojo's local API instead, so Studio matches git right now.
3. **Play one round with sound on.** I checked every sound loads, but I can't hear them. Swap anything you don't like in `Config.Sounds`.
4. **Run a 2-player test** (Test > Clients and Servers > 2 players). The Studio connection only starts solo playtests, so ghost modes with others still alive, 3D sounds heard by the other player, the friend bonus and voice still need you.
5. **Check a phone in the device emulator** (Test > Device, e.g. iPhone 14 landscape, then an iPad).

## What I did

| # | Task | Result | Commit |
| --- | --- | --- | --- |
| 1 | Sounds | Done | `edf83a0` |
| 2 | Mobile pass | Done (harness-tested; emulator check for you) | `1cde3e3` |
| 3 | Results screen juice | Done | `2da5bf3` |
| 4 | Round juice | Done | `b16ce42` |
| 5 | Ghost haunt cam + Watch King | Done | `110481f` |
| 6 | Hub polish | Done (save the place) | `32cb014` |
| 7 | 6 more cosmetics | Done | `6a35c39` |
| 8 | Performance and safety | Done (solo; 2-player for you) | `4830181` |
| 9 | Final verify + this report | Done | this commit |

### 1. Sounds
- `Config.Sounds` has every effect (SoundId, Volume, optional random pitch, 3D range). Hub music, map ambience and the King's roar are filled in too.
- All ids are free Creator Store audio (Pro Sound Effects, APM and DistroKid, which are licensed for Roblox, plus public uploads). I skipped obvious rips from other games. Each one was checked to load in Studio.
- Client (`src/client/Sounds.luau`):
  - click and hover on every button in the game UI
  - pumpkin pickup (random pitch), coins gained
  - round-start gong, countdown ticks in the last 10 s of voting, intermission and the round
  - caught, then a ghost whoosh
  - purchase, daily reward and code redeemed
- Server (`SfxService`): 3D King footsteps (faster when chasing), the roar when he hears someone, and skeleton rattle / bat squeak / cat meow, both on hits and now and then on their own.
- New **Settings** button with Music and Sounds on/off, saved per player (`Config.Data.Template.Settings`, a new field; nothing was removed).

### 2. Mobile pass
- New `src/client/Layout.luau` (`Config.UI`):
  - The UI scales up on big screens and never down, so phone text stays at least 14 px.
  - Panels shrink only when they don't fit.
  - On touch screens, panels along the bottom keep clear of the thumbstick and jump button.
- Shop, Codes, Invite and Settings share one side column: bottom-left on PC, top-left on phones and tablets (above the thumbstick).
- Phones get a compact shop. Admins get a touch "Admin" button, since there's no F8 on a phone.
- I couldn't drive Studio's device emulator. Instead I mounted the real UI into a 740×300 phone screen and a 1024×710 tablet screen and checked positions and screenshots.

### 3. Results screen
- The panel slides in with a bounce.
- MVP spotlight with the top collector's avatar headshot and a spinning glow.
- Survived! / Caught / MVP badges.
- Coins count up, with the coin sound on your own row.
- Your row is highlighted and scrolled into view even outside the top 10.
- "Next round in X" follows the server timer.
- Tune it in `Config.Results`.

### 4. Round juice
- "RUN!" banner when the King appears.
- A red heartbeat pulse at the screen edges, with a heartbeat sound, while a King within 45 studs is chasing you. The server now tags each King with `TargetUserId`.
- "+1" pop-ups on pickups.
- "Last 30 seconds!" warning and "X survivors left" when someone is caught.
- Tune it in `Config.Juice`.

### 5. Ghost haunt cam
- When you're caught, the camera circles the King (or the catch spot) for 2 s, then the normal ghost controls take over.
- Spectate now includes the Kings, and there's a **Watch King** button.
- Tune it in `Config.Ghost.HauntCam`.

### 6. Hub polish
- New `src/server/Hub/HubExtras.luau` (`Config.Hub.Polish`).
- Plaza 1.5× wider.
- Terrain grass with hills and mud. The Baseplate is hidden but still solid underneath.
- A dead-tree forest ring and a haunted mansion on a hill in the distance.
- A Pumpkin King statue, a pumpkin patch corner and extra graves.
- An iron fence with cobwebs and ground fog, plus more lanterns and candles.
- Glowing stepping stones from the spawn pad to every NPC.
- 808 → 1,488 parts, 66 → 79 lights. Still only one hub, and custom NPC models still swap in.

### 7. Cosmetics
| Item | Slot | Price | Id |
| --- | --- | --- | --- |
| Candy Corn Hat | Hat | 180 | `CandyCornHat` |
| Bat Bow | Hat | 220 | `BatBow` |
| Candy Swirl | Trail | 150 | `CandySwirlTrail` |
| Purple Fog | Trail | 280 | `PurpleFogTrail` |
| Mini Cauldron | Pet | 550 | `MiniCauldron` |
| Itsy Spider | Pet | VIP only | `SpiderPet` |

- All looks are built from Parts. Any of them can be replaced by a model named after its Id in `ReplicatedStorage.Custom.Cosmetics`.
- A trail called "Candy Corn" already existed, so the new one is "Candy Swirl".

### 8. Performance and safety
- **Leaks:** two full rounds left server and client instance counts exactly where they started.
- **Leave cleanup:** every per-player table on the server is cleared when a player leaves. One was missing in PumpkinService; added.
- **Remotes:** every remote validates its input and has a cooldown. I added light spam guards to GetShopState and Haunt.
- **Per-frame work:** HubAmbience now only animates candles and lights near the camera, and flickers at 20 Hz.
- **Bug fixed while testing:** floating candles were sliding sideways instead of bobbing, because they're rotated cylinders and the bob was applied in their local space. With streaming on, they could also be skipped entirely.

### 9. Final verify
Solo Studio playtest with the final code; Output was clean on server and client from the start.
- **Pass:**
  - spawn on the hub pad, one hub
  - all 6 NPC prompts (Witch → shop, Vendor → Packs & VIP, Boo tips, Voting Board, Gravestone, Photo Spot emotes)
  - a full round: vote → map → walk-in pumpkin pickup → King at 14 s → minions → caught → results → back to the hub
  - all 25 shop items equip and unequip; VIP-only items refused without VIP
  - skins restore the avatar exactly; a hat sits on a skin head piece
  - PUMPKIN works once, then "already used"; a wrong code is refused
  - daily toast after F8 > Reset daily and a rejoin
  - Invite is available
  - every F8 command
  - a custom model in `ReplicatedStorage.Custom` replaces the placeholder, and its script is stripped
- **Fixed during verify:** the Leaderboard Gravestone showed "Unknown" for a Studio local-server test player. Players with user id 0 or below are no longer saved to or shown on the board.
- **Not tested:** anything that needs 2 players (see Needs Kieran).

## Needs Kieran
- Save the place (Ctrl+S) after checking the new hub.
- Reconnect the Rojo plugin.
- Listen to every sound and swap any you don't like (`Config.Sounds`, `Config.Hub.Music`, `Config.Maps.List[i].AmbientSound`, `Config.King.Heard.RoarSoundId`, `Config.Juice.Heartbeat.SoundId`).
- **2-player test:** ghost modes and haunting with others still alive, 3D sounds heard by the other player, the friend bonus, voice routing.
- **Device emulator:** a phone and a tablet. Check the side buttons, shop and vote panel, and that Roblox's own Sprint/Shout/Track touch buttons don't sit on top of a panel.
- **Robux IDs** (still blocking M6): create the VIP pass and the 3 coin packs in Creator Hub and paste the IDs into `Config.Monetization`.
- **Speed hacks:** movement is client-side in Roblox, so a cheater can still raise their own walk speed. Pickups already reject impossible speeds; a server-side movement check is a good post-launch job.
- **Testing reset my Studio save.** That's your own test data: Coins, owned items and codes went back to a new player.

## The 5 best things to build before 20 October
1. **A 2-player and friends playtest pass with fixes.** Multiplayer is the heart of the game and hasn't been tested end to end yet: ghost modes, catching with survivors left, voice, the friend bonus.
2. **Monetisation go-live.** Create the VIP pass and coin pack IDs, publish, and make one real purchase in a live server. M6 can then be marked done.
3. **A short first-time tutorial.** Three Boo Guide pop-ups in the first round (collect pumpkins, sprint and shout make noise, hide from the King). Kids skip dialog, so show it in play.
4. **Real art for the King and one map.** One Creator Store or Blender Pumpkin King rig with walk/idle animations (`ReplicatedStorage.Custom.Characters.PumpkinKing`) and a hand-dressed Pumpkin Patch. Thumbnails and the first round sell the game.
5. **A launch-week event and a codes plan.** Use `/new-event` for a "Blood Moon" double-pumpkin weekend and post a code for YouTubers on launch day; the codes system and the daily streak are ready for it.
