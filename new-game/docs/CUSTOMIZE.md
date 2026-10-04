# Customise everything

The game is built so you can change almost anything without touching code. There are three layers:

| Layer | What it controls | Where | How hard |
| --- | --- | --- | --- |
| **1. Config** | Every number, name, price, colour, dialogue line, code, reward | `src/shared/Config.luau` | Edit text, save. Rojo syncs it live. |
| **2. Custom models** | How every character, NPC, hat, pet and skin *looks* | Studio: `ReplicatedStorage > Custom` | Build or import a model, give it the right name. |
| **3. Code** | New behaviour (a new monster, mode, item type) | `src/` | Ask Claude Code with a slash command (bottom of this page). |

Test anything fast in a Studio playtest with **F8** (admin panel): +Coins, Unlock all items, Reset daily, **Rebuild hub**, Reset my save. It only works in Studio unless you turn it on for live servers (`Config.Admin`).

---

## Quick "I want to change..." table

| I want to change... | Edit |
| --- | --- |
| Game name on the HUD | `Config.Game.Name` (the Roblox page name is set in Creator Hub) |
| Round length, intermission, results time | `Config.Round` |
| Coins per pumpkin, survivor bonus | `Config.Rewards` |
| Easy/Hard pumpkins, reward multiplier | `Config.Difficulty.Levels` |
| King speed, hearing, sight, how many Kings | `Config.King.Difficulty` |
| How loud sprinting/shouting/talking is to the King | `Config.King.Noise`, `Config.Voice.Noise` |
| Skeletons, bats, ghost cats (count, speed, damage, messages) | `Config.Monsters` |
| Player walk/sprint speed | `Config.Player` |
| Ghost mode rules (fly speed, haunt) | `Config.Ghost` |
| Voice range and echo | `Config.Voice` |
| Hub layout, colours, lighting, music, decorations | `Config.Hub` (then F8 > Rebuild hub, or delete `Workspace.Hub`) |
| NPC names, positions, dialogue | `Config.Npcs.List` |
| Shop items and prices (hats, trails, pets, skins) | `Config.Shop.Items` |
| VIP perks, Robux products | `Config.Monetization` (IDs from Creator Hub) |
| Codes for YouTubers | `Config.Codes.List` |
| Daily streak rewards | `Config.Daily.Rewards` |
| Friend/group bonus, invite button, favourite prompt | `Config.Social` |
| Map lighting and ambient sound | `Config.Maps.List[i].Lighting`, `.AmbientSound` |
| UI colours and font | `src/client/Theme.luau` |
| Character/NPC/hat/pet/skin looks | A model in `ReplicatedStorage > Custom` (below) |
| A whole map | A model in `ServerStorage > Maps` (below) |

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
| `WitchWanda` | Witch Wanda (shop NPC) | 8 |
| `BooGuide` | Boo Guide (tips NPC) | 6.5 |
| `PumpkinVendor` | Pumpkin Vendor NPC | 7.5 |

Sizes are in `Config.Custom.Heights`. To keep the size you built, add an attribute to the model: **KeepSize** (boolean) = true.

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
2. Name the model after the map's Id (`PumpkinPatch` or `SpookyMansion`) and put it in `ServerStorage > Maps` (create the Maps folder).
3. Save and play. That map loads instead of the generated one.

Add a third map: add an entry to `Config.Maps.List` (Id, Name, SpawnFolder = "Spawns", Lighting, AmbientSound) and put its model in `ServerStorage > Maps`. Or ask Claude with `/add-map`.

---

## The hub
`Config.Hub` controls the plaza size, colours, lighting, decorations, music and photo spot emotes. After changing it, rebuild the hub: F8 > **Rebuild hub** (that playtest only), or delete `Workspace.Hub` in Studio and press Play (it rebuilds and you can save it).
You can also edit the hub by hand in Studio: the game never overwrites an existing `Workspace.Hub`.

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
