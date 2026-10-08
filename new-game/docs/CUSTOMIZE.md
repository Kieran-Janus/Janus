# Customise everything

The game is built so you can change almost anything without touching code. There are three layers:

| Layer | What it controls | Where | How hard |
| --- | --- | --- | --- |
| **1. Config** | Every number, name, price, colour, dialogue line, code, reward | `src/shared/Config/` (`init.luau` plus one file per v2 feature) | Edit text, save. Rojo syncs it live. |
| **2. Custom models** | How every character, NPC, hat, pet, skin and decoration *looks* (one model swaps every copy) | Studio: `ReplicatedStorage > Custom` | Build or import a model, give it the right name. |
| **3. Code** | New behaviour (a new monster, mode, item type) | `src/` | Ask Claude Code with a slash command (bottom of this page). |

Test anything fast in a Studio playtest with **F8** (admin panel; phones get an Admin button at the top right): + Coins, Unlock all items, Reset daily reward, **Rebuild hub**, **Repaint hub**, **Apply custom props**, Reset my save, Start round now, Force mode, plus buttons the v2 features add (parkour, Candy Rush, Web Scour, Easter eggs, crates). It only works in Studio unless you turn it on for live servers (`Config.Admin`).

Every v2 feature has an on/off switch in `src/shared/Config/Features.luau`. New to v2? Start with [`docs/V2-CHANGES.md`](V2-CHANGES.md).

Want to change a skin's colours, give it a new head piece, or make its wings flap and its walk spooky? See [Change and animate skins](#change-and-animate-skins) (three ways, step by step).

