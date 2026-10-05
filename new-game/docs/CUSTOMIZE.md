# Customise everything

The game is built so you can change almost anything without touching code. There are three layers:

| Layer | What it controls | Where | How hard |
| --- | --- | --- | --- |
| **1. Config** | Every number, name, price, colour, dialogue line, code, reward | `src/shared/Config/` (`init.luau` plus one file per v2 feature) | Edit text, save. Rojo syncs it live. |
| **2. Custom models** | How every character, NPC, hat, pet and skin *looks* | Studio: `ReplicatedStorage > Custom` | Build or import a model, give it the right name. |
| **3. Code** | New behaviour (a new monster, mode, item type) | `src/` | Ask Claude Code with a slash command (bottom of this page). |

Test anything fast in a Studio playtest with **F8** (admin panel): +Coins, Unlock all items, Reset daily, **Rebuild hub**, **Repaint hub**, Reset my save. It only works in Studio unless you turn it on for live servers (`Config.Admin`).

Want to move, recolour or rebuild the lobby or a map **by hand** in Studio? See [Editing the lobby and maps by hand](#editing-the-lobby-and-maps-by-hand).

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
| Hub layout, lighting, music, decorations | `Config.Hub` (then F8 > Rebuild hub to try it, and raise `Config.Hub.BuildVersion` so saved hubs update) |
| Hub colours | `Config.Hub.Palette` (the `hubPalette` list at the top of `Config/init.luau`) |
| Where the Ready pad, shop, minigames and parkour go | `Config.Lobby.Zones` |
| Ready pad look and sign text | `Config.Hub.ReadyArea` |
| Hub terrain, forest, mansion, statue, fence, glowing paths | `Config.Hub.Polish` (same rebuild) |
| NPC names, positions, dialogue | `Config.Npcs.List` |
| Shop items and prices (hats, trails, pets, skins) | `Config.Shop.Items` |
| VIP perks, Robux products | `Config.Monetization` (IDs from Creator Hub) |
| Codes for YouTubers | `Config.Codes.List` |
| Daily streak rewards | `Config.Daily.Rewards` |
| First-round tutorial tips and timings | `Config.Tutorial` |
| Friend/group bonus, invite button, favourite prompt | `Config.Social` |
| Map lighting and ambient sound | `Config.Maps.List[i].Lighting`, `.AmbientSound` |
| Sound effects (clicks, pickups, King footsteps, minions, rewards) | `Config.Sounds` (SoundId "" = silent) |
| Hub music, King roar | `Config.Hub.Music`, `Config.King.Heard.RoarSoundId` |
| UI colours and font | `src/client/Theme.luau` |
| UI size on big screens, phone layout, side buttons | `Config.UI` |
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
Add an entry to `Config.Shop.Items`. For example, a new pet that only uses your model:
```lua
{
	Id = "SpiderPet",            -- also the name of your model in Custom > Cosmetics
	Name = "Spooky Spider",      -- shown in the shop
	Slot = "Pet",                -- "Skin", "Hat", "Trail" or "Pet"
	Price = 750,                 -- coins
	Style = { Kind = "Custom" }, -- look comes from the custom model
},
```
Add `VipOnly = true, Price = 0` to make it a VIP perk. Until the model exists, the shop shows a pink "?" box, so nothing breaks.

### Skin options (no model needed)
```lua
{
	Id = "Vampire", Name = "Vampire", Slot = "Skin", Price = 600,
	Style = {
		Kind = "Skin",
		BodyColor = Color3.fromRGB(220, 220, 235), -- recolours the whole avatar (optional)
		Material = Enum.Material.SmoothPlastic,    -- optional: Neon, Fabric, Glass, ...
		Transparency = 0,                          -- optional: 0.3 = see-through
		HideClothes = true,                        -- hide shirt and pants (optional)
		Head = "SkinSkull",                        -- optional head piece: SkinPumpkin, SkinSkull, SkinKing
		HeadColor = Color3.fromRGB(235, 228, 210), -- head piece colour
		GlowColor = Color3.fromRGB(255, 0, 0),     -- eyes and mouth glow
	},
},
```
Skins are removed cleanly when unequipped: the player's own avatar comes back.

### Trails
A trail is two colours: `Style = { Kind = "Trail", Color = ..., Color2 = ... }`.

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

Add a third map: add an entry to `Config.Maps.List` (Id, Name, SpawnFolder = "Spawns", Lighting, AmbientSound) and put its model in `ServerStorage > Maps`. Or ask Claude with `/add-map`.

---

## The hub
`Config.Hub` controls the plaza size, colours, lighting, decorations, music and photo spot emotes. After changing it, try it with F8 > **Rebuild hub** (that playtest only). To make it stick, raise `Config.Hub.BuildVersion` by one: the next time the game starts, a saved hub with a lower number is rebuilt (unless it is Locked, see below).

---

## Editing the lobby and maps by hand

The lobby ("Spooky Town Square", `Workspace.Hub`) and the round maps are built by code, but you can turn them into real parts in your place and change anything by hand in Studio: move, resize, recolour, delete or add parts.

### How the game treats the lobby saved in your place
- When you press Play, the game uses the `Workspace.Hub` saved in your place, as it is.
- **BuildVersion.** Every lobby built by the game has the attribute `BuildVersion` (select `Workspace.Hub`, then Properties > Attributes). When the lobby code changes, `Config.Hub.BuildVersion` goes up. A saved lobby with a lower number (or none) is rebuilt from code automatically, and your changes to it are lost...
- **Locked.** ...unless you lock it. Add the attribute `Locked` (a boolean, ticked) to `Workspace.Hub`, or run `Bake.Lock()` (below). A Locked lobby is never rebuilt; if it is older than the code, the Output window says so and how to update it.
- **The game always puts back what it needs**, even in a Locked lobby: the spawn, the Ready pad and the Pumpkin Shop keeper. If one is missing, it is added for that server and the Output window tells you; run `Bake.Repair()` to add it to your place for good.
- The old Witch Wanda and Boo Guide are removed from saved lobbies automatically.

### Step by step: edit the lobby
1. Stop the game (you must be in edit mode, not playing).
2. Open View > **Command Bar**.
3. Paste this and press Enter: `require(game.ServerScriptService.Server.Tools.Bake).Hub()`
   `Workspace.Hub` is (re)built from code. Ctrl+Z undoes it.
4. Edit it. In the Explorer it is grouped into Models with readable names:
   - `Plaza` (the ground), `Spawn`, `Npcs` (Voting Board, Leaderboard, Photo Spot),
   - one Model per lobby area: `ReadyArea`, `Shop` (with the `PumpkinVendor` stall), `Parkour`, `CandyRush`, `WebScour`, `EasterEggs`,
   - `Decor`: everything that is only for looks (`ClockTower`, `Cauldron`, `Lamps`, `Bunting`, `JackOLanterns`, `Candles`, `Graveyard`, `Trees`, `Forest`, `HauntedMansion`, `KingStatue`, `PumpkinPatch`, `OldGraves`, `Fence`, `Paths`, `Ambience`). Delete or move any of it freely.
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
| `ReadyPad` | Players standing on it join the next round | The square stone in `ReadyArea`. Ctrl+D a copy to make a second pad. The glowing ring is just decoration. |
| `ReadySign` | Shows "READY 2 / 4" and what the round is doing | An invisible part in `ReadyArea` holding the floating sign. Move it anywhere. |
| `HubSpawn` | Where players appear in the lobby and come back after a round | The `Spawn` pad. |
| `ShopKeeper` | Opens the Pumpkin Shop | On the `PumpkinVendor` stall. Tag **any** part `ShopKeeper` and it opens the shop too (a "Shop" prompt is added). |

Other features add their own tags (parkour checkpoints, Candy Rush pads, Easter eggs...): the list, with what each one needs, is at the top of `src/shared/Tags.luau`.

### Colours: the palette
The lobby's colours are in `Config.Hub.Palette` (the `hubPalette` list at the top of `src/shared/Config/init.luau`): `Ground`, `Stone`, `Wood`, `Iron`, `Bone`, `Orange`, `Purple`, `Green`, `Glow`, `Gold`, `Cloth`, `Straw`, `Dark`.
- Each painted part has the attribute **PaletteRole** (which colour it uses) and sometimes **PaletteShade** (0.3 = 30% darker, -0.2 = 20% lighter).
- Change a colour in the palette and every part with that role follows the next time you press Play, even in a Locked lobby. To keep it in your place too, run `Bake.Repaint()` in edit mode and save.
- Recoloured one part by hand? It keeps your colour until you change that palette colour. To keep it for good, delete its `PaletteRole` attribute.
- To paint one of your own parts from the palette, give it a `PaletteRole` attribute (a string, e.g. `Wood`).

### Swap a decoration everywhere: props
Put a model in `ReplicatedStorage > Custom > Props` named exactly after the decoration, and **every copy** in the lobby uses it: `JackOLantern`, `Lamppost`, `DeadTree`, `Gravestone`, `Candle`, `Cobweb`, `KingStatue`, `ClockTower`, `Cauldron`, `VendorStall`, `ReadyPadArch`.
- Not sure of the name? Select the decoration and look at its `PropName` attribute.
- It is scaled to the size of the decoration it replaces (add `KeepSize` = true to keep yours) and stands where it stood, turned the same way (only left/right: it is never tipped over).
- It works in a saved or Locked lobby too: the swap happens each time the game starts.
- Scripts inside are removed. Keep it in git: **Save to File...** as `assets/Props/JackOLantern.rbxm`.
- Removed your custom prop? Lobbies built while it existed still contain copies of it: run `Bake.Hub()` again (or F8 > Rebuild hub) to get the built ones back.

### Lobby areas (zones)
`Config.Lobby.Zones` says where the Ready pad, the shop, Candy Rush, Web Scour and the parkour course go. Decorations are never placed inside a zone, so each area stays free. Move one by changing its `Offset`, then rebuild (`Bake.Hub()`, or raise `Config.Hub.BuildVersion`). The shop follows its zone.

### Round maps
1. In edit mode, run `require(game.ServerScriptService.Server.Tools.Bake).Map("PumpkinPatch")` (any Id from `Config.Maps.List`).
   The map appears in `ServerStorage > Maps > PumpkinPatch`. From now on, rounds on that map use this copy.
2. To edit it, drag it into **Workspace**. It sits far away from the lobby: select it and press **F** to fly the camera there.
3. Edit it. Keep exactly one part named **Floor** (the ground pumpkins and monsters stand on) and the **Spawns** folder (where players start); the **Hotspots** folder is optional.
4. Drag it back into `ServerStorage > Maps` and save the place.
5. Keep it in git: right-click it > **Save to File...** and save it as `new-game/maps/PumpkinPatch.rbxm` (the `maps/` folder is `ServerStorage > Maps`). Then, with Rojo connected, delete the copy in Studio so there is only one.
- Running `Map(...)` again keeps your previous copy as `PumpkinPatch_Backup`.
- Lighting, sounds and the name in the vote still come from `Config.Maps`.
- Want the code-built map back? Delete it from `ServerStorage > Maps`.

---

## Claude Code commands (type them in Claude Code)
| Command | What it does |
| --- | --- |
| `/next-milestone` | Builds the next unfinished milestone in `docs/PROGRESS.md` |
| `/verify` | Full playtest pass: every feature, every error, then fixes |
| `/add-cosmetic` | New hat, pet, trail or skin. Describe it and it builds the look too |
| `/reskin` | Restyle a character or NPC (Part-built or from a model you name) |
| `/add-npc` | New hub NPC with dialogue and a prompt |
| `/add-monster` | New minion type with behaviour and config |
| `/add-map` | New round map, built from code, in the existing style |
| `/new-code` | Adds a promo code with reward and expiry |
| `/new-event` | Limited-time event (double pumpkins, Blood Moon round, event cosmetics) |
| `/tweak` | Balance or tune anything from a plain-English request |
| `/polish-hub` | Bigger, richer spawn hub (terrain, statue, more detail) |

Each command reads `CLAUDE.md`, keeps numbers in Config, playtests in Studio, and commits.
