# Pumpkin Panic v2: build spec

Written 5 October 2026 (night) from Kieran's v2 request. This is the contract every v2 change follows, so separate pieces fit together. Kieran: you don't need to read this; `docs/V2-CHANGES.md` is the plain-English version.

## The request, as a checklist
1. Pumpkin Vendor is missing from the lobby: find out why, fix it, and make it impossible to lose again.
2. Everything looks blocky: full visual redesign of the lobby (and better-looking new maps).
3. Lobby minigames on the side: **Candy Rush** (click your candies, first to clear them all wins) and **Web Scour** (a quick Halloween scavenger hunt in the spider webs).
4. **Ready pad**: nobody is pulled into a round automatically. Stand on the pad to say you're ready; everyone else stays in the lobby (minigames, parkour, shop) and can spectate.
5. New mode **Pumpkin Hide & Seek** (PvP): seekers have candy guns, hiders are pumpkins. Fairly easy to find hiders. Two maps: **Pumpkin Farm** and **Hedge Maze**.
6. New mode **ScareMaze**: two teams, Haunters and Survivors. Survivors must get through the maze and lose if they stand still for 3 seconds. Jumpscares from moving scarecrows and zombies popping up.
7. **Parkour** course in the lobby.
8. **Easter eggs**: hidden pumpkins that give coins once each (e.g. a pumpkin behind the shop gives 50).
9. **Economy**: each pumpkin = 5 coins. Rarity prices: Common 125, Uncommon 500, Rare 1000, CRAZY 100000.
10. **Crates**, bought with coins or Robux, each item has a rarity. One crate per rarity, plus themed mixed crates with % chances (Pumpkin, Candy, Spooky + more, 20 skins each, one CRAZY skin at 0.1%). Preview shows every item and its chance.
11. **Super easy to edit every part of every map** (IMPORTANT).
12. **Top-left Menu**: skins, shop, crates, invite, vote, codes, settings, spectate.
13. Remove the witch, Boo Guide and all tutorial pop-ups. The Pumpkin Vendor is the only shopkeeper.
14. Every change can be turned off, reverted or improved.

## Ground rules (on top of CLAUDE.md)
- Server authoritative, every remote validated (type, range, ownership, cooldown). Coins and items are only ever granted on the server.
- Every tunable lives in Config. v2 settings live in their own files under `src/shared/Config/` (see below), one file per feature, so each is short and easy to edit.
- Every v2 feature has an on/off switch in `Config.Features`. A service whose feature is off does nothing in `Start()`; its UI hides.
- Functional parts are found by **CollectionService tag** (constants in `src/shared/Tags.luau`), never by position or path. A tagged part can be moved, resized, recoloured, duplicated or replaced in Studio and still works.
- New looks must support the custom-model override (`CustomAssets`), like the existing characters and cosmetics.
- Kid-friendly: spooky-cute, no gore, no blood.
- One commit per feature, message starts with `v2:`.

## Config layout
`src/shared/Config.luau` becomes `src/shared/Config/init.luau` (same `require(ReplicatedStorage.Shared.Config)` path). New child modules, each returning a plain table assigned onto Config:

