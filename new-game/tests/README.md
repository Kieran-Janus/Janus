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
puts `lune` on your PATH (it is pinned in `rokit.toml`; the harness was written against
Lune 0.8.9). Rojo is **not** needed: the harness reads `default.project.json` and the files
itself.

The runner prints one line per test, a summary, and exits with code 1 if anything failed. A
test fails when it throws, or when game code it ran threw inside a task thread (`task.spawn`,
an event handler, a Script), even if the test itself didn't notice.

## What the specs cover

| Spec | Checks |
| --- | --- |
| `config.spec` | Shop items: unique Ids, known Slot, whole non-negative Price, Style.Kind; NPCs: Id, Kind, Offset, prompt; maps: unique ids, builder module exists, sizes; codes only give real items. |
| `builders.spec` | `HubBuilder.Build()` and every map builder in `src/server/Maps` run, make parts with finite, positive sizes, are deterministic; custom NPC models in `ReplicatedStorage.Custom.Characters` are scaled and placed; `MapService.Load` finds floor, spawns and random floor points (raycasts hit real geometry). Notes how many Ball parts have unequal sides (Roblox renders those as spheres). |
| `cosmetics.spec` | Every shop item: `Cosmetics.Preview`, `Cosmetics.Build` (pivot at the design origin), `Cosmetics.Wear` / `TakeOff` on a character, skins restore the avatar, a custom model in `ReplicatedStorage.Custom.Cosmetics` replaces the placeholder and is scaled. |
| `modules.spec` | Every ModuleScript requires cleanly (server, shared, client); `Main.server.luau` boots and plays a whole round with a player in it; `Main.client.luau` boots against what the server replicated. |
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
| `rt:calls("Class", "Method")` | Calls made to engine methods the harness only stubs (`Terrain:FillBall`, `RemoteEvent:FireClient`, `Sound:Play`, ...). |
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

## How the harness works

| File | Role |
| --- | --- |
| `run.luau` | Finds and runs the specs, prints the report. |
| `harness/Runtime.luau` | One fake game: DataModel, require, scripts, players, helpers. |
| `harness/Project.luau` | Builds the tree from `default.project.json` (Rojo rules: `init.luau`, `.server/.client.luau`, `.meta.json`, `.json`, `.model.json`, `.txt`, `.rbxm/.rbxmx`), or converts a place file. |
| `harness/Dom.luau` | The instance tree: pure-Luau instances with Roblox semantics (members before children, type-checked properties, Destroy locks Parent, Clone remaps references, attributes, tags, structural events). |
| `harness/Engine.luau` | Real math: `Position`/`Orientation` vs `CFrame`, `GetPivot`/`PivotTo`, `GetBoundingBox`, `ScaleTo`, `BulkMoveTo`, attachments, humanoids, camera projection, raycasts. |
| `harness/Services.luau` | Deterministic services: Players, RunService, CollectionService, TweenService, DataStoreService (in memory, JSON), HttpService, MarketplaceService, TextService, PhysicsService, PathfindingService (straight lines), Debris, input services. |
| `harness/Globals.luau` | `task`, `Random`, `TweenInfo`, `DateTime`, `RaycastParams`, `OverlapParams`, virtual `tick`/`os.time`/`os.clock`. |
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
- **Lune 0.8.9 gaps**: `number * Vector3` (number first) and `number / Vector3` error, write
  `vector * number`; EnumItems aren't stable table keys; `EnumItem:IsA`,
  `CFrame:FuzzyEq` and `CFrame:AngleBetween` don't exist; classes or properties newer than
  Lune's reflection database (2024) report "not a valid member".
- Unknown services (`GetService` of a class Lune doesn't know) get a permissive fake that logs
  a warning; DataStores are in-memory JSON; HTTP errors unless a test sets `rt.httpHandler`.
