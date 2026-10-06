# Offline tests

Smoke tests that run the real game code from `src/` without Roblox Studio, on
[Lune](https://lune-org.github.io/docs). The harness builds a fake DataModel the way
`rojo build` would and runs ModuleScripts and Scripts in a Roblox-like environment.

## Running

From the `new-game/` folder:

```sh
lune run tests/run                  # every tests/specs/*.spec.luau
lune run tests/run -- builders      # only spec files whose name contains "builders"
lune run tests/run -- --verbose     # also show the game's print() output
lune run tests/run -- --quiet       # hide the game's warnings too
```

On Windows, run the same commands in PowerShell or cmd from `new-game\`. `rokit install`
puts `lune` on your PATH (pinned to 0.10.2 in `rokit.toml`: Lune 0.8.9 sometimes froze
forever while reading files when the computer was busy). Rojo is **not** needed: the harness reads `default.project.json` and the files
itself.

The runner prints one line per test, a summary, and exits with code 1 if anything failed. A
test fails when it throws, or when game code it ran threw inside a task thread (`task.spawn`,
an event handler, a Script), even if the test itself didn't notice.

## What the specs cover

| Spec | Checks |
| --- | --- |
| `config.spec` | Shop items: unique Ids, known Slot, a Rarity from `Config.Rarity.Order`, `Items.Price` = own Price or the rarity price, Style.Kind; NPCs: Id, Kind, Offset, prompt; maps: unique ids, builder module exists, sizes, all Lighting groups, a Modes list of real modes; playlists point at a map made for their mode; lobby zones have Offset + Size and don't overlap; codes only give real items. |
| `Core.spec` | v2 foundation: feature switches, the v2 maps and playlists, rarity prices, `Items` helpers, the Pumpkin Shop replacing the witch, v2 save fields, `Lobby` zone maths, `Tags`. |
| `Startup.spec` | The `ORDER` lists in `Main.server.luau` / `Main.client.luau` name real modules once each (GameService last, MenuUI first); the placeholder services and UIs start / mount with their feature off and on. |
| `Rounds.spec` | Every mode in `Config.Modes` has its settings and a `src/server/Modes/<Id>.luau` with `Run`; `Playlists` lookups and which playlists the vote offers for a ready count and feature switches (a switched-off mode never; too few ready players = wait, no vote); `ReadyService.Inside` for flat, turned, round and ball pads, and against the pad the hub actually builds; a two-player round where only the player on the pad plays, the other can spectate (`SpectateFocus` streams the map to them, not to the player in the round), and everyone ends back in the lobby, not ready. |
| `Hub.spec` | `HubBuilder` builds every section, tag (HubSpawn, ReadyPad, ReadySign, ShopKeeper) and readable group; decorations stay out of the zones; palette roles, sync and repaint; `HubService` builds, rebuilds an old hub, keeps and repairs a Locked one; custom shopkeeper checks; custom props; `Bake` (hub, lock, maps; a baked map loads where the built one did); the Ready sign text. |
| `lobbyrepair.spec` | A lobby saved in the place and edited by hand: your own `HubSpawn` SpawnLocation stays on, pieces dragged out of the hub are removed before the spawn / Ready pad / shopkeeper checks, a Ready pad Model and a shopkeeper anywhere in Workspace count, a `Config.Hub.Lighting` typo only skips that setting, switched-off areas (Ready pad, Parkour, Candy Rush, crate stand, and the egg on the parkour trophy) leave the running game, Candy Rush and Web Scour repair a saved hub without throwing hand edits away (and a lantern Model works), the parkour board and egg coins follow Config, and the Voting Board client finds its board anywhere in the hub. |
| `Menu.spec` | `Config.Menu` lines are complete; `MenuLogic` (side buttons to tiles, tile grid on every screen size, the Menu button never covers the Hud); the mounted `MenuUI` adds, replaces, opens, closes and turns `Layout.SideButton` into tiles. |
| `builders.spec` | `HubBuilder.Build()` and every map builder in `src/server/Maps` run, make parts with finite, positive sizes, are deterministic; custom NPC models in `ReplicatedStorage.Custom.Characters` are scaled and placed; `MapService.Load` finds floor, spawns and random floor points (raycasts hit real geometry). Notes how many Ball parts have unequal sides (Roblox renders those as spheres). |
| `cosmetics.spec` | Every shop item: `Cosmetics.Preview`, `Cosmetics.Build` (pivot at the design origin), `Cosmetics.Wear` / `TakeOff` on a character, skins restore the avatar, a custom model in `ReplicatedStorage.Custom.Cosmetics` replaces the placeholder and is scaled. |
| `modules.spec` | Every ModuleScript requires cleanly (server, shared, client); `Main.server.luau` boots, waits while nobody stands on the hub's Ready pad, then plays a whole round once a player steps on it and sends them back to the lobby; `Main.client.luau` boots against what the server replicated and the Menu gets every tile. A `[Main] X failed to ...` warning (Main catches failing services and UIs) fails the test. |
| `crates.spec` | `Config.Crates`: every crate has items, chances add up to 100, rarity crates hold only their rarity, 200,000 simulated rolls match the odds, the reel; `CrateService`: coins taken, skin given or duplicate refunded, spam / unknown crates / no coins / crates off refused, restricted and "no answer" players refused (PolicyService); Robux crates granted once, undone when the save fails, restricted buyers get coins; F8 crate commands; the crate stand's prompts; the crate panel shows every chance, hides buy buttons for restricted players and spins to the result. |
| `HubLook.spec` | The lobby's look: real ovals instead of squashed balls, faces on the pumpkin surface, the phone budget (`Config.Hub.Budget` parts and lights, with every lobby feature on), decorations that never trip or block players, paths and signposts to every area that is switched on (and none to areas that are off), the view from the spawn. |
| `skins.spec` | Crate skins (`Config/Skins/`): 6 themes x 20 skins with their rarities, ids, crates and prices; every Style option points at something real; the rarity looks; every skin previews, goes on R15 and R6 characters and comes off leaving the avatar as it was; the shop dressing a respawned character; the client `SkinFx` effects; the paged Skins tab. |
| `parkour.spec` | The lobby parkour course: every jump in `Config.Parkour.Course` is doable, `ParkourLogic` (jump maths, checkpoint order, times, cooldowns), the built section (tags, Index order, inside its zone), `SpeedCheck` (the anti-teleport maths), `ParkourService` (start, checkpoints, falls, anti-teleport and flying, finish rewards, cooldown, Go to start, rounds, respawns, admin reset, a saved hub with no course), and `ParkourUI`. |
| `candyrush.spec` | Candy Rush: the rules (lanes, candy spots, the winner, coins and daily cap), the stand the hub builds, whole races on the server (two players, a forfeit, a solo run, the admin test, a player leaving) and the client screen. |
| `webscour.spec` | Web Scour: `WebScourRules`, the Spider Grove section, whole hunts against the real `WebScourService` (start at the lantern, catch critters, rejected catches, coins, best time, cooldowns, two hunters, leavers, the F8 command) and `WebScourUI`. |
| `eggs.spec` | Easter eggs: `EasterEggRules`, the egg list, placing eggs next to their anchors in the built hub, collecting them through the real `EasterEggService` (button, touch, distance, rounds, once only, coins, toast, admin reset) and `EasterEggUI`. |
| `hideseek.spec` | Pumpkin Hide & Seek: `HideSeekRules`, its two maps (Pumpkin Farm, Hedge Maze: every maze cell reaches the seeker hut) and whole rounds of `Modes/HideSeek.luau` with fake players (roles, the pumpkin disguise, the candy gun's server checks, tagging, leaving, results); fair play (the shop can't undo a disguise, resetting leaves the pumpkin to be found, extra seekers line up in the hut, hiders copy the map's decoys), spectators can't watch hiders, no chat bubbles during a round, 'Start round now' refused while hiding. |
| `scaremaze.spec` | ScareMaze: the rules (teams, the keep-moving rule, scores), the map (a way from the entrance to the exit, traps along it, tags) and a whole round on the real map with three players (one escapes, one stands still, one Haunter BOOs); the anti-cheat (teleporting during 'Get ready' or mid-run, flying) and a Survivor who resets during 'Get ready' becoming a Haunter. |
| `mazegen.spec` | `MazeGen`: every maze is fully connected, rooms are open, wall runs match the walls. |
| `harness.spec` | Self-tests of the harness (geometry, raycasts, scheduler, signals, services). If these fail, don't trust the others. |

## Writing a spec

Add `tests/specs/<name>.spec.luau`:

```lua
local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

describe("ShopService", function()
	local rt = Runtime.new() -- a fresh fake game, loaded from default.project.json
	local Config = rt:require("ReplicatedStorage.Shared.Config")

	it("does something", function()
		local ShopService = rt:require("ServerScriptService.Server.Services.ShopService")
		ShopService.Start()
		local player = rt:addPlayer({ Name = "Buyer" }) -- fires PlayerAdded, spawns a character
		rt:advance(5) -- 5 virtual seconds of task.wait loops, delays, Heartbeat
		expect(player:GetAttribute("DataReady")).toBe(true)
		T.note("anything worth printing under the test name")
	end)
end)
```

Each `Runtime.new()` is an isolated game (its own DataModel, module cache and clock), so specs
don't leak into each other. Code in a `describe` body runs while the file loads; code in `it`
runs as the test.

### Runtime API

| Call | Does |
| --- | --- |
| `Runtime.new(options?)` | Options: `client` (RunService:IsClient, a LocalPlayer), `studio`, `seed`, `time` (os.time at start), `echo` ("all"/"warn"/"none"), `dataStores = false` (GetDataStore errors), `baseplate`, `place` (load an `.rbxl` such as `rojo build` output instead of the project), `root`, `project`, `input`. |
| `rt:require(pathOrModule)` | Requires like a script would, e.g. `"ServerScriptService.Server.Services.MapService"`. |
| `rt:find(path)` | An instance by dotted path; errors if missing. |
| `rt:runScript(pathOrScript)` / `rt:startServer()` | Runs a Script/LocalScript as a task (it may keep running as time advances). |
| `rt:advance(seconds)` / `rt:flush()` | Moves virtual time / runs deferred tasks. `rt:now()` is the clock. |
| `rt:call(fn, ...)` | Runs `fn` as a task and advances time until it returns (for code that yields). |
| `rt:addPlayer{Name, UserId, character}` / `rt:removePlayer(p)` / `rt:spawnCharacter(p)` | Players and simple R15-like characters. |
| `rt:fire(signal, ...)` / `rt:fire(instance, "Event", ...)` | Fire any event (`Touched`, `Triggered`, ...). |
| `rt:fireServer(remote, player, ...)` / `rt:invokeServer(remote, player, ...)` | A client calling a RemoteEvent / RemoteFunction. |
| `rt:triggerPrompt(prompt, player)` / `rt:purchase(player, productId)` / `rt:triggerAction(name)` | ProximityPrompt, Developer Product receipt, ContextActionService action. |
| `rt:replicateFrom(serverRt)` | Copies ReplicatedStorage / Workspace / Lighting children from a server runtime into a client runtime. |
| `rt:calls("Class", "Method")` | Calls made to engine methods the harness only stubs (`Terrain:FillBall`, `RemoteEvent:FireClient`, `Sound:Play`, ...); pass a list of method names to get them all in call order. |
| `rt:source(pathOrScript)` | A script's source code (e.g. to read the `ORDER` list in a Main script). |
| `rt:parts(root?)`, `rt:create(className, props?, parent?)` | Helpers. |
| `rt.warnings`, `rt.logs`, `rt.errors` | Game output and task errors. |
| `rt.secrets`, `rt.httpHandler`, `rt.gamePasses`, `rt.groupRanks`, `rt.friends`, `rt.dataStoreFailures`, `rt.filterText` | Set up service behaviour (see the top of `harness/Services.luau`). |
| `rt.env` | The globals scripts see (`rt.env.Vector3`, `rt.env.task`, ...). |

### Matchers

`expect(x).toBe(y)`, `toEqual` (deep), `toBeNear(y, eps?)` (numbers, Vector2/3, CFrame,
Color3), `toBeTruthy`, `toBeFalsy`, `toBeNil`, `toBeGreaterThan`, `toBeGreaterThanOrEqual`,
`toBeLessThan`, `toBeLessThanOrEqual`, `toContain`, `toHaveLength`, `toBeA(typeName)`,
`toBeInstanceOf(className)`, `toMatch(pattern)`, `toThrow(substring?)`, `toBeFinite`. Negate
with `.never` (`expect(x).never.toBe(y)`). Also `T.beforeEach`, `T.afterEach`, `T.skip`,
`T.note`.

## Preview images (cloud tooling)

`tests/preview.luau` builds the hub, a map or a lobby section inside the harness and writes a
scene JSON for the offline previewer that lives in the cloud environment at
`/tmp/claude-0/render` (not part of this repo). From `new-game/`:

```sh
lune run tests/preview -- hub                         # -> tests/out/hub.json
lune run tests/preview -- map PumpkinPatch            # -> tests/out/PumpkinPatch.json
lune run tests/preview -- section ReadyArea           # src/server/Hub/Sections/ReadyArea.luau
lune run tests/preview -- hub out/hub.json            # or any output path

node /tmp/claude-0/render/render.mjs tests/out/hub.json tests/out/hub --views overview,top,ground
```

- `lune run tests/catwalk` (or `-- theme Pumpkin`, `-- ids A,B,C`, `--look preview`) dresses
  mannequins in crate skins and writes `tests/out/catwalk.json` the same way (see the comment at
  the top of `tests/catwalk.luau`).
- `hub` runs `HubBuilder.Build()`; `map` runs `MapService.Load(id)` (the map's builder, or a model
  in `ServerStorage.Maps`); `section` builds `Sections/<Name>` into an empty hub Model with
  `Build(hub, HubLayout.Zone(<Name>))`, the same zone `HubBuilder` gives every section (the
  Shop section is only the mat under the stall: the shopkeeper is an NPC, see `Hub/Npcs.luau`).
- Lighting comes from `Config.Hub.Lighting` or the map's `Lighting`; the terrain is the
  `Terrain:Fill*` calls the harness recorded (`Air` fills are exported but not drawn).
- The exporter is `/tmp/claude-0/render/export.luau` by default; point `--exporter <path>` or
  the `ROBLOX_PREVIEW_EXPORTER` environment variable elsewhere. Without it the script stops
  with a message saying so.
- The renderer writes `overview.png` (3/4 aerial view), `top.png` (map, north = -Z up) and
  `ground.png` (eye height from the south). See `/tmp/claude-0/render/README.md` for views,
  options and what is approximated.
- `tests/out/` and `out/` are git-ignored.

## How the harness works

| File | Role |
| --- | --- |
| `run.luau` | Finds and runs the specs, prints the report. |
| `harness/Runtime.luau` | One fake game: DataModel, require, scripts, players, helpers. |
| `harness/Project.luau` | Builds the tree from `default.project.json` (Rojo rules: `init.luau`, `.server/.client.luau`, `.meta.json`, `.json`, `.model.json`, `.txt`, `.rbxm/.rbxmx`), or converts a place file. |
| `harness/Dom.luau` | The instance tree: pure-Luau instances with Roblox semantics (members before children, type-checked properties, Destroy locks Parent, Clone remaps references, attributes, tags, structural events). |
| `harness/Engine.luau` | Real math: `Position`/`Orientation` vs `CFrame`, `GetPivot`/`PivotTo`, `GetBoundingBox`, `ScaleTo`, `BulkMoveTo`, attachments, humanoids, camera projection, raycasts. |
| `harness/Services.luau` | Deterministic services: Players, RunService, CollectionService, TweenService, DataStoreService (in memory, JSON), HttpService, MarketplaceService, TextService, PhysicsService, PathfindingService (straight lines), Debris, input services. |
| `harness/Globals.luau` | `task`, `Random`, `TweenInfo`, `DateTime`, `RaycastParams`, `OverlapParams`, virtual `tick`/`os.time`/`os.clock`, and a fixed `CFrame.lookAt` (Lune's is mirrored, see Limits) plus `CFrame.lookAlong` and `CFrame.new(pos, lookAt)`. |
| `preview.luau` | Exports the hub / a map / a lobby section as a scene JSON for the preview renderer (below). |
| `harness/Scheduler.luau` | Virtual time behind `task.*`. |
| `harness/Api.luau` | Generated list of every class's events, methods and callbacks. |

Lune's own `Instance` isn't used for the tree: it returns a new userdata on every access (so
instances can't be table keys), can't override built-in properties such as `Position`, and
panics if you parent into a destroyed instance. Datatypes (`Vector3`, `CFrame`, `Enum`, ...),
class/property information and defaults do come from Lune.

Every engine member exists: events from `Api.luau` are signals, and methods the harness
doesn't implement are no-op stubs that return a harmless default (`0`, `false`, `""`, `{}`, a
dummy connection) and are recorded for `rt:calls`. To refresh `Api.luau` after an engine
update, run `lune run tests/harness/tools/gen-api -- path/to/globalTypes.d.luau` (the
definitions file luau-lsp uses).

## Limits

- **No physics.** Nothing falls, collides or touches; `Touched` never fires unless a test
  fires it. Parts move only when code sets their `CFrame`/`Position`/pivot (`Humanoid:MoveTo`
  walks the character in a straight line over virtual time).
- **No real players or network.** Players are instances made by `rt:addPlayer`. Server and
  client are separate runtimes; nothing replicates unless you call `rt:replicateFrom`.
  `FireClient`/`FireServer` are only recorded; simulate the other side with
  `rt:fireServer` / `rt:invokeServer`.
- **Events never fire by themselves**, except the ones the harness simulates: structural ones
  (`ChildAdded`, `Destroying`, `Changed`, `AttributeChanged`, CollectionService signals),
  `RunService` per-frame events while time advances (only when something is connected),
  `Tween.Completed`, `Humanoid` `HealthChanged`/`Died`/`MoveToFinished`, `BindableEvent`.
- **No rendering, GUI layout, sound or terrain voxels.** GUI objects exist but sizes like
  `AbsoluteSize` read as zero; sounds are silent; Terrain methods are recorded no-ops.
- **Raycasts** test part shapes (blocks, balls, cylinders; wedges and meshes count as
  blocks) and ignore terrain and collision groups. Region queries use bounding boxes.
- **Time is virtual.** It only moves on `rt:advance`, `rt:call`, or `task.wait` outside a task
  thread (which advances the clock). `Signal:Wait()` only works inside a task thread;
  `WaitForChild` in a test body lets tasks run for up to 5 virtual seconds, then errors.
- **Random** is deterministic per seed but doesn't produce Roblox's exact numbers.
- **Approximate pivots**: a Model with no PrimaryPart whose pivot was never set pivots at the
  centre of its bounding box. `ScaleTo` scales parts, attachments, joints, nested models,
  SpecialMeshes, light ranges and HipHeight, not every scalable property.
- **Lune 0.8.9's `CFrame.lookAt` is wrong** (it mirrors the look direction's Z: a target at +Z
  gives a LookVector of -Z). The `CFrame` scripts see in the harness is fixed (`harness.spec`
  checks it); if you use `require("@lune/roblox").CFrame` directly in a spec, use
  `rt.env.CFrame` instead.
- **Lune 0.8.9 gaps**: `number * Vector3` (number first) and `number / Vector3` error, write
  `vector * number`; EnumItems aren't stable table keys; `EnumItem:IsA`,
  `CFrame:FuzzyEq` and `CFrame:AngleBetween` don't exist; classes or properties newer than
  Lune's reflection database (2024) report "not a valid member".
- Unknown services (`GetService` of a class Lune doesn't know) get a permissive fake that logs
  a warning; DataStores are in-memory JSON; HTTP errors unless a test sets `rt.httpHandler`.