Want every pumpkin (or lantern, tree, gravestone...) to be **your** model, everywhere at once? See [Swap every copy of something at once](#swap-every-copy-of-something-at-once).

Want to move, recolour or rebuild the lobby or a map **by hand** in Studio? See [Editing the lobby and maps by hand](#editing-the-lobby-and-maps-by-hand).

Too much movement, or a phone feels slow? Every animation switch is in one list: [Turn animations off or down](#turn-animations-off-or-down).

Jump to: [Animations](#turn-animations-off-or-down) · [Change and animate skins](#change-and-animate-skins) · [Skin Studio](#skin-studio) · [Skins](#crate-skins-add-or-change-a-skin) · [Crates](#crates) · [Modes and playlists](#modes-and-playlists) · [Maps](#maps) · [Ready pad](#the-ready-pad) · [Parkour](#parkour-jumps) · [Candy Rush](#candy-rush) · [Web Scour](#web-scour) · [Dances](#photo-spot-dances) · [Floor signs](#floor-signs) · [Solid lobby](#a-solid-lobby) · [Tormented Tower](#tormented-tower) · [Secret pumpkins](#secret-pumpkins-easter-eggs) · [Menu](#menu-tiles) · [Lobby zones](#lobby-areas-zones) · [Swap every copy](#swap-every-copy-of-something-at-once) · [Toolbox codes](#with-a-toolbox-code-one-line-no-dragging) · [Move one thing](#move-just-one-thing) · [Tags](#parts-that-do-something-tags)

---

## Quick "I want to change..." table

| I want to change... | Edit |
| --- | --- |
| Game name on the HUD | `Config.Game.Name` (the Roblox page name is set in Creator Hub) |
| Round length, intermission, results time | `Config.Round` |
| Results screen timings, text, colours, motion (row pops, shine, "You got X coins!"; `Animate = false` = no motion) | `Config.Results` |
| 3-2-1 countdown, "GO!", "RUN!", heartbeat warning, +1 pop-ups, last-30-seconds, survivors-left (`Animate = false` = no motion) | `Config.Juice` |
| Vote panel text and motion (cards popping in, count ticks, winner pop; `Animate = false` = no motion) | `Config.Voting` |
| Coins per pumpkin, survivor bonus | `Config.Rewards` |
| Easy/Hard pumpkins, reward multiplier | `Config.Difficulty.Levels` |
| King speed, hearing, sight, how many Kings | `Config.King.Difficulty` |
| How loud sprinting/shouting/talking is to the King | `Config.King.Noise`, `Config.Voice.Noise` |
| Skeletons, bats, ghost cats (count, speed, damage, messages) | `Config.Monsters` |
| Player walk/sprint speed | `Config.Player` |
| Ghost mode rules (fly speed, haunt) | `Config.Ghost` |
| Voice range and echo | `Config.Voice` |
| Turn any v2 feature on or off | `src/shared/Config/Features.luau` (one `true`/`false` line each) |
| How hard the lobby and map animations work on phones (how far candles animate, flicker rate, how often they look for something nearby) | `Config.Performance` (the `Phone...` lines are for small touch screens; `tests/specs/perf.spec.luau` checks idle work stays near zero). See [Turn animations off or down](#turn-animations-off-or-down) |
| UI animation: panels popping in and out, buttons squashing, the Menu's tiles, the Menu button's wobble, coins rolling | `Config.UI.Motion` (`On = false` = everything instant) |
| Animations on the Hide & Seek, ScareMaze (BOO cooldown ring), jumpscare, ghost, spectate, daily reward, NPC dialogue, announcement and Voting Board screens | `Config.ScreenMotion` (`src/shared/Config/ScreenMotion.luau`; `On = false` = instant) |
| Shop animations: hover lift, turning previews, rare shine, purchase pop and sparkles, "Need N more Coins", "Wearing it!" | `Config.Shop.Juice` (`Animate = false` = none) |
| How big the skin pictures are in the Shop | `Config.Shop.PreviewDistance`, `Config.Shop.PhonePreviewDistance` (phones; smaller = bigger) |
| The floating READY sign hiding while you stand right under it | `Config.Hub.ReadyArea.Sign.HideNear` (studs; `0` = always shown) |
| Hub layout, lighting, music, decorations | `Config.Hub` (then F8 > Rebuild hub to try it, and raise `Config.Hub.BuildVersion` so saved hubs update) |
| Hub colours | `Config.Hub.Palette` (the `hubPalette` list at the top of `Config/init.luau`) |
| Where the Ready pad, shop, crate stand, minigames and parkour go | `Config.Lobby.Zones` (`src/shared/Config/Lobby.luau`) |
| Ready pad rules: players needed, who can vote, words | `Config.Lobby.Ready` (`src/shared/Config/Lobby.luau`) |
| Ready pad look and sign text | `Config.Hub.ReadyArea` |
| Watching the round from the lobby | `Config.Lobby.Spectate` |
| Hub terrain, forest, mansion, statue, fence, glowing paths | `Config.Hub.Polish` (same rebuild) |
| NPC names, positions, dialogue | `Config.Npcs.List` |
| Shop items (hats, trails, pets, classic skins) | `Config.Shop.Items` |
| Crate skins (about 630, 30 themes) | `src/shared/Config/Skins/<Theme>.luau` (see "Crate skins" below) |
| A skin's look, moving pieces and walk style | Skin Studio in a playtest, its theme file, or your own model: [Change and animate skins](#change-and-animate-skins) |
| Prices by rarity (Common, Uncommon, Rare, CRAZY), duplicate refunds | `Config.Rarity` (`src/shared/Config/Rarity.luau`) |
| VIP perks, VIP pass, coin packs | `Config.Monetization` (IDs from Creator Hub) |
| Crates: prices, odds, Robux products, the crate stand, words | `Config.Crates` (`src/shared/Config/Crates.luau`, see "Crates" below) |
| Codes for YouTubers | `Config.Codes.List` |
| Daily streak rewards | `Config.Daily.Rewards` |
| Friend/group bonus, invite button, favourite prompt | `Config.Social` |
| Game modes, which mode + map pairs the vote offers | `Config.Modes` (`src/shared/Config/Modes.luau`) |
| Hide & Seek rules, candy gun, coins | `Config.HideSeek` (`src/shared/Config/HideSeek.luau`) |
| ScareMaze rules, BOO, scares, coins | `Config.ScareMaze` (`src/shared/Config/ScareMaze.luau`) |
| Map size, lighting, ambient sound, layout | the map's file, `src/shared/Config/Maps/<Id>.luau` |
| Parkour course, coins, times | `Config.Parkour` (`src/shared/Config/Parkour.luau`) |
| Candy Rush | `src/shared/Config/CandyRush.luau` |
| Web Scour | `src/shared/Config/WebScour.luau` |
| Tormented Tower (the hard climb inside the clock tower) | `Config.TowerParkour` (`src/shared/Config/TowerParkour.luau`) |
| Server-wide announcement banners | `Config.Announce` (`src/shared/Config/Announce.luau`) |
| Photo Spot dances | `Config.Dances` (`src/shared/Config/Dances.luau`, see "Photo Spot dances" below) |
| Glowing floor signs in front of each lobby area | `Config.Lobby.FloorSigns` (`src/shared/Config/Lobby.luau`) |
| Lobby life: the shopkeeper breathes, turns and waves, the Ready pad pulses, floor signs shimmer, the cauldron bubbles, bats fly by (each with its own switch) | `Config.Lobby.Life` (`src/shared/Config/Lobby.luau`, client `src/client/LobbyLife.luau`) |
| Map life: King Hunt pumpkins bob, spin, glow and pop with sparkles when collected; fireflies drift on the round map (a colour per map, fewer on phones); Hide & Seek decoys and hiders' pumpkins wobble now and then, exactly alike (each with its own switch; only on each player's screen, the real pumpkins never move) | `Config.MapLife` (`src/shared/Config/MapLife.luau`, client `src/client/MapLife.luau`), whole feature `Config.Features.MapLife` |
| What in the lobby is solid | `Config.Lobby.Solid` (`src/shared/Config/Lobby.luau`, see "A solid lobby" below) |
| Secret pumpkins (Easter eggs) | `src/shared/Config/EasterEggs.luau` |
| Minigame celebrations (sparkles, "+1", confetti, fireworks, NEW BEST!) in Candy Rush, Web Scour, secret pumpkins and both parkour courses | one switch for all: `Config.Minigames.Effects.On` (`src/shared/Config/Minigames.luau`, also the phone share and shared sizes); each game's own `Effects` table (`CandyRush.luau`, `WebScour.luau`, `EasterEggs.luau`, `Parkour.luau`) |
| Sound effects (clicks, pickups, King footsteps, minions, rewards) | `Config.Sounds` (SoundId "" = silent) |
| Hub music, King roar | `Config.Hub.Music`, `Config.King.Heard.RoarSoundId` |
| UI colours and font | `src/client/Theme.luau` |
| UI size on big screens, phone layout | `Config.UI` |
| Top-left Menu: its button, tile order, words, icons, colours | `Config.Menu` (`src/shared/Config/Menu.luau`) |
| Character/NPC/hat/pet/skin looks | A model in `ReplicatedStorage > Custom` (below) |
| A whole map | A model in `ServerStorage > Maps` (below) |
| Every copy of a pumpkin, lantern, tree, gravestone... at once (lobby AND maps) | A model in `ReplicatedStorage > Custom > Props`: [Swap every copy of something at once](#swap-every-copy-of-something-at-once) |

Colours in Config are `Color3.fromRGB(red, green, blue)`, each 0-255. Pick them in any colour picker.
Sounds are `"rbxassetid://NUMBER"` from the Creator Store (Toolbox > Audio). Empty `""` means no sound.

---

## Turn animations off or down
Every animation in the game is only a look on each player's own screen. Buttons, votes, coins and prizes happen straight away whether the animation plays or not, so switching one off never breaks anything. Change `true` to `false` on the line, save, press Play.

| What moves | Switch it off | Turn it down instead |
| --- | --- | --- |
| Panels popping in and out, buttons squashing, the Menu's tiles and its button's wobble, coins rolling | `Config.UI.Motion.On = false` (`src/shared/Config/init.luau` > `UI` > `Motion`). This also stops everything in the next row. | the `...Seconds` and `...Scale` numbers in the same block |
| Hide & Seek and ScareMaze banners, the BOO cooldown ring, the jumpscare zoom, the ghost panel and spectate bar, daily reward and code toasts, NPC text typing out, stacked announcements, the Voting Board | `Config.ScreenMotion.On = false` (`src/shared/Config/ScreenMotion.luau`) | `PhoneShare` (less sparkle and confetti on phones), each screen's own block |
| The vote panel (cards pop in, your pick bounces, counts tick up, the winner pops) | `Config.Voting.Animate = false` | `Config.Voting.Motion` |
| Round moments (3-2-1, GO!, RUN!, banners punching in, "+1" pop-ups) | `Config.Juice.Animate = false` (the same messages show, just still) | `Config.Juice.Motion`, `Config.Juice.Countdown` |
| The results screen (rows growing in, shine, coins counting, "You got X coins!") | `Config.Results.Animate = false` | `RowInSeconds`, `ShineSeconds`, `CountUpSeconds` in `Config.Results` |
| The Shop (hover lift, turning previews, rare shine, purchase sparkles, coin roll) | `Config.Shop.Juice.Animate = false` | `SpinSpeed = 0` (still previews), `PhoneSparkles` |
| Minigame celebrations (Candy Rush, Web Scour, secret pumpkins, both parkour courses) | `Config.Minigames.Effects.On = false` for all of them (`src/shared/Config/Minigames.luau`), or one game's own `Effects.On` | `PhoneShare` |
| The lobby comes alive (shopkeeper, Ready ring, floor signs, cauldron, bats) | `Config.Lobby.Life.On = false` (`src/shared/Config/Lobby.luau`), or one part: `Keeper.On`, `ReadyPad.On`, `FloorSigns.On`, `Cauldron.On`, `Bats.On` | `Range`, `PhoneRange` |
| Round maps come alive (bobbing pumpkins, fireflies, wobbling Hide & Seek pumpkins) | `Config.Features.MapLife = false` (`src/shared/Config/Features.luau`), or one part in `src/shared/Config/MapLife.luau`: `Pickups.On`, `Ambient.On`, `Wobble.On` | `Range`, `PhoneRange`, `Ambient.PhoneCount` |
| The crate stand (crates bob, sway, peek their lids, wake up when you walk close) | `Config.Crates.Idle.On = false` (`src/shared/Config/Crates.luau`; the crates then just float gently by `Stand.Bob`, `0` = still) | `Idle.Range`, `Idle.PhoneRange`, `Idle.PhoneSparkleShare`, `LookDefaults.PeekEvery = 0` (no lid peeks) |
| Crate openings (chest drop, shake, light beam, pedestal) | Players can tick **Quick open** on the crate page (`QuickOpen.Default = true` starts it ticked), or `Opening.Style = "Reel"` for the old spinning strip | `Opening.ShakeSeconds`, `Opening.Beam` (`PhoneShafts`, `FlashSeconds = 0` = no flash), `PhoneConfetti`, `PhoneCoinPour`; crate cards: `Cards.SpinSpeed = 0`, `Cards.Halo = false` |
| CRAZY skins' rainbow, orbiting pieces and glow | `Config.Features.SkinEffects = false` | `Effects.MaxAnimated` in `src/shared/Config/Skins/Settings.luau` |
| Skin pieces that move or change colour (flapping wings, wagging tails, colour fades, sparkle bursts: a skin's `Animate`) | `Config.Features.SkinAnimations = false` | `MaxCharacters` / `PhoneMaxCharacters`, `MaxDistance`, `MaxColorWrites` in `src/shared/Config/SkinAnimate.luau` |
| Walk styles (Zombie, Ghost, Robot... a skin's `Motion`) | `Config.Features.WalkStyles = false` | `MaxCharacters` / `PhoneMaxCharacters`, `MaxDistance` in `src/shared/Config/SkinMotion.luau` |
| Floating candles and flickering lights, and how often the lobby, map and crate animations look for something nearby | (no off switch) | `Config.Performance`: `AmbienceDistance`, `FlickerHz`, `IdleScanHz` and their `Phone...` versions |

Phones already get less: shorter ranges, fewer sparkles, no turning Shop previews. While nothing near the camera is moving, these animations do almost no work (`Config.Performance.IdleScanHz`), and a panel's animation only runs while it is open.

---

## Builder mode: give a character your own look

Every character has a placeholder made from Parts. Put a model with the **exact name** below into `ReplicatedStorage > Custom > Characters` and the game uses it instead.

| Name the model | Replaces | Scaled to (studs tall) |
| --- | --- | --- |
| `PumpkinKing` | The Pumpkin King (boss) | 10 |
| `SkeletonPatrol` | Skeleton minion | 6.2 |
| `Bat` | One bat in a swarm | 1.4 |
| `GhostCat` | Ghost Cat minion | 3 |
| `PumpkinVendor` | The Pumpkin Shop keeper (the person only; the stall stays and they stand behind the counter) | 7.5 |

Sizes are in `Config.Custom.Heights` (only the parts you can see are measured). To keep the size you built, add an attribute to the model: **KeepSize** (boolean) = true.

The shopkeeper is checked before it is used, so the shop never ends up empty: it must have parts you can see, be about the right height (half to one and a half times its `Config.Custom.Heights` size) and stand tall enough to be seen over the counter. If it fails, the built keeper stays and the Output window says why.

### Step by step in Studio
1. **Get or build the model.** Any of these work:
   - **Build it**: Model tab > Part, then resize, colour and group (Ctrl+G) the parts into a Model.
   - **Toolbox**: View > Toolbox > Creator Store, search e.g. "pumpkin king" and insert one. Scripts inside are removed automatically for safety, but check the licence.
   - **A proper animated rig**: Avatar tab > Rig Builder > R15, then dress it with accessories or your own MeshParts. For the King, a rig with a Humanoid and HumanoidRootPart walks with real walk and idle animations.
   - **AI or Blender mesh**: generate it with Roblox Assistant / Cube, Meshy or Tripo, or make it in Blender. Import it with Avatar > Import 3D (or File > Import 3D).
2. **Face it the right way.** The front of the character must face the model's front. Select the model, then in the Model tab use **Pivot > Edit Pivot** and check the front arrow points where the face is. If it walks backwards in game, rotate the model 180° and try again.
3. **Name it** exactly as in the table, e.g. `PumpkinKing`.
4. **Move it** into `ReplicatedStorage > Custom > Characters` in the Explorer (drag and drop).
5. **Save** the place (Ctrl+S).
6. **Test**: press Play. NPCs swap immediately (or use F8 > Rebuild hub). The King and minions use the new look the next round.

**Keep it in git too (recommended):** right-click the model > **Save to File...** and save it as `new-game/assets/Characters/PumpkinKing.rbxm`. Commit it. Now it survives even if the place file is lost, and the laptop gets it with `git pull`.

Notes:
- Custom minions and NPCs are posed as one rigid model (no swinging limbs). For a lively look, add bobbing or glowing parts. The King can be a fully animated rig.
- Board, gravestone and photo spot NPCs keep their built look, because the game draws text on them.
- **Put characters in `Custom > Characters`, not by hand into Workspace > Hub.** The game places them for you, also in a hand-edited lobby.
- **Move an NPC**: change its `Offset` in `Config.Npcs.List` (the shop follows `Config.Lobby.Zones.Shop`), then F8 > Rebuild hub. In a hand-edited (Locked) lobby, just drag the NPC's model in Studio: the shopkeeper moves with its stall.

---

## Swap every copy of something at once

Want every pumpkin in the game to be **your** pumpkin? You don't have to click on each one. Make **one** model, give it the right name, drop it in one folder, and every copy changes: in the lobby, in all five round maps, and the pumpkins players pick up or hide in.

### Step by step
1. **Get a model.** Any of these:
   - **Creator Store**: View > **Toolbox** > Creator Store, search e.g. "pumpkin", click one to insert it. (Scripts inside are removed automatically, so free models are safe.)
   - **Studio's AI**: open the **Assistant** and ask it to generate a 3D model, e.g. "a cute carved pumpkin with a glowing face". Insert the one you like.
   - **Blender** (or any 3D app): export a `.fbx` or `.obj`, then in Studio **File > Import 3D**.
   - **Build it** from Parts (Model tab > Part), colour and resize them.
2. **Make it one Model.** Select everything that belongs to it in the Explorer and press **Ctrl+G** (a single MeshPart: also Ctrl+G). It must be a **Model**.
3. **Name it exactly** like one of the names in the table below, e.g. `Pumpkin` or `JackOLantern` (capitals matter, no spaces).
4. **Move it** into **ReplicatedStorage > Custom > Props** in the Explorer (drag and drop).
5. **Press Play.** Every copy uses your model. Save the place (Ctrl+S).

Good to know:
- **Size is automatic.** Each copy is scaled to the height of the thing it replaces (a small pumpkin stays small, a big one stays big), so any size of model works. To keep the size you built it at, add the attribute **KeepSize** (boolean, ticked) to your model.
- **Facing**: the model's front is the front of its pivot (Model tab > **Pivot > Edit Pivot**, look at the arrow). Turned the wrong way? Rotate your model and try again.
- **Lights**: a jack-o'-lantern, lantern, lamppost or candle with no light inside gets the glow light the built one had, so the maps don't go dark (switch: `Config.Custom.PropLights`). Jack-o'-lanterns that are built without a light (most of the lobby's: their faces glow by themselves) stay without one, so the lobby keeps within its phone light budget; `EveryJackOLantern = true` lights them all, but phones get slower. A light *inside* your model (many Toolbox jack-o'-lanterns have one) is switched off where the built thing has none, for the same reason; `ModelLights = true` keeps them all on.
- **Decorations stay walk-through.** Store models are usually solid. Where the built thing is just decoration you walk through (the Pumpkin Patch field pumpkins, cobwebs, candles, crows, flowers, mushrooms, bats...), your model is too: nobody bumps into it, the King sees through it, and candy flies through it.
- **Gameplay pieces keep working with any model.** For `CollectPumpkin`, `HidingPumpkin`, `ParkourPumpkin` and `Haystack` your model is only the *look*: an invisible part still does the job (the pickup you touch, the hitbox candy hits, the lid you land on, the spot that hides you from the King).
- **Not sure what something is called?** Select it in Studio (in a playtest, or a baked lobby/map) and look at its **PropName** attribute (Properties > Attributes).
- Take your model out of the folder and the built look comes back next time you press Play (in a lobby or map saved in your place, use Revert: see below).

### With a Toolbox code (one line, no dragging)
Every free model in the Toolbox (Creator Store) has a code: the number in its link, e.g. `https://create.roblox.com/store/asset/11600489662/Pumpkin` has the code `11600489662`. In the Toolbox, right-click a model > **Copy Asset ID** to get it.
1. Stop the game (edit mode). Open **View > Command Bar**.
2. **Every copy** of a prop gets that look (here: every lobby pumpkin):
   `require(game.ServerScriptService.Server.Tools.Swap).Toolbox("Pumpkin", 11600489662)`
   Several names at once: `.Toolbox({ "Pumpkin", "ParkourPumpkin" }, 11600489662)`. You can paste the whole link instead of the number.
   It downloads the model (scripts removed), puts it in `ReplicatedStorage > Custom > Props` under that name, and swaps every copy in the lobby and baked maps (the Output window says how many). Round maps built from code use it by themselves.
3. **Only one thing** (or a few): click it in the viewport (Ctrl+click for more), then run
   `require(game.ServerScriptService.Server.Tools.Swap).Selected(11600489662)`
   Only what you selected changes; every other copy stays as it is. It remembers its own look (attribute `CustomModel`, the model is kept as `Custom > Props > Pumpkin_11600489662`), so a later `.Toolbox(...)` or `.Props()` for every pumpkin leaves it alone. Clicking a parkour pumpkin changes only its look: the lid you land on keeps working. If what you clicked holds several things (the parkour START with its arch and lanterns), the Output window lists them: **Alt+click** the one you want and run it again.
4. Save the place (**Ctrl+S**). **Ctrl+Z** undoes it.

- Run `.Toolbox` again with another code to change your mind: the model you had is kept in `ServerStorage > CustomBackups`.
- Normal look back for **every copy**: delete the model from `Custom > Props` and run `require(game.ServerScriptService.Server.Tools.Swap).Props({ Revert = true })`. For **one thing**: delete its `Pumpkin_<code>` model from `Custom > Props`, then the same Revert line.
- Pumpkins have several names: lobby pumpkins `Pumpkin`, carved ones `JackOLantern`, parkour pumpkins `ParkourPumpkin`, King Hunt pickups `CollectPumpkin`, Hide & Seek pumpkins `HidingPumpkin`. Use the list for "all pumpkins".
- **Tools** (a torch, a sword: things you would hold) become a plain model: nobody can pick them up from the lobby.
- **Packs**: a Toolbox code that is a pack (a folder of 7 different trees, 2 mushrooms...) is spread over the copies: the 1st copy gets the 1st model, the 2nd the 2nd, and so on, so every kind is used.
- **Facing the wrong way?** Some Toolbox models are built back to front. Select the model in `Custom > Props`, turn its pivot round (Model tab > Pivot > Edit Pivot, rotate 180), then run `require(game.ServerScriptService.Server.Tools.Swap).Props()`.
- **One secret pumpkin (Easter egg)**: `require(game.ServerScriptService.Server.Tools.Swap).Egg("ForestGhost", 15145049241)`; the egg Ids are in `Config.EasterEggs.List` (Name "Lost Forest Ghost" = Id `ForestGhost`).
- Or just tell Claude Code the code and what it should replace ("make every lobby pumpkin 11600489662", "make the pumpkin by the shop 11600489662").
- It only works in Studio's command bar while the game is stopped (a running game can't download free models).

### Every name you can use
Sizes are studs tall (each copy is scaled to its own size, so this is just a guide).

| Name | What it is | Where it appears | Size |
| --- | --- | --- | --- |
| `Pumpkin` | a plain pumpkin (decoration) | lobby (pumpkin patch, piles, shop shelf, signposts, the Ready arch), Pumpkin Patch field, ScareMaze dead ends, Pumpkin Farm carts | 1-4 |
| `JackOLantern` | a carved, glowing pumpkin | lobby (ring round the plaza, arches, stalls, scarecrow head, parkour, crate stand), Pumpkin Patch, Spooky Mansion, ScareMaze | 1.6-4.3 |
| `CollectPumpkin` | the pumpkins you pick up in King Hunt (look only: the glowing pickup still works) | every King Hunt round | 2.5 (`Config.Pumpkins.Size`) |
| `HidingPumpkin` | Hide & Seek decoys **and** the pumpkins hiders turn into, so they always match (look only: a hidden hitbox is what candy hits) | Pumpkin Farm, Hedge Maze | 2.7-3.9 |
| `ParkourPumpkin` | the pumpkins you jump on (look only: the flat lid you land on stays, invisible) | lobby parkour | 4.5-5.5 |
| `ParkourTrophy` | the golden trophy pumpkin at the top | lobby parkour | 12 |
| `EggGoldenPumpkin`, `EggCandy`, `EggLollipop`, `EggSkull`, `EggGhost` | the secret pumpkins (Easter eggs) | lobby | 1.6 (`Config.EasterEggs.Size`) |
| `Lantern` | a small glass lantern | lobby (clock tower, shop, dead trees), ScareMaze corn walls (the bracket stays) | 1.3-1.7 |
| `Lamppost` | a lamp on a post | lobby and every map | 9-14 |
| `Candle` | a candle | lobby (floating candles, Ready arch), Spooky Mansion, Pumpkin Patch mausoleum | 0.8-2.8 |
| `SpookyTree` | a tree with puffy dark leaves | lobby | 17-28 |
| `DeadTree` | a bare, twisted tree | lobby, Pumpkin Patch, ScareMaze | 13-28 |
| `AutumnTree` | an orange autumn tree | Pumpkin Farm | 11-18 |
| `SpiderGroveTree` | the Spider Grove's crooked trees | lobby (Web Scour) | 15-22 |
| `CornStalk` | one corn plant | Pumpkin Farm corn patch | 8-10.5 |
| `Mushroom` | glowing toadstools | lobby | 1-2.2 |
| `Flowers` | a patch of flowers | Hedge Maze | 1.1 |
| `HedgePost` | the round leafy post where hedges meet | Hedge Maze | 12.6 |
| `Topiary` | a clipped bush shape | Hedge Maze | 6 |
| `Gravestone` | a tombstone | lobby graveyard, Pumpkin Patch graveyard | 3-5 |
| `Coffin` | a coffin | Spooky Mansion crypt | 2 |
| `FencePost` | a fence post | lobby fence, Pumpkin Patch graveyard | 4.5-5.4 |
| `Scarecrow` | a scarecrow | lobby pumpkin patch, Pumpkin Patch, Pumpkin Farm | 10-12.6 |
| `HayBale` | a rectangular hay bale | Pumpkin Patch, Pumpkin Farm, ScareMaze | 2.4-2.6 |
| `HayRoll` | a round roll of hay | lobby, Pumpkin Farm | 2-4.6 |
| `Haystack` | a walk-in haystack that hides you from the King (look only: the hiding spot stays) | Pumpkin Patch | 7-10.5 |
| `Crow` | a crow on the corn | ScareMaze | 1.4 |
| `Bat` | a little bat | lobby (round the moon, over the parkour) | 1-2.2 |
| `Cobweb` | a spider web (size = across) | lobby, Pumpkin Patch, Spooky Mansion | 2.8-5 |
| `Cauldron` | a bubbling cauldron | lobby centre, Spooky Mansion kitchen | 4-12 |
| `Bench` | a bench | lobby, Hedge Maze | 3.2-3.6 |
| `Crate`, `Barrel` | a wooden crate, a barrel | lobby | 1.6-3 |
| `Signpost` | a signpost (yours has no arrow words) | lobby | 7-13.5 |
| `Wheelbarrow`, `HarvestCart`, `Well`, `Tractor`, `RockingChair` | farm things | Pumpkin Farm | 3-9 |
| `Fountain` | the fountain | Hedge Maze | 9 |
| `ClockTower`, `KingStatue` | the big lobby centrepieces (the clock tower is hollow: the Tormented Tower climbs inside, see below) | lobby | 81.5, 18 |
| `VendorStall` | the Pumpkin Shop stall (the shopkeeper is `PumpkinVendor` in `Custom > Characters`) | lobby | 21 |
| `ReadyPadArch`, `ParkourArch` | the arch over the Ready circle, the parkour start arch | lobby | 15.4, 13 |
| `CandyCane`, `GiantLollipop`, `CandyBucket`, `Gumdrop`, `SignCandyCorn` | the Candy Rush stand's decorations | lobby | 1.2-24 |
| `CandyRushWrapped`, `CandyRushLollipop`, `CandyRushCandyCorn` | the candies you click in Candy Rush | lobby, during a race | 2.4 (`Config.CandyRush`) |
| `GroveSpider` | the friendly spider in the Spider Grove | lobby | 8 |
| a crate's Id, e.g. `PumpkinCrate` | that crate on the crate stand and in the crate panel | lobby, Menu > Crates | 3-3.6 (its longest side) |
| `ScareScarecrow`, `ScareZombie`, `ScareBat`, `ScareGhost` | the ScareMaze scares | ScareMaze | 9, 6, 1.4, 6 |

Can't be swapped this way: things that come in every length (the long hedge and corn walls, fence rails, bunting, paths), and anything with words drawn on it by the game (the boards). Characters (the King, minions, the shopkeeper) go in `Custom > Characters` and hats, pets and skins in `Custom > Cosmetics` ([Builder mode](#builder-mode-give-a-character-your-own-look)).

### A saved (Locked) lobby or a baked map
When you press Play the swap happens by itself, also in a lobby you edited by hand (Locked) and in maps baked into `ServerStorage > Maps`. To see your models in **edit mode** and keep them in the place file:
1. Stop the game. Open **View > Command Bar**.
2. Paste this and press Enter: `require(game.ServerScriptService.Server.Tools.Swap).Props()`
   Every prop in `Workspace` (the lobby too) and `ServerStorage > Maps` becomes your model. The Output window says what it swapped, e.g. `Swapped JackOLantern x29, Pumpkin x51.`
3. Save the place (Ctrl+S). **Ctrl+Z** undoes it.

- Trying it in a playtest? **F8 > Apply custom props** does the same for that playtest only. A round being played is left alone (its map and the hiders' pumpkins); the next map loads with your models by itself.
- Changed your model? Run `.Props()` again: every copy gets the new version.
- Want the built look back? Take your model out of `Custom > Props`, then run `require(game.ServerScriptService.Server.Tools.Swap).Props({ Revert = true })`. The built ones are kept in `ServerStorage > PropBackups` for this (delete that folder once you're happy; then Revert can't bring them back, but `Bake.Hub()` / `Bake.Map(...)` can rebuild them).
- Tags and attributes the game needs are kept (decoys stay decoys, parkour pads stay pads).

### Anything else: replace by name
For things that aren't in the table (say, rocks you dragged in from the Toolbox and copied around by hand), replace everything with the same **name**:

`require(game.ServerScriptService.Server.Tools.Swap).Replace("Rock", workspace.MyRock)`

Every Model or Part named `Rock` in `Workspace` and `ServerStorage > Maps` becomes a copy of `workspace.MyRock`: same spot, facing the same way, scaled to the old one's height. It keeps their tags and attributes and prints how many it changed. Add a third part to only change one place, e.g. `.Replace("Rock", workspace.MyRock, workspace.Hub)`.

What it never touches:
- **Props, and the parts inside them.** Pumpkins, jack-o'-lanterns, gravestones... are built from parts with names like `Pumpkin` (a jack-o'-lantern's middle) or `Tombstone` (a gravestone's slab); replacing one part would leave the rest floating. Give it a prop name (`Pumpkin`, `Gravestone`...) and it stops and tells you to use the steps above instead (your model in `Custom > Props`, then `Swap.Props()`), which also keeps what the game needs, like hitboxes and lights.
- Parts that *do* something (they have a tag, like a parkour pad).

Ctrl+Z undoes it; save the place to keep it.

### Keep it in git
Your model lives in the place file. To keep it in git too (recommended): right-click it > **Save to File...** and save it as `new-game/assets/Props/<Name>.rbxm`, e.g. `assets/Props/Pumpkin.rbxm`. Rojo syncs it into `ReplicatedStorage > Custom > Props`, so it survives even if the place file is lost. With Rojo connected, delete the Studio copy afterwards so there is only one.

Or ask Claude Code: `/swap-prop Pumpkin` (it walks through all of this in Studio for you).

---

## Change and animate skins
There are three ways to change how a skin looks and moves. They all end up in the same place: the skin's entry in its theme file, `src/shared/Config/Skins/<Theme>.luau`.

| Way | Best for | You need |
| --- | --- | --- |
| [1. Skin Studio](#way-1-skin-studio-in-a-playtest) | Trying colours, head pieces and animations with buttons and sliders, and seeing them on your own character straight away | Studio and a playtest, then Claude Code (`/save-skins`) or copy and paste |
| [2. Edit the theme file](#way-2-edit-the-theme-file-by-hand) | A quick change (one colour, one speed), or many skins at once | VS Code (Rojo syncs it to Studio) |
| [3. Your own model, or catalog items](#way-3-your-own-model-in-studio-and-catalog-items) | A head piece you built (or got from the Toolbox) with parts that move, or real Roblox hats and clothes | Studio |

Or just ask Claude Code: `/animate-skin Candy_BubblegumBat make the wings flap slowly`, or `/add-skin Candy Rare a bubblegum ghost`.

**Rules for every way** (Skin Studio and the tests tell you when you break one):
- **Never change a skin's `Id`** once it's in the game: it's saved in players' data. Change its `Name` instead.
- Each rarity gets more: Common = colours, materials and accents; Uncommon = + a head piece and 1 animation; Rare = + glow, particles, 3 animations and a walk style; CRAZY = everything, + rainbow, orbiting pieces and 6 animations.
- On a skin players already own, change the look and the name freely. Its rarity, crate and price change what players own and the Robux crate odds, so leave those alone unless you really mean it.
- Spooky-cute, never gory: it's a kids' game.

### Way 1: Skin Studio (in a playtest)
Skin Studio is a skin editor for you (admins) in a Studio playtest. Players never see it. The full tour and troubleshooting are in [Skin Studio](#skin-studio) below.

**Open it and pick a skin**

1. Open the place in Studio, connect Rojo and press **Play**.
2. Press **M** (or the orange **Menu** button) and click the **🎨 Skin Studio** tile. **F8 > Skin Studio** works too. The panel opens on the right, so you can still see your character.
3. In the **Skins** tab, search for a name or Id, or pick a theme, a rarity, "Drafts" or "Animated". Click a skin to edit it. **New** starts a blank skin in the chosen theme. **Duplicate** copies the skin you're editing, which is the easiest way to start a new one.

**Change how it looks (Look tab)**

4. **Basics**: name, rarity, theme, crate and price. A new skin's Id follows its name. A skin already in the game keeps its Id, and its rarity, crate and price are locked 🔒.
5. **Body**: click a colour to open the colour picker (24 swatches, red, green and blue sliders, or type a code like `#FF8214`). Pick materials (Neon, Foil, Glass...), see-through, and whether to hide the avatar's clothes.
6. **Head piece** (Uncommon and up): pick one from the list, then its colours, its glow colour and (pumpkin heads only) its carved face.
7. **Accent**: a second colour and material, and patterns (Belt, Stripes, Wings, Tail, Cape...). Click them in the order you want them.
8. **Glow** and **Particles** (Rare and up): the light's colour, brightness and range, and the particle kind (Sparkles, Embers, Bubbles...) with its two colours.
9. **CRAZY** (CRAZY skins only): rainbow, pulse, the pieces orbiting you and how many, and a special effect.

Every row has a **?** button that explains it. Yellow lines are warnings (allowed, but the tests would complain). A red line at the top is an error: fix it, or press **↶ Undo**.

**Make it move (Animate tab)**

10. Press **+ Add animation**. Choose the **Effect** (what it does: Flap, Wag, Spin, Pulse...) and the **Target** (what it moves: Head, Wings, Tail, Cape, Glow...). Every effect is in [the table below](#every-animation-effect). A greyed-out target tells you why it can't be used: for example, the skin has no Wings pattern yet, or CRAZY already controls it.
11. Set **Speed**, **Amount** and **Delay**, and the effect's own settings (Axis, Colours, Every, Count). ▲ and ▼ change the order, ✕ removes one. Uncommon skins get 1 animation, Rare 3, CRAZY 6.
12. **Walk style** (Rare and CRAZY): pick Zombie, Mummy, Ghost, Robot, Bat, Sneaky, Bouncy or Proud ([table](#every-walk-style)). **▶ Use my own animations** takes the ids of walk, run and idle animations you uploaded.

**See it on you**

13. With **Wear on me** ticked (at the top of the panel), your character wears the skin a moment after every change, animations and walk style included. Walk, run and jump. Go to the Photo Spot and dance.
14. **🎥 Turn** circles the camera round you so you see every side. Press it again to stop. The small preview at the top turns too.
15. **↶ Undo**, **↷ Redo** and **Reset** (back to how the skin was when you opened it) are at the bottom. Closing the panel loses nothing: open it again and it's all still there.

**Save it and put it in the game**

16. Go to the **Save** tab and press **💾 Save**. You can also write a note for Claude Code first, for example "put this one in the Candy crate".
    Saved skins (drafts) only live in this playtest. **They're gone when you press Stop.**
17. In Claude Code, type **`/save-skins`** **before you press Stop**. Claude Code reads your drafts from the playtest through the Studio MCP and shows you a plan: which file, added or changed, the new rarity counts and any warnings. When you say yes, it writes them into the theme files, runs the tests, commits and pushes. Open Skin Studio again and those drafts show ✓.
18. Press **Stop**. Next playtest they're normal skins in the Shop and in their crate.

**No Studio MCP, or `/save-skins` didn't work? Use the Copy code box:**

1. In the Save tab, press **Copy code**. A box shows the skin written as an entry for a theme file.
2. Click in the box, press **Ctrl+A** then **Ctrl+C**.
3. Paste it into Claude Code and say which theme file, for example "put this skin in the Candy theme file". Or paste it yourself: open `src/shared/Config/Skins/<Theme>.luau` and paste it at the end of its rarity's group (each group starts with a comment like `-- RARE`). To change a skin that's already there, replace its old entry, from its `{` to its `},`.
4. Save the file, run the tests (`lune run tests/run`, or ask Claude Code) and commit.

**Print for Claude** (Save tab) prints every saved draft to Output instead, for the older Studio MCP. When you press Stop, Studio prints them once more as a last chance. The classic skins and the Tormented Tower's skin can be tried in Skin Studio, but `/save-skins` doesn't write them: use Copy code.

### Way 2: edit the theme file by hand
Every crate skin is one entry in its theme file in `src/shared/Config/Skins/` (30 themes, one file each). The Tormented Tower's skin is in `src/shared/Config/TowerParkour.luau` > `Skin`.

1. Open the theme file in VS Code, for example `src/shared/Config/Skins/Candy.luau`, and find the skin with **Ctrl+F** (search for its Id or name).
2. Change what you want. The example below shows every setting a skin can have. Leave out what you don't need.
3. Save the file. Rojo copies it into Studio. Press **Play**.
4. See it: **F8 > Unlock all items**, then **Menu > Skins**, pick the theme and wear it. Or open it in Skin Studio and tick **Wear on me**.
5. Run the tests: `lune run tests/run` (or ask Claude Code). They check the rarity rules, the animation limits, that every effect has something to move, and that no two skins look the same.
6. Commit it (or ask Claude Code to).

**A new skin:** copy a whole entry of the same rarity (from `{` to `},`), paste it at the end of that rarity's group, and give it a new `Id` that starts with the theme (`Candy_LollipopBat`). The tests count the skins of each rarity, so after adding one they report the new count: ask Claude Code to update it, or use `/add-skin`, which does it for you.

**Every setting, in one example.** A Rare skin, because Rare can have nearly everything. The CRAZY extras and catalog items come after it.

```lua
{
	Id = "Candy_LollipopBat", -- unique, starts with the theme. NEVER change it once it's in the game
	Name = "Lollipop Bat", -- what players see (1 to 40 letters)
	Rarity = "Rare", -- "Common", "Uncommon", "Rare" or "Crazy": sets its price and what it may have
	-- Price = 300, -- optional: its own shop price instead of its rarity's price
	-- CrateOnly = true, -- optional: only from crates, not sold in the Shop
	-- Crate = "PumpkinCrate", -- optional: drops from a different crate than its theme's
	Style = {
		-- BODY (every rarity). Colours are rgb(red, green, blue), each 0 to 255.
		BodyColor = rgb(255, 140, 200), -- the whole body
		TorsoColor = rgb(230, 90, 170), -- one part, wins over BodyColor (also ArmsColor, LegsColor)
		Material = M.SmoothPlastic, -- the whole body: M.Neon, M.Foil, M.Glass, M.Fabric, M.Ice...
		ArmsMaterial = M.Foil, -- one part (also TorsoMaterial, LegsMaterial, HeadMaterial)
		Transparency = 0, -- 0 = solid, 0.3 = see-through, 1 = invisible
		HideClothes = true, -- the usual: hide the avatar's shirt and pants. false keeps them
		Accent = { -- a second colour on the body
			Color = rgb(120, 60, 160),
			Material = M.Neon,
			Pattern = { "Wings", "Belt" }, -- only Wings, Tail and Cape can move (full list: top of Pumpkin.luau)
		},

		-- HEAD PIECE (Uncommon and up; the list is at the top of Pumpkin.luau)
		Head = "BatHead",
		HeadColor = rgb(255, 140, 200), -- the head piece's main colour
		HeadColor2 = rgb(255, 225, 240), -- its second colour (inner ears, hat, wrapper...)
		GlowColor = rgb(120, 255, 200), -- its glowing bits (eyes, carved face, flame)
		-- HeadColor3 = rgb(...), -- a third colour (only GentlemanGourd's hat band)
		-- Face = "Happy", -- pumpkin heads only: Happy, Spooky, Surprised, Sleepy, Wink, Toothy

		-- GLOW AND PARTICLES (Rare and up)
		Glow = { Color = rgb(255, 120, 200), Brightness = 2, Range = 12 }, -- a light around you
		Aura = { Kind = "Bubbles", Color = rgb(255, 180, 230), Color2 = rgb(255, 255, 255) },
		-- Aura kinds: Sparkles, Embers, Bubbles, Hearts, Snow, Smoke, Stars (fades Color to Color2)

		-- ANIMATIONS (Uncommon 1, Rare 3, CRAZY 6). Every effect: the table below.
		Animate = {
			{ Effect = "Flap", Target = "Wings", Speed = 0.8 }, -- the wings beat, a bit slower
			{ Effect = "ColorCycle", Target = "Belt", Colors = { rgb(255, 110, 190), rgb(120, 255, 200) } },
			{ Effect = "SparkleBurst", Every = 4, Count = 15 }, -- a puff of bubbles every 4 seconds
		} :: { any }, -- keep this ending: it tells Studio's checker the effects differ in shape

		-- WALK STYLE (Rare and CRAZY): Zombie, Mummy, Ghost, Robot, Bat, Sneaky, Bouncy, Proud
		Motion = "Bat",
	},
},
```

Every effect line can also have (all optional): `Speed = 2` (twice as fast, 0.1 to 5), `Amount = 0.5` (half as big or strong, 0 to 3), `Delay = 1` (starts a second later, 0 to 10), `Axis = "X"` (which way it turns: X nods, Y turns, Z tilts), plus each effect's own settings in [the table](#every-animation-effect). Leave `Target` out and the effect uses its usual one.

**CRAZY skins only** also have (and every CRAZY skin needs `Rainbow = true` and an `Orbit`):
```lua
		Crazy = {
			Rainbow = true, -- a rainbow shimmer over you and rainbow accents
			Pulse = true, -- the glow pulses
			Orbit = "Candies", -- pieces flying round you: Pumpkins, Candies, Ghosts, Bones, Eyes, Stars, Bats
			Count = 3, -- how many (1 to 8)
			-- Effect = "DiscoInferno", -- a big special effect: Torment, BloodMoon, DiscoInferno, UfoBeam
		},
```
CRAZY already controls the rainbow on the accents and the pulsing glow, so a CRAZY skin's `Animate` can't colour its accents (`Accents`, `All` or a pattern) and can't `Pulse` or `Flicker` its `Glow`. Use `Head` or `Body`, a `ColorCycle` on the `Glow`, or a moving effect instead. Each CRAZY skin has its own head piece that no other skin uses.

**Your own walk, run and idle animations** instead of (or as well as) a walk style:
```lua
		Motion = { Walk = "rbxassetid://123", Run = "rbxassetid://456", Idle = "rbxassetid://789" },
		Motion = { Preset = "Ghost", Idle = "rbxassetid://789" }, -- the Ghost walk style + your own idle
```
They must be uploaded by you (or your group, if the game belongs to a group) or made by Roblox; see [Walk styles](#walk-styles).

**Catalog items** (real Roblox hats and clothes; do [Way 3](#way-3-your-own-model-in-studio-and-catalog-items) first: these ids are made up, and the tests refuse any id that isn't approved):
```lua
		HideClothes = false, -- only needed for Shirt, Pants and TShirt
		Catalog = {
			Accessories = { { Id = 1234567890, Type = "Hat" }, { Id = 2345678901, Type = "Back" } }, -- up to 4
			Shirt = 3456789012, Pants = 4567890123, TShirt = 5678901234, -- classic clothes
			ClassicFace = 6789012345, -- a flat face (only on a skin without a Head)
		},
```

### Way 3: your own model in Studio, and catalog items

**Your own head piece, with parts that move**

A model can replace a skin's head piece, and its parts can move without any code: you mark them with **attributes** (small named values on a part).

1. **Get or build the model** in Studio: Parts grouped into a Model, a Toolbox model, or a mesh (see [Builder mode](#builder-mode-give-a-character-your-own-look) for the ways to make one). It is resized so its biggest side is 2.4 studs (`Config.Custom.CosmeticSize`) and sits where the head is.
2. **Name it exactly like the skin's Id**, for example `Candy_LollipopBat`, and drag it into `ReplicatedStorage > Custom > Cosmetics`.
3. **Group each moving piece.** A wing made of three parts? Select them and press **Ctrl+G** to make them one Model. A single part can move on its own.
4. **Set where it turns.** A Model turns round its pivot: select it, then **Model tab > Pivot > Edit Pivot** and drag the pivot to the joint (for a wing, where it meets the body). A single part turns round its own middle.
5. **Mark it.** Select the part or Model. In **Properties > Attributes**, press **+**, type the name `Animate`, choose the type **string**, press Save, then type the effect name as its value, for example `Flap`.
6. **Optional settings**, added the same way (the type matters: Studio's **+** starts on "string", so change it to **number** before you type a number):

   | Attribute | Type | What it does |
   | --- | --- | --- |
   | `Animate` | string | The effect: `Spin`, `Bob`, `Float`, `Wobble`, `Flap`, `Wag`, `Breathe`, `Pulse`, `ColorCycle`, `Flicker` or `Shimmer` ([what they look like](#every-animation-effect)). Capital letters count. |
   | `Speed` | number | 0.1 to 5. 2 = twice as fast. |
   | `Amount` | number | 0 to 3. 0.5 = half as big. |
   | `Delay` | number | 0 to 10 seconds later, so two pieces don't move together. |
   | `Axis` | string | `X`, `Y` or `Z`: which way it turns (Spin, Wobble, Flap, Wag, Breathe). |
   | `Reverse` | boolean | Tick it to spin the other way (Spin). |
   | `Every` | number | Flicker: seconds between flickers (0.05 to 30). |
   | `Color2` | Color3 | ColorCycle: fades between the part's own colour and this one. |

7. **Press Play and wear the skin** (F8 > Unlock all items, Menu > Skins). Or open the skin in Skin Studio: its Animate tab lists anything wrong with your marks in yellow, and Output says it once too (`[Cosmetics] your model ...`). **One wrong value and that part doesn't move at all.**
8. **Keep it.** Save the place (Ctrl+S). To keep it in git too, right-click the model > **Save to File...** and save it as `new-game/assets/Cosmetics/<SkinId>.rbxm`, then commit.

Good to know: at most 6 moving groups per skin (`Config.SkinAnimate.MaxPivots`). Scripts inside custom models are always removed, so attributes are the only way to animate one. If the skin's own `Animate` moves its `Head`, your marked parts ride along on top. More detail: [Animate parts of your own model](#animate-parts-of-your-own-model).

**Real Roblox catalog items (hats, hair, back items, classic clothes)**

Crates are sold for Robux and this is a kids' game, so only items made by **Roblox, you or your group** are allowed, and only ids you have checked and approved. The whole feature is **off** until you've tried it.

1. Open `src/shared/Config/SkinCatalog.luau`. Put your Roblox UserId in `AllowedCreators.UserIds` (and your group's id in `GroupIds`, if the game belongs to a group). Roblox's own items are already allowed.
2. Find the item on the Roblox website. Its id is the number in its web address: `roblox.com/catalog/<number>/...`. Check it yourself: how it looks, and that it's kid-friendly.
3. Add it to `ApprovedIds` in the same file, with a note: `[1234567890] = "Pumpkin Cap, Roblox, checked on 9 Oct 2026",`.
4. Switch it on: `SkinCatalog = true,` in `src/shared/Config/Features.luau`.
5. Add it to a skin:
   - **In Skin Studio**: the **Catalog** tab, type the id, press **Look up**. It fills in the kind of item (Hat, Back...) and refuses items by anyone else. Save, then `/save-skins`.
   - **By hand**: a `Catalog = { ... }` block in the skin's `Style` (see the example in [Way 2](#way-2-edit-the-theme-file-by-hand)). Shirts, pants and T-shirts need `HideClothes = false`.
6. Test it in Studio: wear the skin. The item appears after a second or two, the skin's own pieces still move, and taking the skin off gives you back your own avatar exactly. Then try respawning, and a 2-player test.

Bundles, body parts, body scales, layered (3D) clothing and animation packs are not allowed: they break the skin's pieces. Why, and what happens when an item won't load: [Catalog items in skins](#catalog-items-in-skins).

### Every animation effect
`Speed`, `Amount` and `Delay` can go on every effect (`Speed` = how fast, `Amount` = how big or strong, `Delay` = seconds later). The **bold** target is the one it uses when you leave `Target` out. "Every skin" numbers are in `src/shared/Config/SkinAnimate.luau` > `Presets`: change one there and every skin with that effect changes.

| Effect | What it looks like | What it can move (Target) | Its own settings | Every skin (`Presets`) |
| --- | --- | --- | --- | --- |
| `Spin` | Turns round and round, like a spinning top | **`Head`**, `Wings`, `Tail`, `Cape`, `"Part:<name>"` | `Axis` (default `Y`), `Reverse = true` (the other way). `Amount` does nothing here: use `Speed` | `Seconds = 4` (one full turn) |
| `Bob` | Bobs up and down | **`Head`**, `Wings`, `Tail`, `Cape`, `"Part:<name>"` | none | `Seconds = 1.2`, `Height = 0.15` studs |
| `Float` | Floats up and sways gently, like under water | **`Head`**, `Wings`, `Tail`, `Cape`, `"Part:<name>"` | none | `Seconds = 3`, `Height = 0.35` studs, `Sway = 6` degrees |
| `Wobble` | Tilts from side to side | **`Head`**, `Wings`, `Tail`, `Cape`, `"Part:<name>"` | `Axis` (default `Z`) | `Seconds = 1`, `Degrees = 8` |
| `Flap` | Wings beat back and open again, like a bat | **`Wings`**, `"Part:<name>"` | `Axis` (default `Y`) | `Seconds = 0.6`, `Degrees = 35` |
| `Wag` | Swings from side to side, like a happy tail | **`Tail`**, `"Part:<name>"` | `Axis` (default `Y`) | `Seconds = 0.5`, `Degrees = 25` |
| `Breathe` | A slow, tiny lift and tilt, like a cape in a breeze | **`Cape`**, `Head`, `Wings`, `Tail`, `"Part:<name>"` | `Axis` (default `X`) | `Seconds = 3.5`, `Height = 0.05`, `Degrees = 3` |
| `Pulse` | Glows brighter and dimmer, like a heartbeat | **`Glow`**, `Head`, `Accents`, a pattern (`"Belt"`...), `Body`, `All`, `"Part:<name>"` | none | `Seconds = 1.6`, `Low = 0.45` (the dimmest: 45%) |
| `ColorCycle` | Fades through your colours in order, rippling across the pieces | **`Accents`**, `Glow`, `Head`, a pattern, `Body`, `All`, `"Part:<name>"` | `Colors = { rgb(...), rgb(...) }` (2 to 6 colours) | `SecondsPerColor = 1`, `Spread = 0.15` (how far each piece is behind the last) |
| `Flicker` | Flickers like a candle flame | **`Glow`**, `Head`, `Accents`, a pattern, `Body`, `All`, `"Part:<name>"` | `Every = 0.08` (seconds between flickers, 0.05 to 30) | `Every = 0.08`, `Low = 0.3`, `Chance = 0.35` (how often it dims) |
| `Shimmer` | A bright band of light sweeps up the pieces | **`Accents`**, `Head`, a pattern, `Body`, `All`, `"Part:<name>"` (not `Glow`) | none | `Seconds = 2`, `Width = 0.25`, `Strength = 0.6` |
| `SparkleBurst` | A puff of the skin's own particles every few seconds | **`Aura`** only (the skin needs an `Aura`) | `Every = 3` (seconds between bursts, 0.5 to 30), `Count = 20` (particles, 1 to 50) | `Every = 3`, `Count = 20`, `MaxCount = 50` |

For the colour effects (`Pulse`, `ColorCycle`, `Flicker`, `Shimmer`) `Amount` above 1 is the same as 1 (full strength); `Amount = 0.5` is half. For `SparkleBurst` it multiplies `Count`. What each target means: [Animated skins](#animated-skins).

### Every walk style
A walk style poses the arms, legs and head and blends with Roblox's own walking, on R15 and R6 avatars. A dance at the Photo Spot always wins. Its numbers are in `src/shared/Config/SkinMotion.luau` > `Presets` (degrees, studs, and `Seconds` for one step): change one there and every skin with that walk style changes.

| `Motion =` | What it looks like | Its numbers (`Presets`) |
| --- | --- | --- |
| `"Zombie"` | Arms held out in front, head tilted, a slight lean, a slow shuffle | `ArmsForward = 85` (how high the arms are), `Lean = 8`, `HeadTilt = 12`, `Seconds = 1.1` |
| `"Mummy"` | Stiff arms forward, a little lower, and short, stiff steps | `ArmsForward = 75`, `Step = 14` (how far the legs swing), `Lean = 4`, `Seconds = 1.3` |
| `"Ghost"` | Floats above the ground and bobs, legs dangling, arms limp | `Height = 0.8` (studs up), `Bob = 0.25` studs, `Dangle = 18`, `Seconds = 2.4` |
| `"Robot"` | Straight elbows and knees, swinging arms, the head turning in little ticks | `Swing = 28` (arms), `Step = 24` (legs), `HeadTurn = 20`, `Ticks = 4` (head stops per turn), `Seconds = 0.9` |
| `"Bat"` | Arms out, flapping like wings (faster when moving), with a little hover | `ArmsOut = 70`, `Flap = 35`, `Hover = 0.3` studs, `Seconds = 0.35` (one flap while moving), `IdleSeconds = 0.8` (standing) |
| `"Sneaky"` | A crouched tiptoe with arms held close | `Crouch = 0.35` studs lower, `Lean = 14`, `Knees = 35` (how bent), `Seconds = 0.9` |
| `"Bouncy"` | An extra hop in every step | `Hop = 0.35` studs, `Seconds = 0.5` |
| `"Proud"` | Chest out, chin up, a gentle sway | `ChestOut = 8`, `ChinUp = 12`, `Sway = 4`, `Seconds = 2` |

Settings for all walk styles are at the top of the same file: `MaxCharacters` (12 closest characters get one; `PhoneMaxCharacters` 6), `MaxDistance` (100 studs), `RunSpeed` (above 20 studs a second an uploaded `Run` animation plays instead of `Walk`), `OwnRootShiftMax` (0.2: your own float or hop stays small so you don't bump ceilings; other players see the full float) and `AllowUploaded` (`false` ignores uploaded animation ids).

### It doesn't move?
| Check | Why |
| --- | --- |
| The skin really has the target | A `Flap` on `Wings` needs the Wings pattern in `Accent.Pattern`, a `SparkleBurst` needs an `Aura`, `Glow` effects need a `Glow`. Otherwise it does nothing (the tests and Skin Studio warn you). |
| The rarity allows it | Common: no animations; Uncommon 1, Rare 3, CRAZY 6; walk styles Rare and CRAZY only (`Config.SkinAnimate.Rarity`). The tests fail with the reason. |
| CRAZY isn't already doing it | A CRAZY skin's rainbow colours its accents and its pulse dims its glow, so `Animate` can't touch those. |
| The switches are on | `SkinAnimations`, `WalkStyles` (and `SkinEffects` for CRAZY) in `src/shared/Config/Features.luau`. |
| You're close enough | Other players' skins animate within 120 studs, the closest 8 (4 on phones): `src/shared/Config/SkinAnimate.luau`. Your own always does. |
| It's not a Hide & Seek hider | Hiders never animate, sparkle or change colour, on purpose. |
| Shop and crate previews | They move on PC only (`PreviewMotionOnPhones = false`), at most 4 at once. |

---

## Skins, hats, pets and trails

### Change how an existing item looks
Put a Model (or an Accessory from the Toolbox) named after the item's **Id** into `ReplicatedStorage > Custom > Cosmetics`. Ids are in `Config.Shop.Items`, e.g. `WitchHat`, `MiniPumpkin`, `GhostKitty`, `PumpkinHead`.
- **Hats**: the bottom of the model sits on top of the head. Scaled so the biggest side is 2 studs.
- **Pets**: float next to the player. 1.6 studs.
- **Skins**: the model is the head piece. It replaces the head, centred on it. 2.4 studs.
Sizes are in `Config.Custom.CosmeticSize`.

### Add a brand new item
Add an entry to `Config.Shop.Items` (in `src/shared/Config/init.luau`). For example, a new pet that only uses your model:
```lua
{
	Id = "SpiderPet",            -- also the name of your model in Custom > Cosmetics
	Name = "Spooky Spider",      -- shown in the shop
	Slot = "Pet",                -- "Skin", "Hat", "Trail" or "Pet"
	Rarity = "Uncommon",         -- sets the price: Common 125, Uncommon 500, Rare 1000, Crazy 100000
	Style = { Kind = "Custom" }, -- look comes from the custom model
},
```
The price comes from the item's `Rarity` (`src/shared/Config/Rarity.luau`). To give one item its own price, add `Price = 750`. Add `VipOnly = true, Price = 0` to make it a VIP perk. Until the model exists, the shop shows a pink "?" box, so nothing breaks. Or ask Claude Code: `/add-cosmetic a glowing bat hat`.

### Rarity and prices
`src/shared/Config/Rarity.luau` has one block per rarity: `Name` (what players see), `Price` (coins in the shop), `Color` (the tag colour) and `DuplicateRefund` (coins back when a crate gives you a skin you own). Change `Levels.Rare.Price` and every Rare item follows. Don't rename the ids (`Common`, `Uncommon`, `Rare`, `Crazy`): items and saves use them.

### Skin options (no model needed)
```lua
{
	Id = "Vampire", Name = "Vampire", Slot = "Skin", Rarity = "Uncommon",
	Style = {
		Kind = "Skin",
		BodyColor = Color3.fromRGB(220, 220, 235), -- recolours the whole avatar (optional)
		Material = Enum.Material.SmoothPlastic,    -- optional: Neon, Fabric, Glass, ...
		Transparency = 0,                          -- optional: 0.3 = see-through
		HideClothes = true,                        -- hide shirt and pants (optional)
		Head = "SkinSkull",                        -- optional head piece (full list: top of Config/Skins/Pumpkin.luau)
		HeadColor = Color3.fromRGB(235, 228, 210), -- head piece colour
		GlowColor = Color3.fromRGB(255, 0, 0),     -- eyes and mouth glow
	},
},
```
Skins are removed cleanly when unequipped: the player's own avatar comes back.

### Crate skins: add or change a skin
The crate skins (about 630 with the classic ones) live in `src/shared/Config/Skins/`, one file per theme (30 themes). The six classic themes (`Pumpkin`, `Candy`, `Spooky`, `Graveyard`, `Monster`, `Moonlight`) have 20 skins each: 12 Common, 5 Uncommon, 2 Rare and 1 CRAZY. The 24 newer themes (`VampireCastle`, `ZombieTown`, `HauntedCarnival`, `MummyTomb`, `WerewolfWoods`, `MadScientistLab`, `GhostShip`, `BatCave`, `SpiderLair`, `SkeletonCrew`, `CursedToys`, `ScarecrowFarm`, `HauntedHotel`, `MonsterDisco`, `BlackCatAlley`, `GoblinMarket`, `SwampCreatures`, `WitchsBrew`, `AlienAbduction`, `FrostyFright`, `GraveyardParty`, `CandyFactory`, `PhantomTheatre`, `AutumnLeaves`) have 21 each: 13 Common, 5 Uncommon and 3 Rare, and three of them one ONE IN A MILLION CRAZY skin. There are exactly 10 CRAZY skins in the game (the six classic ones, the Tormented Tower's and the three one-in-a-million ones). The tests check that no two skins look the same. Every style option (colours, materials, patterns, head pieces, glow, auras, CRAZY effects) is explained at the top of `Pumpkin.luau`.

**Add a skin:**
1. Open the theme file, e.g. `src/shared/Config/Skins/Candy.luau`.
2. Copy one whole skin block (from `{` to `},`) of the rarity you want and paste it below.
3. Give it a new `Id` that starts with the theme (`Candy_BubbleGum`) and a `Name`.
4. Set its `Rarity` and change its `Style` colours.
5. Save. It is in the Shop (at its rarity price) and in that theme's crate straight away. The crate odds update by themselves: skins of one rarity share that rarity's chance.
6. The offline tests (`lune run tests/run`) check how many skins of each rarity every theme has, so after adding a skin they report the new count. That's expected: ask Claude Code to update the count in `tests/specs/skins.spec.luau`, or use `/add-skin`, which does it for you. (Changing an existing skin's look and name keeps the counts.)

**Change a skin:** change its `Name` or anything in `Style` freely. **Never change an `Id`** once the game is live: it is saved in players' data.

**Rules worth knowing:**
- How rarities should look: Common = colours, materials and an accent; Uncommon = + a head piece; Rare = + glow and particles (`Glow`, `Aura`); CRAZY = everything + `Crazy = { Rainbow, Pulse, Orbit }`, and optionally its own animated `Effect` (`Torment`, `BloodMoon`, `DiscoInferno`, `UfoBeam`: `src/client/SkinEffects.luau`, numbers in `Skins/Settings.luau` > `Effects.Special`).
- The Skins tab of the shop has a theme dropdown (the "All themes" chip) with all 30 themes.
- `CrateOnly = true` keeps a skin out of the Shop (crates only). `Price = 300` gives it its own price.
- `Crate = "CandyCrate"` on one skin puts it in a different crate than its theme's.
- **New theme:** copy a theme file, rename it and every `Id` in it, then add a line to `Themes` in `Skins/Settings.luau` (its `Id` is the file name, `Crate` is the crate it drops from). Add that crate too (see "Crates").
- CRAZY animations can be switched off with `Config.Features.SkinEffects = false`; their speed and how many players animate at once are in `Skins/Settings.luau` > `Effects`.
- Or ask Claude Code: `/add-skin a Candy skin made of bubble gum, Rare`.

### Animated skins
Skin pieces can move and change colour: wings flap, tails wag, capes sway, head pieces spin, bob or float, colours fade, glows flicker and sparkles burst. Everyone in the server sees the same movement at the same moment. Each player's own screen draws it (`src/client/SkinAnim.luau`), so it costs no network and phones stay fast.

Add an `Animate` list to a skin's `Style` (in its theme file in `src/shared/Config/Skins/`):
```lua
Style = {
	...
	Accent = { Color = rgb(200, 80, 160), Pattern = { "Wings", "Tail" } },
	Head = "BatHead",
	Glow = { Color = rgb(255, 120, 200) },
	Animate = {
		{ Effect = "Flap", Target = "Wings" },             -- the wings beat
		{ Effect = "Wag", Target = "Tail", Speed = 1.5 },  -- the tail wags, a bit faster
		{ Effect = "Pulse", Target = "Glow" },             -- the light pulses
	} :: { any }, -- (tells Studio's checker the effects may look different from each other)
},
```

**The effects** (what each looks like, what it can move and its settings) are in one table: [Every animation effect](#every-animation-effect).

**The targets:** `Head` = the head piece (or your custom model), `Wings` / `Tail` / `Cape` = those accent patterns (the only ones that can move), any other pattern name (`"Belt"`, `"Stripes"`...) = that pattern's pieces, `Accents` = every accent piece, `All` = head piece + accents, `Body` = the avatar's own body parts, `Glow` = the light, `Aura` = the particles, `"Part:Crescent"` = the parts (or the Model) called `Crescent` inside the head piece. Leave `Target` out and each effect uses its usual one (Flap: Wings, Wag: Tail, Breathe: Cape, Pulse and Flicker: Glow, ColorCycle and Shimmer: Accents, SparkleBurst: Aura, the others: Head).

**Make it faster, bigger or later** (all optional): `Speed = 2` (twice as fast, 0.1 to 5), `Amount = 0.5` (half as big or strong, 0 to 3), `Delay = 1` (starts a second later, so two effects don't move together), `Axis = "X"` (which way it turns: X nods, Y turns, Z tilts). To change an effect for every skin at once, change its numbers in `src/shared/Config/SkinAnimate.luau` > `Presets` (for example `Flap.Degrees`).

**CRAZY already owns the rainbow and the glow pulse.** A CRAZY skin's `Crazy.Rainbow` colours its accents and `Crazy.Pulse` pulses its glow every frame, so `Animate` can't colour the accents (`Accents`, `All` or a pattern) or `Pulse` / `Flicker` the `Glow` of a skin that has them. Use `Target = "Head"` or `"Body"`, a `ColorCycle` on the `Glow` (that changes its colour, not its brightness), or any moving effect instead. The tests (and Skin Studio) tell you in plain English if you try.

**How many:** Common skins don't animate, Uncommon get 1 effect, Rare 3, CRAZY 6 (`Config.SkinAnimate.Rarity`). The tests check every skin. These skins show it off: Bubblegum Bat, Cotton Candy Cat, Moon Moth, Brew Mistress, Sir Gourdington, Zombie Overlord and every CRAZY skin.

**Hide & Seek:** a hider never animates, sparkles or changes colour, so nothing gives them away.

### Animate parts of your own model
A custom model for a skin (`ReplicatedStorage > Custom > Cosmetics`, named after the skin's Id; see "Builder mode") can move too, without any code:
1. Select a part, or a Model grouping several parts, inside your model.
2. Properties > Attributes > **+**: add `Animate` (type string) and type an effect name: `Spin`, `Bob`, `Float`, `Wobble`, `Flap`, `Wag`, `Breathe`, `Pulse`, `ColorCycle`, `Flicker` or `Shimmer`.
3. Optional, the same way: `Speed`, `Amount`, `Delay`, `Every` (numbers), `Axis` (string `X`, `Y` or `Z`), `Reverse` (boolean), `Color2` (Color3: `ColorCycle` fades between the part's own colour and this one).
4. A Model turns round its pivot: set it with the **Pivot** tool (Model tab > Pivot > Edit Pivot). A single part turns round its own middle.
5. Press Play and wear the skin. To keep it in git, right-click the model > **Save to File...** as `assets/Cosmetics/<SkinId>.rbxm`.

Names and types must be exact: `Spin`, not `spin` (capital letters count), and `Speed`, `Amount`, `Delay` and `Every` must be **number** attributes inside their ranges (Studio's **+** starts on "string": change the type before you type the number; `Speed` is 0.1 to 5). **One wrong value and that part doesn't move at all.** Skin Studio's Animate tab lists what's wrong with your model's marks (yellow lines), and in a Studio playtest Output says it once when you wear the skin (`[Cosmetics] your model ...`). At most 6 moving groups per skin (`Config.SkinAnimate.MaxPivots`). Scripts inside custom models are still removed, so attributes are the way to animate one. If the skin's own `Animate` moves its `Head`, your moving parts ride along on it.

### Walk styles
A skin can change how you walk: add `Motion` to its `Style` (Rare and CRAZY skins only):
```lua
Motion = "Zombie",
```
Zombie, Mummy, Ghost, Robot, Bat, Sneaky, Bouncy or Proud: what each looks like and its numbers are in [Every walk style](#every-walk-style).

Their numbers (how far the arms reach, how high the ghost floats...) are in `src/shared/Config/SkinMotion.luau` > `Presets`. They work on R15 and R6 avatars, blend with Roblox's own walking, and a dance at the Photo Spot always wins. Every screen poses the closest 12 characters (6 on phones). **Your own float or hop is kept small** (`OwnRootShiftMax`, 0.2 studs) so you don't bump ceilings in the Tower or the maze; other players see the full float.

**Your own animations:** upload walk, run and idle animations (Avatar > Animation Editor > Publish), then:
```lua
Motion = { Walk = "rbxassetid://123", Run = "rbxassetid://456", Idle = "rbxassetid://789" },
Motion = { Preset = "Ghost", Idle = "rbxassetid://789" }, -- or both: the ghost poses + your idle
```
- They must be **owned by the game's owner** (you, or your group if the game belongs to a group), or be Roblox's own. Roblox won't play anyone else's. In Studio a warning in Output says `[SkinWalk] animation 123 didn't load: is it owned by the game's owner?` and your normal walk stays. A slow download (a phone joining the game) is waited for, up to `LoadGiveUpSeconds` (30) in `Config.SkinMotion`.
- They play on R15 avatars only (R6 avatars get just the `Preset`). Run plays above `RunSpeed`, Walk while moving, Idle when standing; in the air Roblox's own jump and fall show.
- `AllowUploaded = false` in `Config.SkinMotion` ignores all uploaded ids.

Switch walk styles off with `Config.Features.WalkStyles = false`, and animated skins with `Config.Features.SkinAnimations = false` (skins then look exactly as before, just still). Or ask Claude Code: `/animate-skin Candy_BubblegumBat make the wings flap slowly and the glow pulse`.

### Catalog items in skins
A skin can also put real Roblox catalog items on you: a hat, hair, glasses or a mask, a back item, a classic shirt, pants or T-shirt, or a classic face. The server adds them to your own avatar (`src/server/Services/SkinCatalogService.luau`) and Roblox shows them to everyone. Shop and crate cards show small pictures of them along the bottom of the preview (a 3D preview can't load catalog items).

**It's switched off** (`Config.Features.SkinCatalog = false`) until you've tried it in Studio.

```lua
Style = {
	...
	HideClothes = false, -- only needed for Shirt / Pants / TShirt (a costume hides your clothes)
	Catalog = {
		Accessories = { { Id = 1234567890, Type = "Hat" }, { Id = 2345678901, Type = "Back" } }, -- up to 4
		Shirt = 3456789012, Pants = 4567890123, TShirt = 5678901234, -- classic clothes
		ClassicFace = 6789012345, -- a flat face (only on a skin without a Head piece)
	},
},
```
These numbers are made up: an item's id is the number in its catalog web address (`roblox.com/catalog/<number>/...`). `Type` is one of `Hat`, `Hair`, `FaceAccessory` (glasses, masks), `Neck`, `Shoulder`, `Front`, `Back` or `Waist`; Skin Studio's **Look up** button fills it in for you. A wrong value is left out (the tests and Skin Studio say what's wrong).

**Only items made by Roblox, by you or by your group, and only ids you have approved.** Crates are sold for Robux and this is a kids' game, so other people's catalog items never go inside paid boxes:
1. The item must be made by Roblox, by you or by your group. Put your UserId in `AllowedCreators.UserIds` and your group's id in `AllowedCreators.GroupIds` (`src/shared/Config/SkinCatalog.luau`). Skin Studio's Look up refuses anyone else's items and says why.
2. Check the item yourself (how it looks, that it's kid-friendly) and add its id to `ApprovedIds` with a note: `[1234567890] = "Pumpkin Cap, Roblox, checked on 9 Oct 2026",`. The tests fail for any skin that uses an id that isn't listed. Claude Code only adds an id there when you say yes **and** it was made by Roblox, you or your group.
3. `ShowBuyButtons` stays `false`, so cards never show "Buy" buttons.

**What isn't allowed, and why:** bundles and body parts (they swap your body's parts, which breaks the skin's welded pieces and head piece), body scales (the welded pieces end up in the wrong place), layered 3D clothing (R15 only, it pokes through the skin and ignores `HideClothes`), and animation packs (use a walk style, `Motion`, instead).

**If an item won't load** (deleted, moderated, or Roblox is slow), you simply see the skin without it, and it isn't tried again until you change skin. In Studio, Output says `[SkinCatalog] catalog item 123 didn't load...` once. The character's attribute `SkinCatalogStatus` says `Loading`, `On` or `Failed: <why>`.

**Head pieces:** a skin's head piece hides your own hair and hats, but not the skin's catalog items, so a catalog `Hat` sits on your real head, inside or on top of the head piece. Check how it looks. Back items, clothes, and skins without a head piece are the easy cases.

**Switch it on and test it in Studio:**
1. Set `SkinCatalog = true` in `src/shared/Config/Features.luau`.
2. Give a test skin an approved id (or use Skin Studio's Catalog tab), press Play and wear it.
3. Check: the item appears after a second or two; the skin's pieces are still there and still move; take the skin off and your own avatar comes back exactly (one set of clothes, your own colours); reset (respawn) and it comes back; a wrong id shows the skin without it and Output explains.
4. Try it with two players (Test > Clients and Servers), and as a Hide & Seek hider (nothing shows while you hide).

### Trails
A trail is two colours: `Style = { Kind = "Trail", Color = ..., Color2 = ... }`.

---

## Skin Studio
Skin Studio is a skin editor for **you** (admins) in a Studio playtest: pick any skin or make a new one, change everything with colour pickers, sliders and dropdowns, and see it on your own character straight away (animations and walk styles too). Players never see it. Settings: `src/shared/Config/SkinStudio.luau` (on/off: `Config.Features.SkinStudio`). New to it? Follow [Way 1](#way-1-skin-studio-in-a-playtest) step by step; this section is the full tour.

**Open it:** press Play in Studio, then **Menu > Skin Studio** (the 🎨 tile) or **F8 > Skin Studio**. It sits on the right of the screen so you can see your character on the left. On a phone (Studio's device emulator, phone on its side) it's a column down the right half, with a small turning preview of the skin just left of it, and help and messages pop up in a bubble (tap it to close it); 🎥 Turn puts your character in the middle of the free part of the screen.

**The tabs:**
| Tab | What's there |
| --- | --- |
| Skins | Search names and Ids, pick a theme, a rarity, "Drafts" (your saved drafts) or "Animated". Tap a skin to edit it. **New** starts a blank skin in the chosen theme, **Duplicate** copies the one you're editing. ✎ = a draft, ✓ = already in the game files, 🎞 animated, 🚶 walk style, 🛍 catalog items. |
| Look | Name, Id, theme, rarity, crate and price; body colours and materials; the head piece; the accent (colour, material, patterns: tap them in order); glow; particles; CRAZY. Every row has a **?** that explains it (on a phone the explanation pops up in a bubble). Yellow lines under a section are warnings (allowed, but the tests would complain); red lines at the top are errors (it can't be worn or saved until fixed). |
| Animate | Animations (+ Add animation: effect, what it moves, speed, amount...) and the walk style. Targets CRAZY already drives are greyed out with the reason. |
| Catalog | Real Roblox catalog items: type an id and press **Look up**. Only items made by Roblox, you or your group are allowed (put your UserId or group id in `AllowedCreators` in `src/shared/Config/SkinCatalog.luau` first). They only show in game once `Config.Features.SkinCatalog` is on. |
| Save | **Save**, **Copy code**, **Print for Claude**, your drafts (open or delete them), a note for Claude Code (`/save-skins` shows it next to the skin, and Claude Code asks you before doing what it says) and "Keep wearing after closing". |

The footer has **Undo**, **Redo**, **Reset** (back to how the skin was when you opened it) and **🎥 Turn**: the camera circles your character so you can see every side (press it again, or close the panel, to get your camera back).

**Wearing:** with **Wear on me** ticked, your character wears the skin a moment after each change, and again after you respawn. Your save never changes (you don't own the draft). Other players in the same server see the skin on you while you wear it (in a 2-player test too). Choosing a skin yourself (**Menu > Skins**, the Shop, or **Equip** after opening a crate) takes the draft off, so you wear what you chose; edit the draft or tick **Wear on me** again to put it back on. **Closing the panel loses nothing** (Escape, the Roblox menu, opening the shop...): open it again and your skin, its Undo history and the tab are still there, and you keep wearing it (untick "Keep wearing after closing" in the Save tab to go back to your own skin when you close).

**Skins players already own** keep their Id and theme, and their rarity, crate and price are locked 🔒: players own them and the Robux crate odds depend on them. "Unlock rarity, crate and price" asks first, and `/save-skins` warns about any such change.

### Saving your skins into the game
Saved drafts live in the playtest. They are gone when you press Stop, so:

1. In Skin Studio, press **Save** on each skin you like (Save tab).
2. In Claude Code, type **`/save-skins`** **before you press Stop**. Claude Code reads the drafts from the running playtest through the Studio MCP, shows you the plan (which file, added or changed, the new rarity counts, warnings), writes them into the theme files after you say yes, runs the tests, commits and pushes.
3. When Claude Code has written them, it tells the playtest which drafts are now in the files: open Skin Studio again and they show ✓, and the "not in the game files yet" reminder stops counting them (without the built-in Studio MCP the reminder simply stays until you press Stop; that's fine).
4. Press Stop. Rojo syncs the changed theme files into Studio; next playtest the skins are normal skins in the shop and crates. The drafts themselves are gone after Stop (unless `UseDataStore` is on, below), so there's no ✓ to see then.

Two backups that always work:
- **Print for Claude** (Save tab) prints every saved draft to Output. Claude Code reads it with `get_console_output` (the older MCP), or you copy it into Claude Code. When you press Stop, Studio prints them once more as a last chance.
- **Copy code** (Save tab) shows the skin as Luau: Ctrl+A, Ctrl+C, paste it into Claude Code and say which theme file.

Classic skins (not in a crate) and the Tormented Tower's skin can be tried in Skin Studio, but `/save-skins` doesn't write them: use Copy code.

> ⚠️ **Keeping drafts after Stop needs Studio API access. Read this first.**
> Turning on **Game Settings > Security > Enable Studio Access to API Services** makes Studio use your **REAL** player save and the **PUBLIC** leaderboard. Then F8 "+ Coins", "Unlock all" and "Reset my save" change your real save, and Studio test rounds post to the leaderboard everyone sees. **Skin Studio doesn't need it:** leave it off and use `/save-skins` during the playtest.

Only if you still want drafts kept after Stop: turn on API access (knowing the above) and set `UseDataStore = true` in `Config.SkinStudio`. Drafts then also go into their own DataStore (`SkinStudioDrafts_v1`, never your player save), written at most every 7 seconds, and `/save-skins` can read them with Studio stopped. Live servers never touch it.

**Troubleshooting:**
| You see | What it means |
| --- | --- |
| "Saved for this playtest. Run /save-skins..." | Normal: the draft is saved until you press Stop. Run `/save-skins` now. |
| "Not allowed" | Skin Studio only works for admins in Studio (`Config.Admin`, `Config.SkinStudio.AllowInLiveServers`), with `Config.Features.SkinStudio` on. |
| "Skin Studio is switched off" (F8) | Set `SkinStudio = true` in `src/shared/Config/Features.luau`. |
| "N drafts are not in the game files yet" after `/save-skins` | Open Skin Studio again: drafts `/save-skins` wrote show ✓ and aren't counted. If Claude Code couldn't tell the playtest (no built-in Studio MCP), the reminder stays until Stop: your skins are still saved in the files. |
| "Slow down!" | Too many clicks at once; it tries again by itself for wearing. Wait a second for Save. |
| "Animation didn't load" (Output, `[SkinWalk]`) | An uploaded walk/run/idle animation must be owned by you (or your group, if the game is a group game) or made by Roblox. A slow download isn't a failure: the game waits up to `LoadGiveUpSeconds` (30, `Config.SkinMotion`) before giving one up. |
| "Not an allowed creator" | That catalog item isn't made by Roblox, you or your group (`Config.SkinCatalog.AllowedCreators`). |
| "This skin's rarity is locked" | Players already own this skin: press "Unlock rarity, crate and price" only if you really mean to change it. |
| A red ✕ line in the Look tab | Something can't be used (for example a pattern that doesn't exist). Fix it or press Undo. |

---

## Crates
Mystery crates give a random skin. Everything about them is in `src/shared/Config/Crates.luau`
(switch them off with `Config.Features.Crates = false`, or only the Robux ones with
`Config.Features.RobuxCrates = false`).
- **Odds**: `Odds = { Common = 73.48, Uncommon = 24, Rare = 2.5, Crazy = 0.02 }` is the chance (in
  percent) of each rarity. The skins of one rarity share it equally, so in the Pumpkin Crate each
  of the 12 Commons has 6.123% and its one CRAZY skin 0.020%. Keep the total at 100. One crate can
  have its own `Odds`. Rare and CRAZY were made rarer in the big skin update.
- **ONE IN A MILLION**: a skin with its own `Odds` (in its theme file: `Odds = 0.0001`) has exactly
  that chance (0.0001% = 1 open in a million) and the rest of the crate shares the other 99.9999%;
  the preview shows "0.0001%". These skins (`OneInAMillion = true`: Night Lord Supreme in Vampire
  Castle, Disco Demon in Monster Disco, Star Voyager in Alien Abduction) are never in the CRAZY Crate.
  Anyone unboxing a CRAZY skin is announced to the whole server (an extra-big banner for these),
  words in `Text.AnnounceCrazy` / `Text.AnnounceMillion`, switch: `AnnounceCrazy`; it waits `AnnounceDelay` seconds (4.5) so the winner sees their own reveal first.
- **Prices**: each crate's `Price` (coins): 600 for themed crates (doubled in the big skin update),
  the rarity crates stay just under the shop price of their rarity (the comment at the top of
  `Crates.luau` explains why). A Robux price is set in Creator Hub: make a Developer
  Product (Monetization > Developer Products) and paste its id into that crate's
  `Robux.ProductId`. Until then the button says "Coming soon".
- **Which skins are inside**: a skin is in a crate when its `Crate` is that crate's Id (the theme
  files in `Config/Skins/` do this for you). The rarity crates (Common, Uncommon, Rare, CRAZY Crate)
  hold every crate skin of their rarity.
- **New crate**: copy a line in `List`, give it a new Id and Name, then set `Crate = "<new Id>"` on
  the skins it should give. It appears in Menu > Crates straight away, and on the crate stand once
  the lobby is rebuilt (F8 > Rebuild hub, or `Bake.Hub()`). A lobby saved in your place keeps its
  stand: copy one of its `<CrateId>Display` models and set the `CrateId` attribute of its
  `CratePrompt` part to the new Id.
- **Duplicates**: a skin you already own ALWAYS pays back `DuplicateRefund` coins (`Config/Rarity.luau`:
  60, 250, 500 or 50,000, about half the shop price); the reveal says "Duplicate! +X coins back".
- **Open several**: `Open.Counts` (x1, x5, x10). The server rolls them all in one request and takes
  the coins in one go. While a strip spins, Space (`Open.SkipKey`) or the Skip button jumps to the
  result, then on to the next crate. **Quick open** (a switch on the crate page, `QuickOpen`) skips
  the strips: every result on one page, rarity colours, duplicates with their coins back, the best
  one highlighted.
- **Tabs and pages**: Menu > Crates has a tab per `Categories` entry (each crate's `Category`), and
  `PageSize` (`PhonePageSize` on phones) crates per page. Each card's chest turns slowly on a
  soft halo and bounces when tapped: `Cards` (`SpinSpeed`, `Halo`, `PopSeconds`).
- **On phones** the crate panel drops its hint line and moves up, the cards fit the list's height
  (name and price never cut off) and the opening chest is bigger: `Opening.PhoneCameraDistance`
  (smaller = bigger chest).
- **The crate stand** next to the Pumpkin Shop (`src/server/Hub/Sections/CrateStand.luau`, in
  `Config.Lobby.Zones.Crates`): the rarity crates and the themed crates in `Stand.Themed` (there
  isn't room for all 30) on plinths with an "Open" prompt. Each prompt sits on
  an invisible part tagged `CrateDisplay` with the attribute `CrateId`: move or copy them in
  Studio, or tag any part of your own. Your own crate look: a model named after the crate's Id
  (e.g. `PumpkinCrate`) in `ReplicatedStorage > Custom > Props`. It shows on the stand and in the crate panel, sized by its longest side (a long coffin stays on its plinth; a model you stood upright stays upright). With a Toolbox code: `require(game.ServerScriptService.Server.Tools.Swap).Toolbox("PumpkinCrate", 5420577601)`. Its front is its pivot's front (turn the pivot if it shows its side).
- **How each crate looks** (`LookDefaults` and each crate's `Look` in `Crates.luau`): `Style` is the
  chest's shape: `Pumpkin` (carved pumpkin, leafy lid), `Candy` (wrapped candy box with a bow),
  `Coffin` (a ghost peeks out), `Tomb` (mossy tombstone chest), `Monster` (furry, googly eyes that
  follow players, teeth), `Moon` (starry, crescent moon) or `Chest` with an `Emblem` on the front
  (a head piece name like `WolfHead`, or `Gem`). Colours are the crate's `Color`, `Trim`, `Glow`
  and the Look's `Accent`. `Bob`, `Sway`, `PeekEvery`, `PeekAngle`, `Shake`, `Sparkles` and
  `Sounds` (`SoundId = ""` = silent) tune how it moves; give one crate its own value to change only
  that one. `New = true` puts a NEW ribbon on its card.
- **The stand comes alive** (`Idle`, client side, only crates near the camera; phones get fewer
  sparkles and a shorter range): crates bob and sway, the lid peeks open every few seconds with a
  puff of light and sparkles, a soft ring glows under each one, and when you walk close
  (`WakeDistance`) the nearest crate wiggles and shows its name, price and an Odds button that
  opens its page. `Stand.LightBrightness` is the light under each crate.
- **Opening** (`Opening`): the chest drops in and bounces, shakes faster and faster
  (`ShakeSeconds`), then the lid bursts open with a beam in the colour of the rarity you really
  won (`BeamColors`; CRAZY is a rainbow) and the skin flies out onto a spinning pedestal before the
  reveal card. The beam is a soft fan of light pouring out of the chest with rays turning behind
  it and a white flash at the burst: `Opening.Beam` (`Height`, `Width`, `Shafts`, `Spread`,
  `Shimmer`, `Rays`, `RaySpeed`, `FlashSeconds`...). CRAZY: a full-screen rainbow burst, confetti and `Sounds.CrazyBurst`. A duplicate:
  coins pour out with "+X coins back". Space or a tap skips; Quick open shows everything at once.
  `Style = "Reel"` brings back the old spinning strip. `CameraDistance` = how big the chest looks.
- **Your own crate model** still works everywhere: it bobs, sways and shakes, and its lid opens only
  if it has a part named `Lid` (the stand's built chests all have one).
- **Fair to players (kids)**: the beam, the reel and the reveal always show the server's real
  result; on the reel the cards next to yours (`Opening.TeaseGuard`) never show a rarer skin than
  the one you won, so there are no teasing near misses; no countdowns or "only X left"; the odds are
  one tap away on every card and on the stand.
- **Test it**: F8 > "Crates: open free Pumpkin Crate", "Crates: open free CRAZY Crate" (the CRAZY celebration) and "Crates: +100k coins". Which crate the free button opens: `Admin.FreeCrate`. To see what players in a blocked region see, set `Policy.TestAsRestricted = true` (Studio only).
- Or ask Claude Code: `/add-crate a Witchy crate with 20 new skins`.

**Roblox's rule for paid random items (please keep it):** players must see every item and its
exact chance *before* they pay (the crate panel always shows them), and players whose region
doesn't allow paid random items (Roblox tells the game through `PolicyService`) can't open any
crate, not even with coins (coins can be bought with Robux). They see "Crates aren't available in
your region; you can still buy any skin directly in the Shop", and every crate skin stays for
sale in the Shop at its rarity price. If Roblox can't answer, crates stay closed for that player
(in Studio they stay open so you can test; set `Policy.TestAsRestricted = true` to see what those
players see). If such a player still buys a Robux crate somehow, they get its coin price instead.

---

## Modes and playlists
A **mode** is a way to play: King Hunt, Pumpkin Hide & Seek or ScareMaze. A **playlist** is one mode on one map ("Hide & Seek: Hedge Maze"). The vote before each round offers playlists, never bare maps. Everything is in `src/shared/Config/Modes.luau`:
- `VoteChoices`: how many playlists the vote offers (3), picked at random from the ones that fit.
- `List`: one block per mode. `Name` and `Description` are what players see, `MinPlayers` is the fewest ready players it works with, `Feature` is its switch in `Features.luau`.
- `Playlists`: one block per mode + map pair. `Id` (never rename once live), `Mode`, `Map` (an Id from `Config.Maps.List`), `Name` (the vote button) and an optional `MinPlayers` if that map needs more players.
- **Take a playlist out of the vote:** delete its block. **Take a whole mode out:** switch it off in `Features.luau` (`HideSeek = false`).
- **Put a map in another mode:** add a playlist with that `Mode` and `Map`, and add the mode to the `Modes` list in the map's file (`src/shared/Config/Maps/<Id>.luau`). The map needs that mode's tagged parts (see "Maps" below). Or ask Claude Code: `/new-playlist Hide & Seek on the Spooky Mansion`.
- **Test one mode alone:** in a Studio playtest, F8 > "<mode>: force next round" (works with any number of players), then step on the Ready pad.
- Each mode's rules have their own file: `Config/HideSeek.luau` (head start, seeker share, giggles, glow, candy gun, coins) and `Config/ScareMaze.luau` (time, stop rule, Haunter share, BOO, scares, coins). King Hunt uses `Config.Round`, `Config.King`, `Config.Monsters` and `Config.Rewards` in `init.luau`.
- A brand new mode needs code (`src/server/Modes/<Id>.luau`): ask Claude Code.

---

## Maps
Each map is built from code in `src/server/Maps/` until you give it a hand-made version. To use your own:
1. Build the map as one Model. It needs:
   - a Part named **Floor** (the main ground; pumpkins and monsters spawn on it),
   - a Folder named **Spawns** with a few Parts where players start,
   - optional: a Folder named **Hotspots** with Parts marking risky pumpkin areas.
2. Name the model after the map's Id (`PumpkinPatch`, `SpookyMansion`, ...) and put it in `ServerStorage > Maps`.
3. Save and play. That map loads instead of the generated one.

Easiest start: let the game build its own map into `ServerStorage > Maps` for you and edit that (see [Editing the lobby and maps by hand](#editing-the-lobby-and-maps-by-hand)).

**Add a new map** (or ask Claude with `/add-map`):
1. Copy one of the files in `src/shared/Config/Maps/` (e.g. `PumpkinPatch.luau`) and rename the copy after your map's Id (e.g. `GhostTown.luau`). In it, change `Id` (the same as the file name), `Name`, `Lighting` and `AmbientSound`, and set `Modes` to the game modes it is for (`"KingHunt"`, `"HideSeek"`, `"ScareMaze"`). Leave `Builder` pointing at the builder of a map like yours: it is only used when there is no model.
2. Add it to `Config.Maps.List` in `src/shared/Config/init.luau`: one more line like `require(script.Maps.GhostTown) :: any,`.
3. Add a playlist for it in `src/shared/Config/Modes.luau` > `Playlists`: `{ Id = "KingHuntGhostTown", Mode = "KingHunt", Map = "GhostTown", Name = "King Hunt: Ghost Town" },`. The vote only offers playlists, and the button shows the playlist's `Name`.
4. Build the map as described above, name the Model after the Id and put it in `ServerStorage > Maps`. Besides `Floor` and `Spawns`, the other modes use tagged parts: a ScareMaze map needs at least one part tagged `MazeExit` (where Survivors escape) and can have `SurvivorSpawn`, `HauntSpawn` and `ScareTrigger`; a Hide & Seek map can have `SeekerSpawn`, `HiderSpawn`, `HidingDecoy` and `SeekerDoor`. Without the spawn tags everyone starts at `Spawns`. What each tag needs is at the top of `src/shared/Tags.luau`.

---

## The Ready pad
Players stand on the Ready pad (the glowing rune circle in front of the spawn) to join the next round. Nobody else is pulled in.
- **Rules:** `src/shared/Config/Lobby.luau` > `Ready`. `MinReady` = how many ready players start the vote (now 1; never fewer than the switched-on modes need). `VoteOnlyReady` = only ready players can vote. `LeaveGraceSeconds` = a wobble or jump off the pad doesn't un-ready you. `PadText` and `Text` = the words.
- **Look:** `Config.Hub.ReadyArea` in `init.luau` (size, runes colour, standing stones, arch, "PLAY!" banner, the floating "READY x / y" sign).
- **Move it:** change `Config.Lobby.Zones.ReadyArea` and rebuild the lobby. Or, in a baked lobby, move the whole area: in the Explorer open the `ReadyArea` folder, click its first child, Shift+click its last child, then drag (or move just the pad, the part tagged `ReadyPad`).
- **A second pad:** select the pad and press Ctrl+D. Any part tagged `ReadyPad` counts, square or round, and a tagged Model counts as its whole box.
- **Switch it off** (`ReadyPad = false` in `Features.luau`) and everyone in the lobby plays every round, like before v2.
- If there is no part tagged `ReadyPad` at all, everyone counts as ready (the Output window says so) and the game puts a pad back the next time it starts.

---

## Parkour jumps
The "Spooky Sky Climb" behind the clock tower. Settings: `src/shared/Config/Parkour.luau`.
- **The climb:** about 60 jumps in 8 themed stages (Pumpkin Hop, Broomstick Bridge, Graveyard Steps, Candy Sky, Bat Wings, Crypt Lids, Lantern Leap, Moonlight Summit), spiralling up round the parkour zone. It starts super easy and the top is only a little trickier (slightly smaller pieces, slightly longer gaps). Each stage starts at a checkpoint (7 in all), so a fall only costs you that stage: falling to the ground, onto a lower lap (`FallBelowCheckpoint` studs under your checkpoint), onto the START pad or into slime sends you back to your last checkpoint. "Go to start" in Menu > Parkour starts again from the bottom.
- **Coins and times:** `Reward.Coins` (300), `Reward.CooldownHours` (20), `MinSeconds` (45: a faster finish doesn't count). These work straight away, also in a saved lobby.
- **The course** is the `Course` list near the top: one line per piece, in climbing order. `Kind` is `Start`, `Pumpkin`, `Grave`, `Broom`, `Candy`, `Bat`, `Platform`, `Checkpoint`, `Finish` or `Hazard` (green slime). `Offset = Vector3.new(right, up, back)` is where the top of the piece is, in studs from the middle of the parkour zone, seen from the plaza. Optional: `Size`, `Rotation`, `Spicy = true` (a harder jump is allowed), `Label` (a checkpoint's stage name) and `Text` (words on a gravestone).
- **Add a jump:** copy a line, paste it where it goes in the order and change its `Offset`. Keep `Start` first and `Finish` last. The Output window warns about any jump that is too far or too high for a normal player (limits in `Jumps`: 9 studs across and 5 up; 10 and 5.5 for a Spicy one), and about any piece hanging too low over a jump (`Jumps.Headroom`, 12.5 studs: a jump goes about 7 studs up and a character is 5 tall, so on a spiral each lap must climb high enough; the solid bits under a piece count too, `Hang`). `lune run tests/run -- parkour` checks every jump too.
- **Solid pieces:** everything on the course you can see and bump into is solid: gravestones with their foot and dirt mound, crypt lids, broom handles, bands and straws, candies and their wrappers, bat bodies, heads, ears and wings, the finish island and the trophy. Only glow, words (plaques, signs), moss, flat painted details, slime and effects are walk-through. The parkour course is in `Config.Lobby.Solid.KeepAreas`, so the lobby's solid pass leaves it alone: it is built solid in `src/server/Hub/Sections/Parkour.luau`. A pumpkin's round body is only a look (it can be your own `ParkourPumpkin` model), so an invisible solid `Core` inside it is what you bump into. Solid bits hanging under a piece (the bat's body, the rock island under the finish: `Look.Island`) are listed in `Hang` so the head-room check counts them; `lune run tests/run -- parkour` checks both rules.
- **See it:** F8 > Rebuild hub tries it in a playtest. To keep it, run `Bake.Hub()` in edit mode (or `Bake.Hub(true)` for a Locked lobby) or raise `Config.Hub.BuildVersion`.
- **Or move pieces by hand** in a baked lobby (`Workspace.Hub.Parkour`): the game finds the working parts by tag, not by name or place. `ParkourStart` (start pad), `ParkourCheckpoint` with the attribute `Index` = 1, 2, 3 in climbing order, `ParkourFinish` (the trophy), `ParkourHazard` (slime), `ParkourBoard` (best times). The jumps in between are just parts: move, copy or delete them freely.
- **Celebrations** (also in the Tormented Tower): `Effects` (sparkles bursting from each checkpoint, fireworks and confetti at the finish, a big "NEW BEST!" for a new best time, a little swell of the timer each second; `On = false` turns them off).
- Or ask Claude Code: `/add-parkour-jump a spooky ghost platform after the second checkpoint`.

---

## Tormented Tower
A REALLY hard climb inside the crooked clock tower, for the bravest players. Settings: `src/shared/Config/TowerParkour.luau` (on/off: `Config.Features.TowerParkour`).
- **The climb:** walk in through the doorway (the glowing "TORMENTED TOWER - only the bravest" sign is in front of it), stand on START and climb about 24 hard jumps to the clock face: tiny posts, narrow beams, trusses to climb, platforms that vanish (they flicker red first), spinning bars that knock you off, turning cogs you ride, slime that sends you back, and two long jumps you can only make sprinting (hold Shift, or the sprint button on phones). Only 3 checkpoints. Falling sends you back to your last checkpoint (or the start).
- **The prize:** the first time you beat it you win the **Tormented Soul** skin (CRAZY, with its own animated effect: swirling ghostly chains and red lightning). It is never sold in the shop and is in no crate. Every finish tells the whole server "<name> conquered the Tormented Tower!". Your best time is saved. A Roblox badge: put its id in `Reward.BadgeId` (Creator Hub > your game > Badges; `0` = no badge).
- **Change the course:** the `Course` list at the top. Same idea as the lobby parkour: one line per piece, `Kind` (`Start`, `Ledge`, `Tiny`, `Beam`, `Truss`, `Vanish`, `Spinner`, `Gear`, `Checkpoint`, `Finish`, `Hazard`), `Offset = Vector3.new(right, up, back)` inside the tower (it follows each floor's lean and twist), `Sprint = true` for a jump that needs sprinting. The game checks every jump with the parkour jump maths, including how a piece hanging low over a jump cuts it short; the Output window warns about a problem, and `lune run tests/run -- tower` checks it too.
- **Tweak:** sizes (`Sizes`), how hard jumps may be (`Jumps`), vanishing timings (`Vanish`), spinner and cog speeds (`Spinner`, `Gear`), the minimum time (`MinSeconds`), colours (`Look.Colors`), walls, doorway, lanterns and the window behind the clock face (`Walls`), the skin's look (`Skin`), all the words (`Text`). The skin's effect numbers are in `Config.Skins.Effects.Special.Torment`.
- **The tower itself** is `Config.Hub.ClockTower` (now 7 floors and 22 studs wide, so the climb fits inside). It is hollow while the Tormented Tower is on. Move or resize it there and the course follows (raise `Config.Hub.BuildVersion`).
- **Your own ClockTower model** (`ReplicatedStorage.Custom.Props.ClockTower`) works too: any part of it inside the tower's hollow middle or its doorway stops being solid when the game starts, and plain inner walls are built so the inside still looks like a tower. Leave a doorway gap at the front (the side facing the middle of the lobby), or players walk through your wall there.
- **In Studio:** the pieces are in `Workspace.Hub.TowerParkour.Course`, found by tag: `TowerStart`, `TowerCheckpoint` (attribute `Index` = 1, 2, 3), `TowerFinish`, `TowerHazard`, `TowerVanish` (attribute `Phase`), `TowerSpinner`, `TowerGear`. Spinning bars and cogs turn on a motor (`HingeConstraint`).
- **Test (F8):** "Tower: teleport to start", "Tower: teleport to checkpoint 1/2/3" (with the clock running), "Tower: reset my progress" (best time, finishes and the skin, so you can win it again). Menu > Tormented Tower shows your best time and a "Go to the tower" button.

---

## Candy Rush
The candy stand on the west side of the lobby. Settings: `src/shared/Config/CandyRush.luau`.
- **The race:** `Candies` (10 to win), `MinPlayers` (2), `CountdownSeconds`, `MaxRaceSeconds` (60).
- **Solo runs:** `Solo.On`, `Solo.AfterSeconds` (6 s alone on a pad).
- **Coins:** `Rewards.WinCoins` (25), `PlayCoins` (5), `SoloCoins` (5), `CooldownSeconds` (15), `DailyCap` (300 a day; 0 = no limit).
- **Looks and words:** `Candy`, `Stand`, `Text`, `Sounds`.
- **In Studio:** the stand is a Model tagged `CandyRushStation`; a copy of it is a second, separate race. The board is tagged `CandyRushBoard`. Each pad is tagged `CandyRushPad` with the attribute `Lane` (1 = the left column of the board as you look at it). Move or resize them freely.
- Your own candies: models named `CandyRushWrapped`, `CandyRushLollipop`, `CandyRushCandyCorn` in `Custom > Props`.
- **Celebrations:** `Effects` (sparkles and "+1" when the server counts your grab, sliding lane bars, the punchy 3-2-1-GO, confetti when you win; `On = false` turns them off). Grabs are sent the moment you click either way.
- Test alone: F8 > "Candy Rush: start solo test".

---

## Web Scour
The Spider Grove scavenger hunt. Settings: `src/shared/Config/WebScour.luau`.
- **The game:** `Critters` (6 to find), `TimeLimit` (45 s), `MaxReach` (how close you must be to click one).
- **Coins:** `CoinsPerCritter` (2), `FinishCoins` (20), `TimeBonusPerSecond` (0.5), `MaxCoins` (50), `RewardCooldown` (180 s between paid hunts, saved per player).
- **The critters** are cute cartoon spiders, each a random bright colour from `CritterColors` (add, remove or change colours; the names are only labels).
- **Where they hide:** every web lists its hiding spots as clock hours (`Grove.Webs[...].Spots`, 12 = top, 3 = right; halves like 1.5 work). Each spot snaps to the nearest knot where a ring thread crosses a spoke (`SpotDistance` = how far out), so every spider sits on a strand, never on the floor or a tree. 16 spots in all.
- **Looks and words:** `Grove` (trees, webs, lantern, spider, colours), `Text`, `Sounds`.
- **In Studio:** the lantern is the part tagged `WebScourStart` (your own lantern model works too: tag the Model). The hiding spots are invisible parts tagged `WebScourSpot`: move, copy or delete them (keep them on a web). Delete the lantern and a new one is put back; the rest of the grove stays as you left it.
- **Celebrations:** `Effects` (critters hop now and then, "+1" per catch, a bar that drains with the real time left and a calm once-a-second pulse in the last `HintLastSeconds`, coins counting up and confetti when you find them all; `On = false` turns them off).
- Test: F8 > "Web Scour: start".

---

## Photo Spot dances
At the Photo Spot ("Strike a pose") a bar of spooky, silly dances opens: Zombie Shuffle, Skeleton Rattle, Ghost Float, Pumpkin Head Spin, Monster Mash, Bat Flap, Scaredy Cat Shiver, Witchy Cackle, Mummy Wobble and Spooky Floss. Everyone sees you dance; walking or jumping stops it. Settings: `src/shared/Config/Dances.luau` (on/off: `Config.Features.Dances`).
- **Why not Roblox emotes or animations?** Roblox only plays animations owned by the game's creator, so these dances are made in code (`src/shared/DanceMoves.luau`): the server checks you're at the Photo Spot and sets the `Dance` attribute on your character, and every player's screen moves that character's joints. They work on R15 and R6 avatars.
- **Change the buttons:** `List` (one line per dance; the order is the button order), `Label` = the words on the button, `StopLabel`, `Columns` (buttons per row).
- **Use your own animation:** upload it to Roblox under the game's owner, then put its id in that dance's `AnimationId` (`"rbxassetid://123..."`). It plays instead of the code dance. `""` = the code dance.
- **Tweak:** `Speed` (all code dances), `Cooldown` (seconds between changes), `MaxDrift` (studs you can drift before the dance stops). The Photo Spot itself is tagged `PhotoSpot`; dancing only starts within `Config.Hub.PhotoSpot.CloseDistance` of it.

---

## Floor signs
A flat pad on the ground in front of each lobby area with big glowing words: READY? STEP IN!, PUMPKIN SHOP, MYSTERY CRATES, CANDY RUSH, WEB SCOUR, PARKOUR. Settings: `Config.Lobby.FloorSigns` (`src/shared/Config/Lobby.luau`).
- **Words and colours:** each area's line in `Signs` (`Text`, `Color`). Size, glow, font and the pad colour are at the top of the block.
- **Where:** by default a sign lies in front of its area (`Side = "Front"`, `Gap` studs out). Give it its own spot with `Offset` (studs from the middle of the lobby) and `LookAt` (where its words face), and its own `Width`.
- **In Studio:** each pad is its own part named `<Area>FloorSign` (for example `ShopFloorSign`), tagged `FloorSign` with the attribute `Zone`. Move, turn or resize it freely in a baked lobby. A switched-off area's sign is taken out of the running game.

---

## A solid lobby
When the game starts, every decoration you would expect to bump into or stand on is made solid: trees, lampposts, benches, gravestones, crates, barrels, hay, fences, statues, the cauldron, stalls, stands, rocks, big pumpkins, scarecrows, and your own models from `ReplicatedStorage.Custom.Props`. Settings: `Config.Lobby.Solid` (`src/shared/Config/Lobby.luau`; the code is `src/server/Hub/HubSolid.luau`).
- **What stays walk-through:** tiny ground clutter (pieces under `MinSize` studs, or no higher than `StepHeight` above the ground: leaves, path stones, small candles), see-through pieces (`MaxTransparency`), the glowing floor signs, the working parts (pads, prompts, hitboxes), anything named in `KeepWalkThrough` and everything inside a Model named in `KeepAreas` (the Web Scour webs, mist, fireflies... and the parkour course, which its own code builds solid: see [Parkour](#parkour-jumps)).
- **Your own models:** their parts become solid the same way. Roblox doesn't let scripts change `CollisionFidelity`, so for a MeshPart set it yourself in Studio (select the MeshPart > Properties > CollisionFidelity: `Hull` for round things, `Box` for boxy ones, `PreciseConvexDecomposition` if players must walk inside it).
- **Something blocks a path?** Add its name to `KeepWalkThrough`, or switch the whole thing off with `On = false`.

---

## Secret pumpkins (Easter eggs)
Hidden pumpkins, candies, skulls and ghosts around the lobby. Each pays its coins once per player, ever. Settings: `src/shared/Config/EasterEggs.luau`.
- **Change coins or riddles:** each egg's `Coins` and `Hint` in `List`. Works straight away, also in a saved lobby.
- **Add an egg:** copy a line in `List` and give it:
  - a new `Id` (saved in players' data: never rename or reuse one that is live), a `Name` and a `Hint` (the riddle in Menu > Secret Pumpkins),
  - a `Look`: `GoldenPumpkin`, `Candy`, `Lollipop`, `Skull` or `Ghost`,
  - an `Anchor`, what it hides next to: a tag name (`ShopKeeper`, `ReadyPad`, `ParkourFinish`...), an NPC Id (`VotingBoard`, `Leaderboard`, `PhotoSpot`), a lobby zone (`Shop`, `WebScour`...), a landmark (`ClockTower`, `PumpkinPatch`, `Mansion`, `KingStatue`, `Graveyard`) or `Hub` (the middle),
  - an `Offset = Vector3.new(right, up, back)` from that anchor.
  New eggs appear the next time the game starts, also in a saved lobby.
- **Or place one by hand:** give any part the tag `EasterEgg` and the attributes `EggId` (text) and `Coins` (number). An `EggId` from the list pays the list's coins.
- **Move one:** drag it in a baked lobby (`Workspace.Hub.EasterEggs`).
- Your own egg look: a model named `EggGoldenPumpkin` (or `EggCandy`, `EggLollipop`, `EggSkull`, `EggGhost`) in `Custom > Props`. For **one egg only**, name it `Egg` + the egg's Id (e.g. `EggForestGhost`, Ids in `Config.EasterEggs.List`), or with a Toolbox code: `require(game.ServerScriptService.Server.Tools.Swap).Egg("ForestGhost", 15145049241)` (rebuilds that egg in the lobby; save after).
- **Celebrations:** `Effects` (sparkles at the egg, a toast that slides in with its coins counting up, a shine over found eggs in Menu > Secret Pumpkins; `On = false` turns them off).
- Test: F8 > "Easter eggs: reset mine" lets you find them all again.
- Or ask Claude Code: `/add-secret-pumpkin a candy skull on top of the clock tower, 75 coins`.

---

## Menu tiles
The orange **Menu** button at the top left (key **M**) opens a grid of tiles. Settings: `src/shared/Config/Menu.luau`.
- **Order:** move a line up or down in `Tiles`.
- **Words, picture, colour:** each tile's `Text`, `Icon` (any emoji) and `Color`.
- **Hide a tile:** add `Hidden = true` to its line. Don't change a tile's `Id`: the code finds tiles by Id.
- `Feature = "Crates"` means the tile only shows while that feature is on.
- The button itself: `ButtonText`, `Key`, and `Button` (size, colour; `InTopBar = true` puts it in Roblox's own top bar).
- Switch the whole Menu off (`Menu = false` in `Features.luau`) and the old column of Shop / Codes / Invite / Settings buttons comes back.
- Only one panel is open at a time; Escape closes it, and every open panel (Shop, Crates...) closes by itself when a round pulls you in, so nothing covers the start of the round.
- A tile that opens something new needs a little code (`MenuUI.AddTile`): ask Claude Code.

---

## The hub
`Config.Hub` controls the plaza size, colours, lighting, decorations and music (the Photo Spot's dances are in `Config.Dances`). After changing it, try it with F8 > **Rebuild hub** (that playtest only). To make it stick, raise `Config.Hub.BuildVersion` by one: the next time the game starts, a saved hub with a lower number is rebuilt (unless it is Locked, see below).

What's where (positions are studs from the middle: x = east/west, z = south/north):
- `Spawn`: the round stone players appear on (south), and the spot they look at (`LookAt`).
- `ReadyArea`: the glowing rune circle, its standing stones, the pumpkin arch, the "PLAY!" banner and the floating READY sign (`Sign`; it hides while your camera is within `Sign.HideNear` studs of it, so it never hangs cut off over the top of the screen). Move the circle with `Config.Lobby.Zones.ReadyArea`.
- `ShopStall`: the big "PUMPKIN SHOP" sign, the chalkboard, how many goodies sit on the shelves.
- `Plaza`: the promenade ring round the cauldron, path width, cracks, puddles, fallen leaves.
- `Signposts`: which areas get paths and signs, and what the signs say (only while that area's switch in `Config.Features` is on).
- `ClockTower`, `Cauldron`, `Lampposts`, `Bunting`, `JackOLanterns`, `Candles`, `Benches`, `Graveyard`, `DeadTrees`, `Clutter`, `Polish` (terrain, forest, mansion, statue, pumpkin patch, fence): one block each, with a comment on every number.
- `Budget`: the most parts and lights the whole lobby should have, so it stays smooth on phones (the tests check it).

**Lighting (do this once):** select **Lighting** in the Explorer and set **Technology** to **Future** in the Properties window. Scripts are not allowed to change it, and it makes the lamps, lanterns and candles glow with soft light. Everything else (sky with a big moon and stars, clouds, haze, colours, bloom, depth of field) comes from `Config.Hub.Lighting`.

---

## Editing the lobby and maps by hand

The lobby ("Spooky Town Square", `Workspace.Hub`) and the round maps are built by code, but you can turn them into real parts in your place and change anything by hand in Studio: move, resize, recolour, delete or add parts.

### How the game treats the lobby saved in your place
- When you press Play, the game uses the `Workspace.Hub` saved in your place, as it is.
- **BuildVersion.** Every lobby built by the game has the attribute `BuildVersion` (select `Workspace.Hub`, then Properties > Attributes). When the lobby code changes, `Config.Hub.BuildVersion` goes up. A saved lobby with a lower number (or none) is rebuilt from code automatically, and your changes to it are lost...
- **Locked.** ...unless you lock it. Add the attribute `Locked` (a boolean, ticked) to `Workspace.Hub`, or run `Bake.Lock()` (below). A Locked lobby is never rebuilt; if it is older than the code, the Output window says so and how to update it.
- **The game always puts back what it needs**, even in a Locked lobby: the spawn, the Ready pad and the Pumpkin Shop keeper. If one is missing, it is added for that server and the Output window tells you; run `Bake.Repair()` to add it to your place for good. Tagged pieces count wherever they are in Workspace, even if you dragged them out of `Workspace.Hub`. A lobby minigame that is switched on but missing (the parkour start pad, the Candy Rush stand, the Web Scour lantern) is also built for that server, with a message in the Output window.
- **What a saved lobby keeps.** Config changes to what a lobby area is *made of* (the parkour `Course`, the crate stand and its crate list, the Candy Rush stand or Spider Grove look, where an Easter egg hides) only show once the lobby is rebuilt (F8 > Rebuild hub to try, `Bake.Hub()` to keep). Rewards, prices, timings and words from Config work straight away, also in a saved or Locked lobby.
- **Switching a feature off** in `Config.Features` (Ready pad, Parkour, Candy Rush, Web Scour, Crates, Easter eggs) takes its pieces out of the running game; your saved place still has them, so switching it back on brings them back. Signposts and paths pointing there stay until the lobby is rebuilt.
- The old Witch Wanda and Boo Guide are removed from saved lobbies automatically.

### Step by step: edit the lobby
1. Stop the game (you must be in edit mode, not playing).
2. Open View > **Command Bar**.
3. Paste this and press Enter: `require(game.ServerScriptService.Server.Tools.Bake).Hub()`
   `Workspace.Hub` is (re)built from code. Ctrl+Z undoes it.
4. Edit it. In the Explorer it is sorted into **folders** with readable names, and every single thing in them (one pumpkin, one bench, one tree, one parkour step) is its own **Model**, so clicking it in the viewport selects just that thing (see "Move just one thing" below):
   - `Plaza` (the ground: `Ground`, the `Promenade` ring, the `Dais` the cauldron stands on, `Walkways`, `Curb` and small `Details` such as cracks, puddles and leaves), `Spawn`, `Npcs` (Voting Board, Leaderboard, Photo Spot),
   - one folder per lobby area: `ReadyArea`, `Shop` (with the `PumpkinVendor` stall), `CrateStand`, `Parkour`, `TowerParkour`, `CandyRush`, `WebScour`, `EasterEggs`,
   - `Decor`: everything that is only for looks (`ClockTower`, `Cauldron`, `Lamps`, `PathLamps`, `Bunting`, `JackOLanterns`, `Candles`, `Benches`, `Graveyard`, `Trees`, `Clutter`, `Signposts`, `Forest`, `HauntedMansion`, `KingStatue`, `PumpkinPatch`, `OldGraves`, `Fence`, `Paths`, `Ambience`). Delete or move any of it freely.
5. Lock it: `require(game.ServerScriptService.Server.Tools.Bake).Lock()`
6. Save the place (Ctrl+S). Your lobby lives in the place file, not in git, so keep a backup: right-click `Workspace.Hub` > **Save to File...**

### Move just one thing
1. Do steps 1 to 3 and 5 above once (bake and lock the lobby), so the game keeps your changes.
2. Click the thing in the viewport, e.g. one pumpkin. Only that pumpkin is selected (blue box round it). To pick a single part of something (one plank of a bench), hold **Alt** while you click.
3. Move it with the **Move** tool (Model tab > Move, or Ctrl+2) by dragging the arrows; **Rotate** (Ctrl+3) and **Scale** (Ctrl+4) work the same way. Every other pumpkin stays where it is.
4. Copy it with **Ctrl+D**, delete it with **Delete**.
5. Save the place (**Ctrl+S**).

To give that one thing a different look, see [With a Toolbox code](#with-a-toolbox-code-one-line-no-dragging) (`Swap.Selected`).

A lobby saved before version 9 had all of it grouped in Models, so a click selected the whole lobby: run `Bake.Hub(true)` once to get the new layout (your hand edits are replaced; the old lobby is kept in `ServerStorage > HubBackup`).

More command bar helpers (each one starts with `require(game.ServerScriptService.Server.Tools.Bake)`):

| Add this | What it does |
| --- | --- |
| `.Hub()` | Builds the lobby from code (refuses if it is Locked) |
| `.Hub(true)` | Rebuilds even a Locked lobby; the old one is kept as `ServerStorage > HubBackup` |
| `.Lock()` / `.Unlock()` | Never rebuild it / rebuild it again when the code changes |
| `.Repair()` | Adds back a missing spawn, Ready pad or shopkeeper |
| `.Repaint()` | Paints every part again from the palette (below) |
| `.Map("PumpkinPatch")` | Copies a round map into `ServerStorage > Maps` for editing (below) |
| `.AllMaps()` | The same for every map |

### Parts that do something: tags
The game finds the parts that *do* something by their **tag**, not their name or position. So you can move, resize, recolour or copy them, and they keep working. See a part's tags in Properties > Tags (at the bottom), or View > Tag Editor.

| Tag | What it does | Tips |
| --- | --- | --- |
| `ReadyPad` | Players standing on it join the next round | The round stone in `ReadyArea` (square or round pads both work, and a tagged Model counts as its whole box). Ctrl+D a copy to make a second pad. The glowing runes on top are just decoration. |
| `ReadySign` | Shows "READY 2 / 4" and what the round is doing | An invisible part in `ReadyArea` holding the floating sign. Move it anywhere. |
| `HubSpawn` | Where players appear in the lobby and come back after a round | The `Spawn` pad. Your own SpawnLocation (Model > Spawn) works too: tag it `HubSpawn`, otherwise the game switches it off so it doesn't compete with the lobby spawn. |
| `ShopKeeper` | Opens the Pumpkin Shop | On the `PumpkinVendor` stall. Tag **any** part or model `ShopKeeper`, anywhere in Workspace, and it opens the shop too (a "Shop" prompt is added). |

The v2 features add their own tags:

| Tag | What it does | Needs |
| --- | --- | --- |
| `CrateDisplay` | A crate on the stand: its prompt opens that crate. Tag any part or model to add one | attribute `CrateId` |
| `ParkourStart`, `ParkourFinish` | Parkour start pad, finish trophy | |
| `ParkourCheckpoint` | A parkour checkpoint | attribute `Index` (1, 2, 3 in climbing order) |
| `ParkourHazard` | Green slime: sends you back to your checkpoint | |
| `ParkourBoard` | The best-times board | |
| `CandyRushStation` | A whole Candy Rush stand (a copy is a second race) | |
| `CandyRushPad` | A Candy Rush join pad | attribute `Lane` (1, 2, 3...) |
| `CandyRushBoard` | The board candies pop up on | |
| `WebScourStart` | The Web Scour lantern | |
| `WebScourSpot` | A place a spider can hide (keep it on a web strand) | |
| `FloorSign` | A glowing sign on the ground in front of a lobby area (walk-through) | attribute `Zone` |
| `PhotoSpot` | The Photo Spot: dances only start near it | |
| `TowerStart`, `TowerFinish` | Tormented Tower start pad, finish | |
| `TowerCheckpoint` | A Tormented Tower checkpoint | attribute `Index` (1, 2, 3) |
| `TowerHazard` | Tower slime: back to your checkpoint | |
| `TowerVanish`, `TowerSpinner`, `TowerGear` | The tower's vanishing platforms, spinning bars, turning cogs | `TowerVanish`: attribute `Phase` (seconds its timer is shifted) |
| `EasterEgg` | A secret pumpkin | attributes `EggId`, `Coins` |
| `SeekerSpawn`, `HiderSpawn` | Hide & Seek start spots (maps) | |
| `HidingDecoy` | A decoy pumpkin; hiders copy its look | |
| `SeekerDoor` | The seeker hut door, opens when seekers are let out | |
| `SurvivorSpawn`, `HauntSpawn` | ScareMaze start spots | |
| `MazeExit` | Where ScareMaze Survivors escape | |
| `ScareTrigger` | A scare trap | attribute `Kind` (Scarecrow, Zombie, Bats, Ghost, Patrol) |

The full list, with notes, is at the top of `src/shared/Tags.luau`.

### Colours: the palette
The lobby's colours are in `Config.Hub.Palette` (the `hubPalette` list at the top of `src/shared/Config/init.luau`): `Ground`, `Stone`, `Wood`, `Iron`, `Bone`, `Orange`, `Purple`, `Green`, `Glow`, `Gold`, `Cloth`, `Straw`, `Dark`, `Teal` (the Ready runes, mushrooms), `Foliage` (tree leaves), `Path` (paths and the promenade).
- Each painted part has the attribute **PaletteRole** (which colour it uses) and sometimes **PaletteShade** (0.3 = 30% darker, -0.2 = 20% lighter).
- Change a colour in the palette and every part with that role follows the next time you press Play, even in a Locked lobby. To keep it in your place too, run `Bake.Repaint()` in edit mode and save.
- Recoloured one part by hand? It keeps your colour until you change that palette colour. To keep it for good, delete its `PaletteRole` attribute.
- To paint one of your own parts from the palette, give it a `PaletteRole` attribute (a string, e.g. `Wood`).

### Swap a decoration everywhere: props
Moved to its own section: [Swap every copy of something at once](#swap-every-copy-of-something-at-once). It works in a hand-edited (Locked) lobby and in baked maps too.

### Lobby areas (zones)
`Config.Lobby.Zones` (`src/shared/Config/Lobby.luau`) keeps one area of the lobby free for each thing. Decorations are never placed inside a zone.

| Zone | What goes there | Where now (`Offset`, studs from the middle) |
| --- | --- | --- |
| `ReadyArea` | The Ready circle, right in front of the spawn | (0, 46): south |
| `Shop` | The Pumpkin Shop stall | (40, -18): east |
| `Crates` | The Mystery Crates stand, next to the shop | (46, 6): east |
| `CandyRush` | The Candy Rush stand | (-60, 0): west |
| `WebScour` | The Spider Grove | (-38, -32): north-west |
| `Parkour` | The Spooky Sky Climb (76 wide, 120 tall) | (0, -86): north, behind the clock tower |

- `Offset = Vector3.new(x, 0, z)`: x = east (+) / west (-), z = south (+) / north (-). `Size` = width and depth.
- Each zone faces the middle of the lobby, so its front points at the plaza.
- **Move an area:** change its `Offset`, then rebuild (F8 > Rebuild hub to try it; `Bake.Hub()` in edit mode, or raise `Config.Hub.BuildVersion`, to keep it). The paths and signposts follow.
- In a baked lobby you can also move a whole area by hand. Each area is a **folder** (`Workspace.Hub.CandyRush` and so on), and a folder can't be dragged itself: in the Explorer open it, click its first child, Shift+click its last child, then drag them in the viewport. The working parts are found by tag, so they keep working.
- Or ask Claude Code: `/edit-lobby move Candy Rush closer to the spawn`.

### Round maps
1. In edit mode, run `require(game.ServerScriptService.Server.Tools.Bake).Map("PumpkinPatch")` (any Id from `Config.Maps.List`).
   The map appears in `ServerStorage > Maps > PumpkinPatch`. From now on, rounds on that map use this copy.
2. To edit it, drag it into **Workspace**. It sits far away from the lobby: select it and press **F** to fly the camera there.
3. Edit it. Keep exactly one part named **Floor** (the ground pumpkins and monsters stand on) and the **Spawns** folder (where players start); the **Hotspots** folder is optional.
4. Drag it back into `ServerStorage > Maps` and save the place.
5. Keep it in git: right-click it > **Save to File...** and save it as `new-game/maps/PumpkinPatch.rbxm` (the `maps/` folder is `ServerStorage > Maps`). Then, with Rojo connected, delete the copy in Studio so there is only one.
- Running `Map(...)` again keeps your previous copy as `PumpkinPatch_Backup`.
- Lighting and sounds still come from the map's file in `src/shared/Config/Maps/`; the name on the vote button comes from its playlist in `src/shared/Config/Modes.luau`.
- Want the code-built map back? Delete it from `ServerStorage > Maps`.

---

## Claude Code commands (type them in Claude Code)
| Command | What it does |
| --- | --- |
| `/verify-v2` | Studio test of every v2 feature (solo, 2 players, phones), then fixes, tests, commit and push |
| `/verify` | Shorter playtest pass of the whole game, then fixes |
| `/next-milestone` | Builds the next unfinished milestone in `docs/PROGRESS.md` |
| `/add-skin` | New crate skin in a theme file, with its rarity and look: `/add-skin <theme> <rarity> <what it looks like>` (moving pieces and a walk style too, if you ask) |
| `/animate-skin` | Makes a skin move: `/animate-skin <skin> <what should move>` (effects within its rarity's limit, a walk style for Rare and CRAZY), then tests, a catwalk picture when the preview tooling is there (the cloud session), and a Studio playtest |
| `/add-crate` | New crate: its skins, price, odds, stand display and Robux product |
| `/add-parkour-jump` | New jump (or stage) on the parkour course, checked against the jump limits |
| `/add-secret-pumpkin` | New hidden Easter egg with coins and a riddle |
| `/edit-lobby` | Bake, lock, move or repair the lobby, or move its tagged parts |
| `/new-playlist` | New mode + map pair in the vote |
| `/add-cosmetic` | New hat, pet, trail or skin. Describe it and it builds the look too |
| `/reskin` | Restyle a character or NPC (Part-built or from a model you name) |
| `/swap-prop` | Swap every copy of a prop (every pumpkin, lantern, tree...) for your model, also in a saved lobby and baked maps |
| `/add-npc` | New lobby NPC with dialogue and a prompt |
| `/add-monster` | New King Hunt minion type with behaviour and config |
| `/add-map` | New round map, built from code, in the existing style |
| `/new-code` | Adds a promo code with reward and expiry |
| `/new-event` | Limited-time event (double pumpkins, Blood Moon round, event cosmetics) |
| `/tweak` | Balance or tune anything from a plain-English request |
| `/polish-hub` | More detail and life in the lobby, within the phone budget |
| `/save-skins` | Puts the skins you saved in Skin Studio into the theme files through the Studio MCP, runs the tests, commits and pushes. Run it **before you press Stop** (`/save-skins Id,Id` saves only those) |

Each command reads `CLAUDE.md`, keeps numbers in Config, playtests in Studio when it can, runs the offline tests (`lune run tests/run`) and commits.