| File | Config key | What |
| --- | --- | --- |
| `Config/Features.luau` | `Config.Features` | on/off switches |
| `Config/Modes.luau` | `Config.Modes` | modes, playlists (mode + map pairs offered in the vote) |
| `Config/Lobby.luau` | `Config.Lobby` | lobby layout zones, Ready pad, spectating |
| `Config/Parkour.luau` | `Config.Parkour` | course layout, rewards |
| `Config/Minigames.luau` | `Config.Minigames` | Candy Rush, Web Scour |
| `Config/EasterEggs.luau` | `Config.EasterEggs` | egg list |
| `Config/HideSeek.luau` | `Config.HideSeek` | Hide & Seek rules, candy gun |
| `Config/ScareMaze.luau` | `Config.ScareMaze` | ScareMaze rules, scares |
| `Config/Rarity.luau` | `Config.Rarity` | rarity order, prices, colours, duplicate refunds |
| `Config/Crates.luau` | `Config.Crates` | crate list (each crate's items + odds) |
| `Config/Skins/*.luau` | merged into `Config.Shop.Items` | the crate skins, one file per theme |
| `Config/Menu.luau` | `Config.Menu` | menu tiles order and text |

## Tags (`src/shared/Tags.luau`)
`ReadyPad`, `HubSpawn`, `ShopKeeper`, `ParkourStart`, `ParkourCheckpoint` (attribute `Index`), `ParkourFinish`, `ParkourHazard`, `CandyRushStation`, `CandyRushPad` (attribute `Lane`), `CandyRushBoard`, `WebScourStart`, `WebScourSpot`, `EasterEgg` (attributes `EggId`, `Coins`), `HidingDecoy`, `ScareTrigger` (attribute `Kind`), `MazeExit`, `HauntSpawn`, `SurvivorSpawn`, `SeekerSpawn`, `HiderSpawn`, `PaletteRole` is an attribute, not a tag.

## Game modes
- `src/server/Modes/<Mode>.luau`, one per mode: `KingHunt` (the existing round, moved out of GameService), `HideSeek`, `ScareMaze`.
- Mode contract:
  ```lua
  export type RoundContext = {
      Map: MapService.LoadedMap,
      Players: { Player },      -- the ready players taking part
      Difficulty: string,       -- Config.Difficulty id
      Playlist: any,            -- the Config.Modes.Playlists entry that won the vote
      SetState: (state: string, timeLeft: number) -> (),
      Countdown: (state: string, seconds: number, stopIf: (() -> boolean)?) -> (),
      Teleport: (player: Player, spawn: BasePart) -> (),
  }
  Mode.Run(ctx: RoundContext) -> RoundResult  -- yields for the whole round, cleans up after itself
  export type RoundResult = { Rows: { ResultRow }, ScoreLabel: string, Winner: string? }
  ResultRow = { UserId, Name, Score, Coins, Survived, Top, Team: string?, Badge: string? }  -- Pumpkins = Score kept for old UI
  ```
- `GameService` keeps the loop: wait for enough ready players, vote, load map, intermission, `Mode.Run`, results, unload, send everyone back to the lobby.
- **Playlists** (`Config.Modes.Playlists`): `{ Id, Mode, Map, Name, MinPlayers }`. The vote offers playlists whose `MinPlayers` fits the ready count and whose mode is enabled. Vote option ids are playlist ids.
- The `ReplicatedStorage` attribute `Mode` holds the running mode id (e.g. `HideSeek`) so clients can show mode-specific UI.

## Ready pad and spectating
- `ReadyService`: a player is ready while their character stands inside any part tagged `ReadyPad` (checked on the server every `Config.Lobby.Ready.CheckSeconds`, using positions, not Touched). Publishes `ReplicatedStorage` attributes `ReadyCount`, `ReadyNeeded`, and a player attribute `Ready`.
- Round flow: `Waiting for players` (fewer than `MinReady` ready) -> `Voting` (only ready players can vote; joining the pad mid-vote lets you vote) -> `Intermission` -> round with whoever is still ready at the end of intermission -> `Results` -> everyone in the round is sent back to the lobby spawn (they must stand on the pad again).
- Anyone not in the round stays in the lobby. Menu > Spectate cycles the camera through players in the round (and the King). Lobby minigames work during rounds.

## Economy and rarity
- `Config.Rewards.CoinsPerPumpkin = 5`.
- `Config.Rarity`: `Order = { "Common", "Uncommon", "Rare", "Crazy" }`, each with `Name` (display: Common, Uncommon, Rare, CRAZY), `Price` (125, 500, 1000, 100000), `Color`, `DuplicateRefund` (coins given for a crate duplicate).
- Every shop item gets `Rarity`. Price = `item.Price` if set, else `Config.Rarity[item.Rarity].Price` (one helper: `src/shared/Items.luau`, `Items.Price(item)`, `Items.Get(id)`, `Items.ByCrate(crateId)`). Items can be `CrateOnly = true` (not sold directly) or `VipOnly`.

## Crates
- `Config.Crates.List`: `{ Id, Name, Theme colours, Price (coins), ProductKey/ProductId (Robux, 0 = not for sale yet), Odds = { Common = 70, Uncommon = 24.9, Rare = 5, Crazy = 0.1 } }`. Items list themselves in a crate with `Crate = "<CrateId>"`. Per-rarity crates (`CommonCrate`, `UncommonCrate`, `RareCrate`, `CrazyCrate`) draw from every item of that rarity.
- An item's chance = its rarity's odds / number of items of that rarity in the crate. The preview shows every item with its % (sums to 100).
- Roblox paid random items policy: odds shown before buying; players whose `PolicyService` says `ArePaidRandomItemsRestricted` can't open crates (coins can be bought with Robux, so coin crates count too). They can still buy skins directly at the fixed rarity price.
- Rolls happen on the server (`Random.new()`), duplicates refund coins, results are saved before the client animation starts.

## Menu (top-left)
- One `Menu` button at the top left. It opens a tile grid: Skins (inventory/equip), Shop, Crates, Vote, Spectate, Invite, Codes, Settings, VIP, Parkour/Easter egg progress.
- `Layout.SideButton(text, order)` keeps its signature but now returns a tile in the menu, so existing panels move into the menu without rewriting them.

## Lobby layout and editing
- `Config.Lobby.Zones`: named areas (offset from `Config.Hub.Center` plus size) reserved for the Ready area, Shop, Parkour, Candy Rush, Web Scour. Decoration never goes inside a zone.
- Each lobby section is its own Model under `Workspace.Hub` (`Plaza`, `Shop`, `ReadyArea`, `Parkour`, `CandyRush`, `WebScour`, `EasterEggs`, `Decor/...`) and every part has a readable name.
- Lobby sections are built by modules in `src/server/Hub/Sections/` (each `Build(hub: Model, zone)`), called by `HubBuilder.Build`.
- **Props override**: `Kit.prop(name, cframe, parent, size?, buildFn)` uses a model named `name` from `ReplicatedStorage.Custom.Props` when there is one (every copy of that prop swaps at once), else builds the code version.
- **Saved hub**: the hub saved in the place wins. `Config.Hub.BuildVersion` rebuilds an older saved hub automatically unless the hub has the attribute `Locked = true` (set it once you start hand-editing). Missing functional pieces (Ready pad, shopkeeper, spawn) are always added back, even to a locked hub.
- **Bake**: `src/server/Tools/Bake.luau`, run from Studio's command bar in edit mode, builds the hub into Workspace or any map into `ServerStorage.Maps` so it can be edited by hand.
- **Palette**: parts carry the attribute `PaletteRole`. `Config.Hub.Palette` colours are applied by role, so one colour change reskins every part with that role.
