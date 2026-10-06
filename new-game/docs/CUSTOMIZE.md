# Customise everything

The game is built so you can change almost anything without touching code. There are three layers:

| Layer | What it controls | Where | How hard |
| --- | --- | --- | --- |
| **1. Config** | Every number, name, price, colour, dialogue line, code, reward | `src/shared/Config/` (`init.luau` plus one file per v2 feature) | Edit text, save. Rojo syncs it live. |
| **2. Custom models** | How every character, NPC, hat, pet and skin *looks* | Studio: `ReplicatedStorage > Custom` | Build or import a model, give it the right name. |
| **3. Code** | New behaviour (a new monster, mode, item type) | `src/` | Ask Claude Code with a slash command (bottom of this page). |

Test anything fast in a Studio playtest with **F8** (admin panel; phones get an Admin button at the top right): + Coins, Unlock all items, Reset daily reward, **Rebuild hub**, **Repaint hub**, Reset my save, Start round now, Force mode, plus buttons the v2 features add (parkour, Candy Rush, Web Scour, Easter eggs, crates). It only works in Studio unless you turn it on for live servers (`Config.Admin`).

Every v2 feature has an on/off switch in `src/shared/Config/Features.luau`. New to v2? Start with [`docs/V2-CHANGES.md`](V2-CHANGES.md).

