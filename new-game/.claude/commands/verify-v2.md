---
description: Test every v2 feature in Roblox Studio (solo, then 2 players, then phones), fix what's broken, run the offline tests, commit and push.
---

Verify the v2 update in Roblox Studio. $ARGUMENTS

v2 was built and tested offline only (Lune tests and renders). This is its first real playtest. Work through the steps below **in order** and keep a pass/fail list as you go.

## Before you start
- Read `CLAUDE.md`, `docs/V2-CHANGES.md` (what v2 should do), `src/shared/Config/Features.luau` and `docs/PROGRESS.md`.
- Use the Roblox Studio MCP connection to start and stop playtests, run Luau in edit mode and in the running game, read the Output window, inspect the DataModel and take screenshots when you can. Don't guess what happened: read Output and inspect.
- I (Kieran) am a beginner. When a step needs my hands (Clients and Servers, Test > Device, Lighting, looking at something), tell me exactly what to click and what to look for, then wait for my answer.
- Fix rules: smallest correct fix, numbers stay in `src/shared/Config/`, `--!strict` stays, never `--!nocheck`. If the same error survives 3 attempts, stop and report it. Never create Robux products or passes, publish, or make the game public.
- Undo every temporary Config change you make for testing (they're marked "temporary" below) before you commit. Don't save the place in Studio unless I say so; anything made only in Studio is not in git.

## 0. Setup (edit mode)
1. From `new-game/`: `git status` (clean?), `git log -1 --oneline`, `lune --version` (0.10.2; if not, run `rokit install`).
2. Run `stylua --check src`, `selene src` and `lune run tests/run` (about 2 minutes, 1,100+ tests). Note the result as the baseline.
3. Rojo is connected: `ReplicatedStorage.Shared.Config` is a ModuleScript with children `Features`, `Modes`, `Lobby`, `Parkour`, `Minigames`, `EasterEggs`, `HideSeek`, `ScareMaze`, `Rarity`, `Crates`, `Menu`, `Maps`, `Skins`. `ServerStorage.Maps` exists. If not, ask me to restart `rojo serve` and reconnect.
4. `Lighting.Technology`: if it isn't `Future`, ask me to set it (Explorer > Lighting > Properties > Technology). Scripts can't.
5. `Workspace.Hub`: read its attributes `BuildVersion` and `Locked`, and compare with `Config.Hub.BuildVersion`. Tell me what you found. If it's older and not Locked, the game rebuilds it at Play; offer to bake the new one into the place (`require(game.ServerScriptService.Server.Tools.Bake).Hub()` in edit mode), but ask first and tell me to back up the old one (right-click `Workspace.Hub` > Save to File) if I edited it by hand.

## 1. Solo Play: start-up
1. Start a solo playtest (Play). Read Output from the very first line.
2. Not OK: anything red, `[Main] <name> failed to load/start/mount`, `[HubService] Building the hub failed`. Fix these first.
3. OK (yellow or white): `[CrateService] PolicyService didn't answer ... crates stay open in Studio only`, `[HubService]` notes about pieces put back or retired NPCs removed (note them).
4. In the running server check:
   - `Workspace.Hub` has `BuildVersion` = `Config.Hub.BuildVersion` (or is Locked) and children `Plaza`, `Spawn`, `Npcs`, `ReadyArea`, `Shop`, `CrateStand`, `Parkour`, `CandyRush`, `WebScour`, `EasterEggs`, `Decor`.
   - No `WitchWanda` or `BooGuide` anywhere in Workspace.
   - Tagged parts (CollectionService): `HubSpawn` 1, `ReadyPad` at least 1, `ShopKeeper` present, `ParkourCheckpoint` 3 (attributes `Index` 1-3), `ParkourStart` 1, `ParkourFinish` 1, `CandyRushPad` 2 or more (attribute `Lane`), `WebScourStart` 1, `WebScourSpot` 16, `EasterEgg` 11, `CrateDisplay` 10.
   - Part and light count of `Workspace.Hub` against `Config.Hub.Budget` (4,200 parts, 90 lights).
   - ReplicatedStorage attributes `ReadyCount`, `ReadyNeeded` exist.

## 2. Lobby and the Pumpkin Shop (solo)
- I spawn on the round "BOO!" stone, facing the pumpkin arch and the Ready circle.
- The Pumpkin Shop keeper is visible over the counter; its name tag shows above the awning. Its prompt opens the shop titled "Pumpkin Shop" on the Skins tab.
- Voting Board, Leaderboard Gravestone and Photo Spot prompts work; the board shows the vote.
- Signposts and paths lead to the Ready circle, Shop, Crates, Parkour, Candy Rush and Web Scour.
- No tutorial bubble or Boo Guide appears.

## 3. Top-left Menu (solo)
- The orange Menu button sits in Roblox's top bar, right of the Roblox and chat buttons. **M** opens and closes it.
- Tiles, in order: Skins, Shop, Crates, Vote, Invite, Codes, Settings, VIP & Packs, Parkour, Secret Pumpkins (Spectate only shows during a round you're not in). Each opens the right panel.
- Only one panel is open at a time; Escape closes it. **B** opens the shop. No loose buttons left on screen (except Roblox's own and the touch buttons).
- Menu > Codes: `PUMPKIN` works once, then says already used.

## 4. Shop, rarity prices and skins (solo)
- F8 > "+ Coins" (or "Crates: +100k coins"). Shop cards show rarity tags and prices: Common 125, Uncommon 500, Rare 1,000, CRAZY 100,000.
- Skins tab: pages, filters (owned, rarity, theme). Buy and wear one skin of each rarity. Check from the front and side: Common colours/patterns, Uncommon head piece, Rare glow + particles, CRAZY rainbow + orbiting pieces + pulsing glow.
- Unequip restores my avatar exactly. Reset my character: the skin comes back. A hat sits on top of a head piece.

## 5. Crates (solo)
- Menu > Crates lists 10 crates. The Pumpkin Crate preview shows all 20 skins with chances adding up to 100% (each Common 5.833%, each Uncommon 4.980%, each Rare 2.500%, the CRAZY 0.100%).
- Open one with coins: the strip spins and slows, the reveal shows the skin, coins go down by 300, the skin is owned. A duplicate refunds coins. "Equip now" / "Open another" / "Back" work.
- F8 > "Crates: open free Pumpkin Crate" works. The crate stand prompts in the lobby open the right crate. Robux buttons say "Coming soon" (all ProductIds are 0).
- Region rule (temporary): set `Config.Crates.Policy.TestAsRestricted = true`, Play: every crate refuses with the region message, the Shop still sells skins. Set it back to `false`.

## 6. Ready pad, vote and rounds (solo)
- Step on the Ready circle: the sign shows READY 1, my `Ready` attribute is true, `ReadyCount` is 1. Step off for more than 1 second: not ready.
- On the pad the vote opens (MinReady is 1). Solo, only King Hunt playlists are offered. Play a King Hunt round to the results; I end at the lobby spawn, not ready.
- F8 > "Pumpkin Hide & Seek: force next round", then step on the pad. Solo I'm a seeker (`Config.HideSeek.SoloRole`): I start in the seeker hut, the "Hiding" head start counts 15 s, the door swings open, the candy gun is equipped, a candy on a decoy is a miss with a splat. Press it again later to get the other Hide & Seek map.
- F8 > "ScareMaze: force next round": "Get ready" freezes me 5 s, then standing still 3 s puts me OUT (red 3-2-1 first); running to the green exit escapes. Camera zoom is limited in the maze and normal again in the lobby.
- All 5 maps load without warnings: Haunted Pumpkin Patch, Spooky Mansion, Pumpkin Farm, Hedge Maze, ScareMaze.
- F8 > "Start round now" is refused while a round is running.

## 7. Lobby features (solo)
- **Parkour:** F8 > "Parkour: teleport to start". The timer starts when I leave the START pad. Checkpoints 1/2/3 in order; falling or touching green slime sends me back to my checkpoint. The finish gives 100 coins and a best time on the board; a second finish says when coins come back. Menu > Parkour shows my best and "Go to start". F8 > "Parkour: reset my best/cooldown". Are the brooms and the two spicy jumps doable for a kid? Tell me.
- **Candy Rush:** stand alone on a pad for 6 s: a solo run starts. Click my candies; finishing pays 5 coins. F8 > "Candy Rush: start solo test" works too.
- **Web Scour:** the lantern's "Scour the Web!" starts a hunt: 6 critters, 45 s, clicking them works, coins on finishing. A second hunt within 3 minutes pays nothing but still counts.
- **Secret pumpkins:** walk behind the Pumpkin Shop: the egg gives +50 and a toast. Menu > Secret Pumpkins shows 1/11 and riddles for the rest. List every `EasterEgg` part's position and check none is inside a wall, under the ground or floating where nobody can reach it. F8 > "Easter eggs: reset mine" lets me find them again.

## 8. Two players (Test > Clients and Servers)
Ask me to click: Studio **Test** tab > **Clients and Servers** > set players to **2** > **Start**. Three windows open (Server, Player1, Player2). Read the server's Output. Tell me what to do in each player window.
- **Ready pad and voting:** Player1 on the pad, Player2 off. Only Player1 can vote; Player2 sees the "stand on the pad" hint. The round takes only Player1. Player2 stays in the lobby.
- **Spectating:** during that round, Player2 uses Menu > Spectate (or "Watch the round"): the camera follows Player1 (and the King); Q/E or the buttons switch; Stop returns. Player2 can play Candy Rush and Web Scour while the round runs.
- **Hide & Seek:** both on the pad, force Hide & Seek. One seeker, one hider. The hider becomes a pumpkin that looks like the decoys; no name tag, no chat bubble. The seeker leaves the hut after 15 s; giggles about every 20 s; the hider glows in the last 30 s. A candy on the hider shows TAGGED! and the hider becomes a seeker after 3 s. A hider who resets after the seekers are out comes back on the same pumpkin. Equipping a skin as a hider doesn't un-hide them. Results show the right rows and coins.
- **ScareMaze:** both on the pad, force ScareMaze. With 2 players both are Survivors (Haunters need `MinPlayersForHaunters` = 3). To test Haunters (temporary): set `Config.ScareMaze.MinPlayersForHaunters = 2`, or ask me for a 3-player test. Then: the Haunter starts in the middle; **E** (BOO) near a Survivor shows a jumpscare and slows them; BOO has an 8 s cooldown; the Haunter sees running Survivors through walls; scare traps jump out; an OUT Survivor becomes a Haunter after 2 s; a catch is credited; results show Team and badges. Put the setting back.
- **Candy Rush race:** both on pads: 3-2-1, GO, each clicks only their own lane's candies, the first to 10 wins 25 coins, the other gets 5. Step off mid-race; check the rematch.
- **Web Scour together:** both hunt at once; each sees only their own critters.
- After each round both players are back at the lobby spawn and not ready.

## 9. Phones and tablets (Test > Device)
Ask me to pick a phone in **Test > Device** (e.g. iPhone 14 or a small Android, landscape), then a tablet (iPad), and press Play. Take screenshots if the MCP can, otherwise ask me.
- The Menu button is visible in the top bar; the tile grid fits; text is never tiny (`Config.UI.MinTextSize` 14).
- Shop: the first row's Buy / Equip buttons are fully visible. Crate preview: Open / Robux / Back are visible. Crate reveal: its buttons aren't cut off. Results: full size, the list scrolls. Secret Pumpkins: the list scrolls. Vote panel: fits between the thumbstick and the jump button. Spectate bar: two rows.
- Banners (Candy Rush countdown, Hide & Seek, ScareMaze team, egg toast) sit below the top bar and Hud; parkour messages don't cover the parkour timer.
- Touch: tap candies (Candy Rush), tap critters (Web Scour), tap to throw candy (Hide & Seek), the BOO button sits above the jump button (ScareMaze), prompts work by tap. The Admin button (top right) replaces F8.

## 10. Feature switches (quick, temporary)
One at a time, set to `false` in `Features.luau`, Play, check there are no errors and the feature is gone, then set it back to `true`:
- `Parkour`, `CandyRush`, `Crates`: the area leaves the running game and its Menu tile hides.
- `Menu`: the old column of Shop / Codes / Invite / Settings buttons comes back.
- `ReadyPad`: everyone in the lobby plays the next round.

## 11. Output review
Scroll the whole server and client Output once more. List every warning that is left, with its cause, and whether it needs fixing.

## 12. Fix, test, commit, push
1. Fix each failure. Add or update a spec in `tests/specs/` when the logic is testable.
2. Run `stylua src`, `selene src` and `lune run tests/run` from `new-game/`: all must pass.
3. Re-test the fixed items in Studio.
4. Check `git diff` has no leftover temporary Config changes.
5. Update `docs/PROGRESS.md` (the v2 table: set each feature's status to `verified in Studio`, or note what failed) and add a short pass/fail note.
6. Commit "v2 verify: <short summary>" and push to the current branch only (never force-push).
7. Report to me: a table of every feature with pass / fixed / fail, what you fixed, and what still needs me (Robux ids, publishing, a friends test, art).

## F8 admin buttons (Studio playtests; phones: the Admin button at the top right)
| Button | What it does |
| --- | --- |
| + Coins | +1,000 coins (`Config.Admin.CoinsPerClick`) |
| Unlock all items | Owns every shop item (VIP-only items still need VIP) |
| Reset daily reward | Rejoin to see the daily toast again |
| Rebuild hub | A fresh lobby from Config (this playtest only) |
| Repaint hub | Every part takes its `Config.Hub.Palette` colour again |
| Reset my save | Back to a new player (asks twice; purchase receipts are kept) |
| Start round now | Skips the wait, vote and Ready pad |
| Force mode | Cycles the next round's playlist (Studio only) |
| King Hunt: force next round / Pumpkin Hide & Seek: force next round / ScareMaze: force next round | Next round plays that mode, any player count (Studio only) |
| Parkour: teleport to start | Puts you on the START pad |
| Parkour: reset my best/cooldown | Clears your best time and coin wait |
| Candy Rush: start solo test | A solo race right away |
| Web Scour: start | Puts you at the lantern and starts a hunt |
| Easter eggs: reset mine | Lets you find every egg again |
| Crates: open free Pumpkin Crate | Opens `Config.Crates.Admin.FreeCrate` without paying |
| Crates: +100k coins | +100,000 coins |