Want to move, recolour or rebuild the lobby or a map **by hand** in Studio? See [Editing the lobby and maps by hand](#editing-the-lobby-and-maps-by-hand).

Jump to: [Skins](#crate-skins-add-or-change-a-skin) · [Crates](#crates) · [Modes and playlists](#modes-and-playlists) · [Maps](#maps) · [Ready pad](#the-ready-pad) · [Parkour](#parkour-jumps) · [Candy Rush](#candy-rush) · [Web Scour](#web-scour) · [Secret pumpkins](#secret-pumpkins-easter-eggs) · [Menu](#menu-tiles) · [Lobby zones](#lobby-areas-zones) · [Props](#swap-a-decoration-everywhere-props) · [Tags](#parts-that-do-something-tags)

---

## Quick "I want to change..." table

| I want to change... | Edit |
| --- | --- |
| Game name on the HUD | `Config.Game.Name` (the Roblox page name is set in Creator Hub) |
| Round length, intermission, results time | `Config.Round` |
| Results screen timings, text, colours | `Config.Results` |
| "RUN!", heartbeat warning, +1 pop-ups, last-30-seconds, survivors-left | `Config.Juice` |
| Coins per pumpkin, survivor bonus | `Config.Rewards` |
| Easy/Hard pumpkins, reward multiplier | `Config.Difficulty.Levels` |
| King speed, hearing, sight, how many Kings | `Config.King.Difficulty` |
| How loud sprinting/shouting/talking is to the King | `Config.King.Noise`, `Config.Voice.Noise` |
| Skeletons, bats, ghost cats (count, speed, damage, messages) | `Config.Monsters` |
| Player walk/sprint speed | `Config.Player` |
| Ghost mode rules (fly speed, haunt) | `Config.Ghost` |
| Voice range and echo | `Config.Voice` |
| Turn any v2 feature on or off | `src/shared/Config/Features.luau` (one `true`/`false` line each) |
| Hub layout, lighting, music, decorations | `Config.Hub` (then F8 > Rebuild hub to try it, and raise `Config.Hub.BuildVersion` so saved hubs update) |
| Hub colours | `Config.Hub.Palette` (the `hubPalette` list at the top of `Config/init.luau`) |
| Where the Ready pad, shop, crate stand, minigames and parkour go | `Config.Lobby.Zones` (`src/shared/Config/Lobby.luau`) |
| Ready pad rules: players needed, who can vote, words | `Config.Lobby.Ready` (`src/shared/Config/Lobby.luau`) |
| Ready pad look and sign text | `Config.Hub.ReadyArea` |
| Watching the round from the lobby | `Config.Lobby.Spectate` |
| Hub terrain, forest, mansion, statue, fence, glowing paths | `Config.Hub.Polish` (same rebuild) |
| NPC names, positions, dialogue | `Config.Npcs.List` |
| Shop items (hats, trails, pets, classic skins) | `Config.Shop.Items` |
| Crate skins (120, six themes) | `src/shared/Config/Skins/<Theme>.luau` (see "Crate skins" below) |
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
| Secret pumpkins (Easter eggs) | `src/shared/Config/EasterEggs.luau` |
| Sound effects (clicks, pickups, King footsteps, minions, rewards) | `Config.Sounds` (SoundId "" = silent) |
| Hub music, King roar | `Config.Hub.Music`, `Config.King.Heard.RoarSoundId` |
| UI colours and font | `src/client/Theme.luau` |
| UI size on big screens, phone layout | `Config.UI` |
| Top-left Menu: its button, tile order, words, icons, colours | `Config.Menu` (`src/shared/Config/Menu.luau`) |
| Character/NPC/hat/pet/skin looks | A model in `ReplicatedStorage > Custom` (below) |
| A whole map | A model in `ServerStorage > Maps` (below) |
| One decoration everywhere (every jack-o-lantern, lamp, tree...) | A model in `ReplicatedStorage > Custom > Props` (below) |

Colours in Config are `Color3.fromRGB(red, green, blue)`, each 0-255. Pick them in any colour picker.
Sounds are `"rbxassetid://NUMBER"` from the Creator Store (Toolbox > Audio). Empty `""` means no sound.

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
The 120 crate skins live in `src/shared/Config/Skins/`, one file per theme: `Pumpkin.luau`, `Candy.luau`, `Spooky.luau`, `Graveyard.luau`, `Monster.luau`, `Moonlight.luau`. Each has 20 skins: 12 Common, 5 Uncommon, 2 Rare and 1 CRAZY. Every style option (colours, materials, patterns, head pieces, glow, auras, CRAZY effects) is explained at the top of `Pumpkin.luau`.

**Add a skin:**
1. Open the theme file, e.g. `src/shared/Config/Skins/Candy.luau`.
2. Copy one whole skin block (from `{` to `},`) of the rarity you want and paste it below.
3. Give it a new `Id` that starts with the theme (`Candy_BubbleGum`) and a `Name`.
4. Set its `Rarity` and change its `Style` colours.
5. Save. It is in the Shop (at its rarity price) and in that theme's crate straight away. The crate odds update by themselves: skins of one rarity share that rarity's chance.
6. The offline tests (`lune run tests/run`) check that every theme has exactly 12 Common, 5 Uncommon, 2 Rare and 1 CRAZY, so after adding a skin they report the new count. That's expected: ask Claude Code to update the count in `tests/specs/skins.spec.luau`, or use `/add-skin`, which does it for you. (Changing an existing skin's look and name keeps the counts.)

**Change a skin:** change its `Name` or anything in `Style` freely. **Never change an `Id`** once the game is live: it is saved in players' data.

**Rules worth knowing:**
- How rarities should look: Common = colours, materials and an accent; Uncommon = + a head piece; Rare = + glow and particles (`Glow`, `Aura`); CRAZY = everything + `Crazy = { Rainbow, Pulse, Orbit }`.
- `CrateOnly = true` keeps a skin out of the Shop (crates only). `Price = 300` gives it its own price.
- `Crate = "CandyCrate"` on one skin puts it in a different crate than its theme's.
- **New theme:** copy a theme file, rename it and every `Id` in it, then add a line to `Themes` in `Skins/Settings.luau` (its `Id` is the file name, `Crate` is the crate it drops from). Add that crate too (see "Crates").
- CRAZY animations can be switched off with `Config.Features.SkinEffects = false`; their speed and how many players animate at once are in `Skins/Settings.luau` > `Effects`.
- Or ask Claude Code: `/add-skin a Candy skin made of bubble gum, Rare`.

### Trails
A trail is two colours: `Style = { Kind = "Trail", Color = ..., Color2 = ... }`.

---

## Crates
Mystery crates give a random skin. Everything about them is in `src/shared/Config/Crates.luau`
(switch them off with `Config.Features.Crates = false`, or only the Robux ones with
`Config.Features.RobuxCrates = false`).
- **Odds**: `Odds = { Common = 70, Uncommon = 24.9, Rare = 5, Crazy = 0.1 }` is the chance (in
  percent) of each rarity. The skins of one rarity share it equally, so in the Pumpkin Crate each
  of the 12 Commons has 5.833% and its one CRAZY skin 0.100%. Keep the total at 100. One crate can
  have its own `Odds`.
- **Prices**: each crate's `Price` (coins). A Robux price is set in Creator Hub: make a Developer
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
- **Duplicates**: a skin you already own pays back `DuplicateRefund` coins (`Config/Rarity.luau`).
- **The crate stand** next to the Pumpkin Shop (`src/server/Hub/Sections/CrateStand.luau`, in
  `Config.Lobby.Zones.Crates`): every crate on a plinth with an "Open" prompt. Each prompt sits on
  an invisible part tagged `CrateDisplay` with the attribute `CrateId`: move or copy them in
  Studio, or tag any part of your own. Your own crate look: a model named after the crate's Id
  (e.g. `PumpkinCrate`) in `ReplicatedStorage > Custom > Props`.
- **Test it**: F8 > "Crates: open free Pumpkin Crate" and "Crates: +100k coins". Which crate the free button opens: `Admin.FreeCrate`. To see what players in a blocked region see, set `Policy.TestAsRestricted = true` (Studio only).
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
- **Move it:** change `Config.Lobby.Zones.ReadyArea` and rebuild the lobby. Or, in a baked lobby, drag the whole `ReadyArea` model (or just the pad, the part tagged `ReadyPad`) wherever you like.
- **A second pad:** select the pad and press Ctrl+D. Any part tagged `ReadyPad` counts, square or round, and a tagged Model counts as its whole box.
- **Switch it off** (`ReadyPad = false` in `Features.luau`) and everyone in the lobby plays every round, like before v2.
- If there is no part tagged `ReadyPad` at all, everyone counts as ready (the Output window says so) and the game puts a pad back the next time it starts.

---

## Parkour jumps
The "Spooky Sky Climb" behind the clock tower. Settings: `src/shared/Config/Parkour.luau`.
- **Coins and times:** `Reward.Coins` (100), `Reward.CooldownHours` (20), `MinSeconds` (15: a faster finish doesn't count). These work straight away, also in a saved lobby.
- **The course** is the `Course` list near the top: one line per piece, in climbing order. `Kind` is `Start`, `Pumpkin`, `Grave`, `Broom`, `Candy`, `Bat`, `Platform`, `Checkpoint`, `Finish` or `Hazard` (green slime). `Offset = Vector3.new(right, up, back)` is where the top of the piece is, in studs from the middle of the parkour zone, seen from the plaza. Optional: `Size`, `Rotation`, `Spicy = true` (a harder jump is allowed), `Label` (a checkpoint's stage name) and `Text` (words on a gravestone).
- **Add a jump:** copy a line, paste it where it goes in the order and change its `Offset`. Keep `Start` first and `Finish` last. The Output window warns about any jump that is too far or too high for a normal player (limits in `Jumps`: 9 studs across and 5 up; 10 and 5.5 for a Spicy one).
- **See it:** F8 > Rebuild hub tries it in a playtest. To keep it, run `Bake.Hub()` in edit mode (or `Bake.Hub(true)` for a Locked lobby) or raise `Config.Hub.BuildVersion`.
- **Or move pieces by hand** in a baked lobby (`Workspace.Hub.Parkour`): the game finds the working parts by tag, not by name or place. `ParkourStart` (start pad), `ParkourCheckpoint` with the attribute `Index` = 1, 2, 3 in climbing order, `ParkourFinish` (the trophy), `ParkourHazard` (slime), `ParkourBoard` (best times). The jumps in between are just parts: move, copy or delete them freely.
- Or ask Claude Code: `/add-parkour-jump a spooky ghost platform after the second checkpoint`.

---

## Candy Rush
The candy stand on the west side of the lobby. Settings: `src/shared/Config/CandyRush.luau`.
- **The race:** `Candies` (10 to win), `MinPlayers` (2), `CountdownSeconds`, `MaxRaceSeconds` (60).
- **Solo runs:** `Solo.On`, `Solo.AfterSeconds` (6 s alone on a pad).
- **Coins:** `Rewards.WinCoins` (25), `PlayCoins` (5), `SoloCoins` (5), `CooldownSeconds` (15), `DailyCap` (300 a day; 0 = no limit).
- **Looks and words:** `Candy`, `Stand`, `Text`, `Sounds`.
- **In Studio:** the stand is a Model tagged `CandyRushStation`; a copy of it is a second, separate race. The board is tagged `CandyRushBoard`. Each pad is tagged `CandyRushPad` with the attribute `Lane` (1 = the left column of the board as you look at it). Move or resize them freely.
- Your own candies: models named `CandyRushWrapped`, `CandyRushLollipop`, `CandyRushCandyCorn` in `Custom > Props`.
- Test alone: F8 > "Candy Rush: start solo test".

---

## Web Scour
The Spider Grove scavenger hunt. Settings: `src/shared/Config/WebScour.luau`.
- **The game:** `Critters` (6 to find), `TimeLimit` (45 s), `MaxReach` (how close you must be to click one).
- **Coins:** `CoinsPerCritter` (2), `FinishCoins` (20), `TimeBonusPerSecond` (0.5), `MaxCoins` (50), `RewardCooldown` (180 s between paid hunts, saved per player).
- **Looks and words:** `Grove` (trees, webs, lantern, spider, colours), `Text`, `Sounds`.
- **In Studio:** the lantern is the part tagged `WebScourStart` (your own lantern model works too: tag the Model). The hiding spots are invisible parts tagged `WebScourSpot`: move, copy or delete them. Delete the lantern and a new one is put back; the rest of the grove stays as you left it.
- Test: F8 > "Web Scour: start".

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
- Your own egg look: a model named `EggGoldenPumpkin` (or `EggCandy`, `EggLollipop`, `EggSkull`, `EggGhost`) in `Custom > Props`.
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
- A tile that opens something new needs a little code (`MenuUI.AddTile`): ask Claude Code.

---

## The hub
`Config.Hub` controls the plaza size, colours, lighting, decorations, music and photo spot emotes. After changing it, try it with F8 > **Rebuild hub** (that playtest only). To make it stick, raise `Config.Hub.BuildVersion` by one: the next time the game starts, a saved hub with a lower number is rebuilt (unless it is Locked, see below).

What's where (positions are studs from the middle: x = east/west, z = south/north):
- `Spawn`: the round stone players appear on (south), and the spot they look at (`LookAt`).
- `ReadyArea`: the glowing rune circle, its standing stones, the pumpkin arch and the "PLAY!" banner. Move the circle with `Config.Lobby.Zones.ReadyArea`.
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
4. Edit it. In the Explorer it is grouped into Models with readable names:
   - `Plaza` (the ground), `Spawn`, `Npcs` (Voting Board, Leaderboard, Photo Spot),
   - one Model per lobby area: `ReadyArea`, `Shop` (with the `PumpkinVendor` stall), `CrateStand`, `Parkour`, `CandyRush`, `WebScour`, `EasterEggs`,
   - `Plaza`: `Ground`, the `Promenade` ring, the `Dais` the cauldron stands on, `Walkways`, `Curb` and small `Details` (cracks, puddles, leaves),
   - `Decor`: everything that is only for looks (`ClockTower`, `Cauldron`, `Lamps`, `PathLamps`, `Bunting`, `JackOLanterns`, `Candles`, `Benches`, `Graveyard`, `Trees`, `Clutter`, `Signposts`, `Forest`, `HauntedMansion`, `KingStatue`, `PumpkinPatch`, `OldGraves`, `Fence`, `Paths`, `Ambience`). Delete or move any of it freely.
5. Lock it: `require(game.ServerScriptService.Server.Tools.Bake).Lock()`
6. Save the place (Ctrl+S). Your lobby lives in the place file, not in git, so keep a backup: right-click `Workspace.Hub` > **Save to File...**

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
| `WebScourSpot` | A place a critter can hide | |
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
Put a model in `ReplicatedStorage > Custom > Props` named exactly after the decoration, and **every copy** in the lobby uses it:

| Name | What it replaces |
| --- | --- |
| `Pumpkin` | every plain pumpkin (patch, piles, posts, signs) |
| `JackOLantern` | every carved, glowing pumpkin |
| `SpookyTree` / `DeadTree` | trees with puffy leaves / bare trees with lanterns |
| `Lamppost`, `Lantern`, `Candle` | lamps, small glass lanterns, candles |
| `Bench`, `HayBale`, `Crate`, `Barrel` | furniture and clutter |
| `Gravestone`, `FencePost` | tombstones, iron fence posts with a pumpkin on top |
| `Signpost`, `Mushroom`, `Bat`, `Cobweb` | signs, glowing toadstools, bats, spider webs |
| `ClockTower`, `Cauldron`, `KingStatue` | the big centrepieces |
| `VendorStall`, `ReadyPadArch` | the Pumpkin Shop stall, the arch over the Ready circle |
| `ParkourArch`, `ParkourTrophy`, `ParkourBat` | the parkour start arch, the trophy pumpkin, the bat-wing jumps |
| `CandyCane`, `GiantLollipop`, `CandyBucket`, `Gumdrop`, `SignCandyCorn` | the Candy Rush stand's decorations |
| `CandyRushWrapped`, `CandyRushLollipop`, `CandyRushCandyCorn` | the candies you click in Candy Rush |
| `GroveSpider` | the friendly spider in the Spider Grove |
| `EggGoldenPumpkin`, `EggCandy`, `EggLollipop`, `EggSkull`, `EggGhost` | the secret pumpkins (Easter eggs) |
| a crate's Id, e.g. `PumpkinCrate` | that crate on the stand and in the crate panel |
| `HidingPumpkin` | Hide & Seek pumpkins (when a map has no decoys of its own) |
| `Scarecrow`, `Wheelbarrow`, `Well`, `Tractor`, `HarvestCart`, `RockingChair`, `AutumnTree`, `HayRoll`, `Fountain`, `Topiary` | Pumpkin Farm and Hedge Maze decorations |
| `ScareScarecrow`, `ScareZombie`, `ScareBat`, `ScareGhost` | the ScareMaze scare characters |

The code for all of them is in `src/server/Build/Props.luau` (and `Hub/NpcLooks.luau` for the stall).
- Not sure of the name? Select the decoration and look at its `PropName` attribute.
- It is scaled to the size of the decoration it replaces (add `KeepSize` = true to keep yours) and stands where it stood, turned the same way (only left/right: it is never tipped over).
- It works in a saved or Locked lobby too: the swap happens each time the game starts.
- Scripts inside are removed. Keep it in git: **Save to File...** as `assets/Props/JackOLantern.rbxm`.
- Removed your custom prop? Lobbies built while it existed still contain copies of it: run `Bake.Hub()` again (or F8 > Rebuild hub) to get the built ones back.

### Lobby areas (zones)
`Config.Lobby.Zones` (`src/shared/Config/Lobby.luau`) keeps one area of the lobby free for each thing. Decorations are never placed inside a zone.

| Zone | What goes there | Where now (`Offset`, studs from the middle) |
| --- | --- | --- |
| `ReadyArea` | The Ready circle, right in front of the spawn | (0, 46): south |
| `Shop` | The Pumpkin Shop stall | (40, -18): east |
| `Crates` | The Mystery Crates stand, next to the shop | (46, 6): east |
| `CandyRush` | The Candy Rush stand | (-60, 0): west |
| `WebScour` | The Spider Grove | (-38, -32): north-west |
| `Parkour` | The Spooky Sky Climb (60 tall) | (0, -80): north, behind the clock tower |

- `Offset = Vector3.new(x, 0, z)`: x = east (+) / west (-), z = south (+) / north (-). `Size` = width and depth.
- Each zone faces the middle of the lobby, so its front points at the plaza.
- **Move an area:** change its `Offset`, then rebuild (F8 > Rebuild hub to try it; `Bake.Hub()` in edit mode, or raise `Config.Hub.BuildVersion`, to keep it). The paths and signposts follow.
- In a baked lobby you can also just drag the area's Model (`Workspace.Hub.CandyRush` and so on): the working parts are found by tag.
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
| `/add-skin` | New crate skin in a theme file, with its rarity and look |
| `/add-crate` | New crate: its skins, price, odds, stand display and Robux product |
| `/add-parkour-jump` | New jump (or stage) on the parkour course, checked against the jump limits |
| `/add-secret-pumpkin` | New hidden Easter egg with coins and a riddle |
| `/edit-lobby` | Bake, lock, move or repair the lobby, or move its tagged parts |
| `/new-playlist` | New mode + map pair in the vote |
| `/add-cosmetic` | New hat, pet, trail or skin. Describe it and it builds the look too |
| `/reskin` | Restyle a character or NPC (Part-built or from a model you name) |
| `/add-npc` | New lobby NPC with dialogue and a prompt |
| `/add-monster` | New King Hunt minion type with behaviour and config |
| `/add-map` | New round map, built from code, in the existing style |
| `/new-code` | Adds a promo code with reward and expiry |
| `/new-event` | Limited-time event (double pumpkins, Blood Moon round, event cosmetics) |
| `/tweak` | Balance or tune anything from a plain-English request |
| `/polish-hub` | More detail and life in the lobby, within the phone budget |

Each command reads `CLAUDE.md`, keeps numbers in Config, playtests in Studio when it can, runs the offline tests (`lune run tests/run`) and commits.
