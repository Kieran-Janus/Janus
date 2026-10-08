-- Pumpkin Hide & Seek: the rules (src/server/Modes/HideSeekRules.luau), its two maps (Pumpkin
-- Farm, Hedge Maze) and whole rounds of src/server/Modes/HideSeek.luau with fake players:
-- roles, the pumpkin disguise, the candy gun (server checks), tagging, leaving, results.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

describe("Hide & Seek rules", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Rules = rt:require("ServerScriptService.Server.Modes.HideSeekRules")
	local Random = rt.env.Random
	local cfg = Config.HideSeek

	it("has its settings", function()
		for _, key in
			{
				"SeekerRatio",
				"MinSeekers",
				"TaggedSeekerDelay",
				"HeadStart",
				"Duration",
				"GiggleInterval",
				"GiggleJitter",
				"FirstGiggleAfter",
				"TrailMinSpeed",
				"GlowLastSeconds",
			}
		do
			expect(cfg[key]).toBeA("number")
		end
		expect(cfg.HeadStart + cfg.Duration).toBe(180) -- a 3 minute round
		expect(cfg.TaggedBecomeSeekers).toBeA("boolean")
		for _, key in
			{ "FireCooldown", "DecoyPenalty", "MaxRange", "HitTolerance", "ProjectileSpeed" }
		do
			expect(cfg.Gun[key]).toBeGreaterThan(0)
		end
		for _, key in { "PerTag", "HiderSurvived", "PerMinuteHidden", "WinningTeam", "Played" } do
			expect(cfg.Rewards[key]).toBeGreaterThanOrEqual(0)
		end
		for _, key in { "HiderRole", "SeekerRole", "Counting", "ScoreLabel", "MvpLine", "TaggedBy" } do
			expect(cfg.Text[key]).toBeA("string")
		end
		expect(Config.Modes.List.HideSeek).toBeTruthy()
	end)

	it("picks a quarter of the players as seekers, at least one, never everyone", function()
		local expected =
			{ [2] = 1, [3] = 1, [4] = 1, [7] = 1, [8] = 2, [12] = 3, [16] = 4, [32] = 8 }
		for players, seekers in expected do
			expect(Rules.SeekerCount(players, cfg)).toBe(seekers)
		end
		for players = 2, 32 do
			local seekers = Rules.SeekerCount(players, cfg)
			expect(seekers).toBeGreaterThanOrEqual(1)
			expect(seekers).toBeLessThan(players)
		end
		expect(Rules.SeekerCount(0, cfg)).toBe(0)
		expect(Rules.SeekerCount(1, { SoloRole = "Seeker", SeekerRatio = 0.25, MinSeekers = 1 })).toBe(
			1
		)
		expect(Rules.SeekerCount(1, { SoloRole = "Hider", SeekerRatio = 0.25, MinSeekers = 1 })).toBe(
			0
		)
		-- Even a big MinSeekers leaves one hider.
		expect(Rules.SeekerCount(3, { SeekerRatio = 0.25, MinSeekers = 5 })).toBe(2)
	end)

	it("splits the players and puts last round's seekers at the back of the queue", function()
		local list = { "a", "b", "c", "d", "e", "f", "g", "h" }
		local seekers, hiders = Rules.PickSeekers(list, 2, Random.new(1))
		expect(#seekers).toBe(2)
		expect(#hiders).toBe(6)
		local all = {}
		for _, name in seekers do
			all[name] = true
		end
		for _, name in hiders do
			expect(all[name]).toBeNil()
			all[name] = true
		end
		for _, name in list do
			expect(all[name]).toBe(true)
		end
		-- Whoever sought last time is never picked again while others are free.
		for seed = 1, 20 do
			local again =
				Rules.PickSeekers(list, 2, Random.new(seed), { a = true, b = true, c = true })
			for _, name in again do
				expect(name == "a" or name == "b" or name == "c").toBe(false)
			end
		end
		expect(Rules.Promote({}, Random.new(1))).toBeNil()
		expect(Rules.Promote({ "x" }, Random.new(1))).toBe("x")
	end)

	it("decides who won", function()
		local function winner(startedHiders, startedSeekers, hiders, seekers, timeUp)
			return Rules.Winner({
				StartedHiders = startedHiders,
				StartedSeekers = startedSeekers,
				HidersLeft = hiders,
				SeekersLeft = seekers,
				TimeUp = timeUp,
			})
		end
		expect(winner(3, 1, 0, 4, false)).toBe("Seekers") -- every pumpkin found
		expect(winner(3, 1, 2, 2, false)).toBeNil() -- still playing
		expect(winner(3, 1, 2, 2, true)).toBe("Hiders") -- time's up, two still hidden
		expect(winner(3, 1, 2, 0, false)).toBe("Hiders") -- every seeker left
		expect(winner(0, 1, 0, 1, false)).toBeNil() -- solo practice: never ends early
		expect(winner(0, 1, 0, 1, true)).toBeNil()
		expect(winner(1, 0, 1, 0, false)).toBeNil() -- solo pumpkin: never ends early
		expect(winner(1, 0, 1, 0, true)).toBe("Hiders")
	end)

	it("scores tags, hidden pumpkins and the winning side", function()
		local r = cfg.Rewards
		local entries = {
			{
				UserId = 1,
				Name = "Seeker",
				StartRole = "Seeker",
				Tags = 2,
				Found = false,
				HiddenSeconds = 0,
			},
			{
				UserId = 2,
				Name = "Found",
				StartRole = "Hider",
				Tags = 1,
				Found = true,
				HiddenSeconds = 125,
			},
			{
				UserId = 3,
				Name = "Hidden",
				StartRole = "Hider",
				Tags = 0,
				Found = false,
				HiddenSeconds = 165,
			},
		}
		local rows = Rules.Results(entries, "Hiders", cfg)
		expect(#rows).toBe(3)
		expect(rows[1].Name).toBe("Seeker")
		expect(rows[1].Score).toBe(2)
		expect(rows[1].Pumpkins).toBe(2)
		expect(rows[1].Top).toBe(true)
		expect(rows[1].Won).toBe(false)
		expect(rows[1].Coins).toBe(r.Played + 2 * r.PerTag)
		expect(rows[1].Team).toBe(cfg.Text.TeamSeeker)
		expect(rows[2].Name).toBe("Found")
		expect(rows[2].Coins).toBe(r.Played + r.PerTag + 2 * r.PerMinuteHidden)
		expect(rows[2].Badge).toBe(cfg.Text.BadgeFound)
		expect(rows[2].Stat).toBe(cfg.Text.StatHidden:format(2, 5))
		expect(rows[3].Name).toBe("Hidden")
		expect(rows[3].Survived).toBe(true)
		expect(rows[3].Won).toBe(true)
		expect(rows[3].Top).toBe(true) -- a winning hidden pumpkin
		expect(rows[3].Coins).toBe(r.Played + r.HiderSurvived + r.WinningTeam)
		expect(rows[3].Badge).toBe(cfg.Text.BadgeHidden)

		-- Seekers win: found pumpkins that joined them win too.
		entries[3].Found = true
		local won = Rules.Results(entries, "Seekers", cfg)
		for _, row in won do
			expect(row.Won).toBe(true)
		end
		expect(won[1].Survived).toBe(true) -- a winning seeker gets the green badge
	end)
end)

-- Every part tagged `tag` inside `model`.
local function taggedIn(rt: any, model: any, tag: string): { any }
	local list = {}
	for _, instance in rt.game:GetService("CollectionService"):GetTagged(tag) do
		if instance:IsDescendantOf(model) then
			table.insert(list, instance)
		end
	end
	return list
end

describe("Hide & Seek maps", function()
	local rt = Runtime.new()
	local MapService = rt:require("ServerScriptService.Server.Services.MapService")

	for _, id in { "PumpkinFarm", "HedgeMaze", "MidnightMarket" } do
		it(("builds %s with a floor, spawns, a seeker hut and decoys"):format(id), function()
			local map = MapService.Load(id)
			expect(map.Id).toBe(id) -- not a fallback map
			expect(map.Floor).toBeInstanceOf("Part")
			expect(#map.Spawns).toBeGreaterThanOrEqual(8)
			local hiderSpawns = taggedIn(rt, map.Model, "HiderSpawn")
			expect(#hiderSpawns).toBe(#map.Spawns)
			expect(#taggedIn(rt, map.Model, "SeekerSpawn")).toBeGreaterThanOrEqual(4)
			local doors = taggedIn(rt, map.Model, "SeekerDoor")
			expect(#doors).toBe(1)
			expect(doors[1]:IsA("BasePart")).toBe(true)
			local decoys = taggedIn(rt, map.Model, "HidingDecoy")
			expect(#decoys).toBeGreaterThanOrEqual(if id == "HedgeMaze" then 40 else 90)
			-- Spawns stand on the floor, inside the map.
			for _, spawn in hiderSpawns do
				local offset = map.Floor.CFrame:PointToObjectSpace(spawn.Position)
				expect(math.abs(offset.X)).toBeLessThan(map.Floor.Size.X / 2)
				expect(math.abs(offset.Z)).toBeLessThan(map.Floor.Size.Z / 2)
			end
			local parts = #rt:parts(map.Model)
			T.note(("%d parts, %d decoys, %d hider spawns"):format(parts, #decoys, #hiderSpawns))
			if id == "HedgeMaze" then
				expect(parts).toBeLessThan(1500)
			end
			MapService.Unload()
		end)
	end

	it("shuffles the Midnight Market's decoys and spawns every round", function()
		local function layout(): string
			local map = MapService.Load("MidnightMarket")
			local spots = {}
			for _, decoy in taggedIn(rt, map.Model, "HidingDecoy") do
				local p = decoy:GetPivot().Position
				table.insert(spots, ("%d,%d"):format(math.floor(p.X), math.floor(p.Z)))
			end
			table.sort(spots)
			local parts = #rt:parts(map.Model)
			expect(parts).toBeLessThan(3000)
			MapService.Unload()
			return table.concat(spots, ";")
		end
		expect(layout()).never.toBe(layout())
	end)

	it("builds the same maps every time", function()
		local counts = {}
		for round = 1, 2 do
			local map = MapService.Load("HedgeMaze")
			counts[round] = #rt:parts(map.Model)
			MapService.Unload()
		end
		expect(counts[1]).toBe(counts[2])
	end)

	it("makes a Hedge Maze where every spawn and the plaza can reach the hut", function()
		local Config = rt:require("ReplicatedStorage.Shared.Config")
		local HedgeMaze = rt:require("ServerScriptService.Server.Maps.HedgeMaze")
		local MazeGen = rt:require("ServerScriptService.Server.Maps.MazeGen")
		local def = MapService.Get("HedgeMaze")
		local plan = HedgeMaze.Plan(def)
		expect(#plan.SpawnCells).toBe(def.Spawns)
		expect(#plan.DeadEnds).toBeGreaterThan(5)
		for _, cell in plan.SpawnCells do
			expect(MazeGen.Solve(plan.Maze, plan.HutCell, cell)).toBeTruthy()
		end
		local plaza = { X = plan.Plaza.X + 1, Y = plan.Plaza.Y + 1 }
		expect(MazeGen.Solve(plan.Maze, plan.HutCell, plaza)).toBeTruthy()
		-- Every cell is reachable (nowhere to get stuck, no sealed-off pumpkins).
		local cells = def.Layout.Cells
		for x = 1, cells do
			for y = 1, cells do
				if not MazeGen.Solve(plan.Maze, plan.HutCell, { X = x, Y = y }) then
					error(("cell %d,%d can't be reached"):format(x, y))
				end
			end
		end
		expect(Config.Maps.List).toBeTruthy()
	end)
end)

-- A round of Hide & Seek on the Pumpkin Farm, driven step by step. `setup(rt, players, map)`
-- (optional) runs once the players' saves and the map are loaded, just before the round.
local function newRound(playerCount: number, setup: ((any, { any }, any) -> ())?, mapId: string?)
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local DataService = rt:require("ServerScriptService.Server.Services.DataService")
	local MapService = rt:require("ServerScriptService.Server.Services.MapService")
	local HideSeek = rt:require("ServerScriptService.Server.Modes.HideSeek")
	local RS = rt.game:GetService("ReplicatedStorage")
	DataService.Start()
	local players = {}
	for i = 1, playerCount do
		table.insert(players, rt:addPlayer({ Name = "Player" .. i }))
	end
	rt:advance(1)
	local map = MapService.Load(mapId or "PumpkinFarm")
	if setup then
		setup(rt, players, map)
	end
	local state = { Result = nil :: any, Done = false }
	local ctx = {
		Map = map,
		Players = players,
		Difficulty = "Easy",
		Playlist = {
			Id = "HideSeekTest",
			Mode = "HideSeek",
			Map = mapId or "PumpkinFarm",
			Name = "Test",
		},
		SetState = function(s, timeLeft)
			RS:SetAttribute("State", s)
			RS:SetAttribute("TimeLeft", timeLeft)
		end,
		Countdown = function(s, seconds, stopIf)
			for remaining = seconds, 1, -1 do
				if stopIf and stopIf() then
					return
				end
				RS:SetAttribute("State", s)
				RS:SetAttribute("TimeLeft", remaining)
				rt.env.task.wait(1)
			end
		end,
		Teleport = function(player, spawn)
			player.Character:PivotTo(
				rt.env.CFrame.new(spawn.Position + rt.env.Vector3.new(0, 4, 0))
			)
		end,
		AliveHumanoid = function(player)
			local character = player.Character
			return character and character:FindFirstChildOfClass("Humanoid")
		end,
	}
	rt.scheduler:spawn(function()
		state.Result = HideSeek.Run(ctx)
		state.Done = true
	end)
	rt:advance(0.5)
	local remotes = RS:WaitForChild("Remotes")
	local round = {
		rt = rt,
		Config = Config,
		DataService = DataService,
		HideSeek = HideSeek,
		RS = RS,
		map = map,
		players = players,
		state = state,
		shoot = remotes:FindFirstChild("HideSeekShoot"),
		events = remotes:FindFirstChild("HideSeekEvent"),
	}
	function round.role(player)
		return player:GetAttribute("HideSeekRole")
	end
	function round.withRole(role)
		local list = {}
		for _, player in players do
			if player.Parent and player:GetAttribute("HideSeekRole") == role then
				table.insert(list, player)
			end
		end
		return list
	end
	function round.pumpkinOf(player)
		local folder = map.Model:FindFirstChild("HiderPumpkins")
		for _, model in folder and folder:GetChildren() or {} do
			if model:GetAttribute("HiderUserId") == player.UserId then
				return model
			end
		end
		return nil
	end
	-- Server events of one kind, in order.
	function round.sent(kind)
		local list = {}
		for _, call in rt:calls("RemoteEvent", "FireAllClients") do
			if call.instance == round.events and call.args[1] == kind then
				table.insert(list, call.args[2])
			end
		end
		return list
	end
	-- Stands the seeker 12 studs from `target` (east of it), gun out, and fires at it.
	function round.shootAt(seeker, target)
		local character = seeker.Character
		local Vector3 = rt.env.Vector3
		local CFrame = rt.env.CFrame
		character:PivotTo(CFrame.new(target + Vector3.new(12, 1.5, 0), target))
		local gun = seeker.Backpack:FindFirstChildOfClass("Tool")
			or character:FindFirstChildOfClass("Tool")
		if gun then
			gun.Parent = character -- (Humanoid:EquipTool is only recorded in the harness)
		end
		rt:fireServer(round.shoot, seeker, target)
	end
	return round
end

describe("A Hide & Seek round (4 players)", function()
	local round = newRound(4)
	local rt, Config, RS = round.rt, round.Config, round.RS
	local cfg = Config.HideSeek
	local seeker, hiders

	it("picks one seeker and three pumpkins, and hides the pumpkins", function()
		expect(round.shoot).toBeInstanceOf("RemoteEvent")
		expect(round.events).toBeInstanceOf("RemoteEvent")
		expect(RS:GetAttribute("State")).toBe("Hiding")
		local seekers = round.withRole("Seeker")
		hiders = round.withRole("Hider")
		expect(#seekers).toBe(1)
		expect(#hiders).toBe(3)
		seeker = seekers[1]
		expect(RS:GetAttribute("HidersLeft")).toBe(3)
		expect(RS:GetAttribute("SeekerCount")).toBe(1)
		for _, hider in hiders do
			local pumpkin = round.pumpkinOf(hider)
			expect(pumpkin).toBeInstanceOf("Model")
			expect(rt.game:GetService("CollectionService"):HasTag(pumpkin, "HidingDecoy")).toBe(
				false
			)
			local head = hider.Character:FindFirstChild("Head")
			expect(head.Transparency).toBe(1)
			expect(head:FindFirstChild("face").Transparency).toBe(1)
			expect(hider.Character:FindFirstChildOfClass("Humanoid").DisplayDistanceType.Name).toBe(
				"None"
			)
			-- The pumpkin sits on the ground under the hider and is welded to them.
			local body = pumpkin.PrimaryPart
			expect(body.Anchored).toBe(false)
			expect(body:FindFirstChildOfClass("WeldConstraint").Part0).toBe(
				hider.Character.HumanoidRootPart
			)
		end
		-- The seeker waits in the hut, frozen.
		expect(seeker.Character.HumanoidRootPart.Anchored).toBe(true)
		local hut = round.map.Model:FindFirstChild("SeekerHut", true)
		local offset = hut:GetPivot():PointToObjectSpace(seeker.Character.HumanoidRootPart.Position)
		expect(math.abs(offset.X)).toBeLessThan(8)
		expect(math.abs(offset.Z)).toBeLessThan(8)
	end)

	it("ignores shots while the seekers are still counting", function()
		local pumpkin = round.pumpkinOf(hiders[1])
		round.shootAt(seeker, pumpkin.PrimaryPart.Position)
		expect(#round.sent("Shot")).toBe(0)
		expect(round.role(hiders[1])).toBe("Hider")
		seeker.Character.HumanoidRootPart.Anchored = true -- (shootAt moved it)
	end)

	it("lets the seekers out with candy guns after the head start", function()
		rt:advance(cfg.HeadStart + 0.5)
		expect(RS:GetAttribute("State")).toBe("Playing")
		expect(seeker.Character.HumanoidRootPart.Anchored).toBe(false)
		local gun = seeker.Backpack:FindFirstChildOfClass("Tool")
		expect(gun).toBeInstanceOf("Tool")
		expect(gun:GetAttribute("CandyGun")).toBe(true)
		expect(#round.sent("Released")).toBe(1)
		local door = rt.game:GetService("CollectionService"):GetTagged("SeekerDoor")[1]
		expect(door.CanCollide).toBe(false)
	end)

	it("rejects bad shots: not a seeker, junk targets, gun put away", function()
		local pumpkin = round.pumpkinOf(hiders[1])
		rt:fireServer(round.shoot, hiders[2], pumpkin.PrimaryPart.Position) -- a hider
		rt:fireServer(round.shoot, seeker, "nope")
		rt:fireServer(round.shoot, seeker, rt.env.Vector3.new(0 / 0, 0, 0))
		-- The gun is in the backpack (not held): no shot.
		rt:fireServer(round.shoot, seeker, pumpkin.PrimaryPart.Position)
		expect(#round.sent("Shot")).toBe(0)
		expect(RS:GetAttribute("HidersLeft")).toBe(3)
	end)

	it("tags a hider whose pumpkin the candy hits; they join the seekers", function()
		local hider = hiders[1]
		local pumpkin = round.pumpkinOf(hider)
		round.shootAt(seeker, pumpkin.PrimaryPart.Position)
		local shots = round.sent("Shot")
		expect(#shots).toBe(1)
		expect(shots[1].Result).toBe("Hider")
		expect(shots[1].Shooter).toBe(seeker)
		expect(#round.sent("Tagged")).toBe(1)
		expect(round.sent("Tagged")[1].Hider).toBe(hider)
		expect(round.role(hider)).toBe("Seeker")
		expect(RS:GetAttribute("HidersLeft")).toBe(2)
		expect(RS:GetAttribute("SeekerCount")).toBe(2)
		expect(seeker:GetAttribute("HideSeekTags")).toBe(1)
		expect(round.DataService.Get(seeker).Stats.HideSeekTags).toBe(1)
		expect(pumpkin.Parent).toBeNil() -- the pumpkin is gone...
		expect(hider.Character:FindFirstChild("Head").Transparency).toBe(0) -- ...and they're back
		-- After a moment they get their own candy gun.
		rt:advance(cfg.TaggedSeekerDelay + 0.5)
		expect(hider.Backpack:FindFirstChildOfClass("Tool")).toBeInstanceOf("Tool")
	end)

	it("makes you wait between candies, longer after hitting a decoy", function()
		local target = round.pumpkinOf(hiders[2]).PrimaryPart.Position
		-- A decoy: stand next to one and shoot it.
		local decoy = nil
		for _, model in rt.game:GetService("CollectionService"):GetTagged("HidingDecoy") do
			if model:IsDescendantOf(round.map.Model) and model.Parent.Name == "Decoys" then
				decoy = model
				break
			end
		end
		expect(decoy).toBeTruthy()
		round.shootAt(seeker, decoy.PrimaryPart.Position)
		local shots = round.sent("Shot")
		expect(#shots).toBe(2)
		expect(shots[2].Result).toBe("Decoy")
		expect(shots[2].Cooldown).toBeNear(cfg.Gun.FireCooldown + cfg.Gun.DecoyPenalty)
		round.shootAt(seeker, target) -- straight away: too soon
		expect(#round.sent("Shot")).toBe(2)
		rt:advance(cfg.Gun.FireCooldown + 0.1) -- a normal wait isn't enough after a decoy
		round.shootAt(seeker, target)
		expect(#round.sent("Shot")).toBe(2)
		expect(RS:GetAttribute("HidersLeft")).toBe(2)
	end)

	it("giggles: every hider gets a giggle now and then", function()
		rt:advance(cfg.FirstGiggleAfter + cfg.GiggleJitter + 1)
		local giggles = round.sent("Giggle")
		expect(#giggles).toBeGreaterThanOrEqual(2)
		expect(giggles[1].Pumpkin).toBeInstanceOf("Model")
	end)

	it("ends when every pumpkin is found: the seekers win", function()
		rt:advance(cfg.Gun.DecoyPenalty + 1)
		for _, hider in round.withRole("Hider") do
			rt:advance(cfg.Gun.FireCooldown + 0.1)
			round.shootAt(seeker, round.pumpkinOf(hider).PrimaryPart.Position)
		end
		expect(RS:GetAttribute("HidersLeft")).toBe(0)
		rt:advance(2)
		expect(round.state.Done).toBe(true)
		local result = round.state.Result
		expect(result.ScoreLabel).toBe(cfg.Text.ScoreLabel)
		expect(result.Winner).toBe(cfg.Text.SeekersWin)
		expect(#result.Rows).toBe(4)
		local top = result.Rows[1]
		expect(top.UserId).toBe(seeker.UserId)
		expect(top.Score).toBe(3)
		expect(top.Top).toBe(true)
		expect(top.Team).toBe(cfg.Text.TeamSeeker)
		for _, row in result.Rows do
			expect(row.Coins).toBeGreaterThan(0)
			expect(row.Team).toBeA("string")
		end
		expect(round.DataService.Get(seeker).Stats.HideSeekWins).toBe(1)
		expect(round.DataService.Get(seeker).Stats.HideSeekTags).toBe(3)
	end)

	it("cleans up after itself", function()
		expect(round.map.Model:FindFirstChild("HiderPumpkins")).toBeNil()
		expect(RS:GetAttribute("HidersLeft")).toBeNil()
		expect(RS:GetAttribute("SeekerCount")).toBeNil()
		for _, player in round.players do
			expect(player:GetAttribute("HideSeekRole")).toBeNil()
			expect(player.Backpack:FindFirstChildOfClass("Tool")).toBeNil()
		end
		round.HideSeek.Cleanup() -- safe with nothing running
	end)
end)

describe("Hide & Seek with players leaving", function()
	it("makes a hider the seeker if every seeker leaves while counting", function()
		local round = newRound(3)
		local seeker = round.withRole("Seeker")[1]
		round.rt:removePlayer(seeker)
		local seekers = round.withRole("Seeker")
		expect(#seekers).toBe(1)
		expect(#round.withRole("Hider")).toBe(1)
		expect(round.pumpkinOf(seekers[1])).toBeNil()
		expect(seekers[1].Character.HumanoidRootPart.Anchored).toBe(true)
		round.HideSeek.Cleanup()
	end)

	it("ends with the pumpkins winning when every seeker leaves mid-round", function()
		local round = newRound(2)
		local cfg = round.Config.HideSeek
		round.rt:advance(cfg.HeadStart + 1)
		expect(round.RS:GetAttribute("State")).toBe("Playing")
		local seeker = round.withRole("Seeker")[1]
		local hider = round.withRole("Hider")[1]
		round.rt:removePlayer(seeker)
		round.rt:advance(2)
		expect(round.state.Done).toBe(true)
		local result = round.state.Result
		expect(result.Winner).toBe(cfg.Text.NoSeekers)
		expect(#result.Rows).toBe(1)
		expect(result.Rows[1].UserId).toBe(hider.UserId)
		expect(result.Rows[1].Survived).toBe(true)
		expect(round.DataService.Get(hider).Stats.HideSeekWins).toBe(1)
	end)

	it("plays a solo practice round to the end", function()
		local round = newRound(1)
		local cfg = round.Config.HideSeek
		expect(round.role(round.players[1])).toBe(cfg.SoloRole)
		round.rt:advance(cfg.HeadStart + cfg.Duration - 5)
		expect(round.state.Done).toBe(false)
		round.rt:advance(10)
		expect(round.state.Done).toBe(true)
		expect(round.state.Result.Winner).toBeA("string")
	end)
end)

-- Every BasePart and Decal of a character that can be seen (1 = invisible).
local function visibleParts(character: any): { string }
	local list = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and d.Transparency < 1 then
			table.insert(list, d:GetFullName())
		end
	end
	return list
end

describe("Hide & Seek fair play", function()
	it("keeps a hider hidden when the shop dresses them; found, their look comes back", function()
		local skin
		local round = newRound(2, function(rt, players)
			local Config = rt:require("ReplicatedStorage.Shared.Config")
			local DataService = rt:require("ServerScriptService.Server.Services.DataService")
			local ShopService = rt:require("ServerScriptService.Server.Services.ShopService")
			-- A see-through skin (Ghost-like): wearing it again used to show the whole body.
			for _, item in Config.Shop.Items do
				local style = item.Style
				if item.Slot == "Skin" and style and type(style.Transparency) == "number" then
					skin = item
					break
				end
			end
			expect(skin).toBeTruthy()
			for _, player in players do
				local data = DataService.Get(player)
				data.Owned[skin.Id] = true
				data.Equipped.Skin = skin.Id
				ShopService.Dress(player)
			end
		end)
		local rt = round.rt
		local ShopService = rt:require("ServerScriptService.Server.Services.ShopService")
		local hider = round.withRole("Hider")[1]
		local seeker = round.withRole("Seeker")[1]
		expect(#visibleParts(hider.Character)).toBe(0)
		-- Equipping (or buying) anything mid-round dresses the character again.
		round.DataService.Get(hider).Equipped.Skin = ""
		ShopService.Dress(hider)
		round.DataService.Get(hider).Equipped.Skin = skin.Id
		ShopService.Dress(hider)
		rt:advance(0.1)
		expect(#visibleParts(hider.Character)).toBe(0)
		expect(round.DataService.Get(hider).Equipped.Skin).toBe(skin.Id) -- still saved
		-- Found: their own look (the skin they had on) comes back.
		rt:advance(round.Config.HideSeek.HeadStart + 0.5)
		round.shootAt(seeker, round.pumpkinOf(hider).PrimaryPart.Position)
		expect(round.role(hider)).toBe("Seeker")
		rt:advance(0.1)
		local head = hider.Character:FindFirstChild("Head")
		expect(head.Transparency).toBeLessThan(1)
		expect(head:GetAttribute("Skin_Transparency")).never.toBeNil() -- the skin is on again
		round.HideSeek.Cleanup()
	end)

	it(
		"keeps a reset hider's pumpkin in place (it can still be found) and brings them back",
		function()
			local round = newRound(3)
			local rt, cfg = round.rt, round.Config.HideSeek
			rt:advance(cfg.HeadStart + 0.5)
			expect(round.RS:GetAttribute("State")).toBe("Playing")
			local seeker = round.withRole("Seeker")[1]
			local hiders = round.withRole("Hider")
			local stayer, caught = hiders[1], hiders[2]

			-- Esc > Reset: the pumpkin stays (anchored), the hider is still a hider.
			local pumpkin = round.pumpkinOf(stayer)
			local spot = pumpkin:GetPivot().Position
			stayer.Character:FindFirstChildOfClass("Humanoid").Health = 0
			rt:advance(0.1)
			expect(round.pumpkinOf(stayer)).toBe(pumpkin)
			expect(pumpkin.PrimaryPart.Anchored).toBe(true)
			expect(round.role(stayer)).toBe("Hider")
			expect(round.RS:GetAttribute("HidersLeft")).toBe(2)
			-- Respawning puts them back on that spot as the same pumpkin, not on a hider spawn.
			local color = pumpkin.PrimaryPart.Color
			rt:spawnCharacter(stayer)
			rt:advance(0.5)
			local again = round.pumpkinOf(stayer)
			expect(again).toBeTruthy()
			expect(again).never.toBe(pumpkin)
			expect(pumpkin.Parent).toBeNil()
			expect(again.PrimaryPart.Color).toBeNear(color)
			local root = stayer.Character.HumanoidRootPart.Position
			expect(math.abs(root.X - spot.X) + math.abs(root.Z - spot.Z)).toBeLessThan(0.5)
			expect(#visibleParts(stayer.Character)).toBe(0)

			-- A seeker can still tag the pumpkin of a hider who is waiting to respawn.
			caught.Character:FindFirstChildOfClass("Humanoid").Health = 0
			rt:advance(0.1)
			local waiting = round.pumpkinOf(caught)
			expect(waiting).toBeTruthy()
			round.shootAt(seeker, waiting.PrimaryPart.Position)
			expect(round.role(caught)).toBe("Seeker")
			expect(round.RS:GetAttribute("HidersLeft")).toBe(1)
			expect(waiting.Parent).toBeNil()
			round.HideSeek.Cleanup()
		end
	)

	it("lines extra seekers up in the hut instead of stacking them on the 4 pads", function()
		local round = newRound(24) -- 6 seekers
		local seekers = round.withRole("Seeker")
		expect(#seekers).toBe(6)
		local hut = round.map.Model:FindFirstChild("SeekerHut", true)
		for i, a in seekers do
			local pa = a.Character.HumanoidRootPart.Position
			local offset = hut:GetPivot():PointToObjectSpace(pa)
			expect(math.abs(offset.X)).toBeLessThan(7)
			expect(math.abs(offset.Z)).toBeLessThan(7)
			for j = i + 1, #seekers do
				local pb = seekers[j].Character.HumanoidRootPart.Position
				local apart = math.sqrt((pa.X - pb.X) ^ 2 + (pa.Z - pb.Z) ^ 2)
				expect(apart).toBeGreaterThan(2.5)
			end
		end
		round.HideSeek.Cleanup()
	end)

	it(
		"dresses hiders as copies of the map's own decoys (a hand-edited map still matches)",
		function()
			local color = nil
			local round = newRound(3, function(rt, _players, map)
				-- As if the decoys of a baked map had been recoloured by hand.
				color = rt.env.Color3.fromRGB(40, 200, 250)
				for _, decoy in rt.game:GetService("CollectionService"):GetTagged("HidingDecoy") do
					if decoy:IsDescendantOf(map.Model) then
						for _, d in decoy:GetDescendants() do
							if d:IsA("BasePart") then
								d.Color = color
							end
						end
					end
				end
			end)
			local CollectionService = round.rt.game:GetService("CollectionService")
			for _, hider in round.withRole("Hider") do
				local pumpkin = round.pumpkinOf(hider)
				expect(pumpkin).toBeTruthy()
				expect(pumpkin.PrimaryPart.Color).toBeNear(color)
				expect(pumpkin:GetAttribute("PumpkinWidth")).toBeA("number")
				expect(CollectionService:HasTag(pumpkin, "HidingDecoy")).toBe(false)
			end
			round.HideSeek.Cleanup()
		end
	)
end)

describe("Hide & Seek on the lobby's screens", function()
	local client = Runtime.new({ client = true })
	local RS = client.game:GetService("ReplicatedStorage")
	local me = client.localPlayer
	-- What the server would have replicated once a Hide & Seek round is on.
	local remotes = client:create("Folder", { Name = "Remotes" }, RS)
	client:create("RemoteEvent", { Name = "HideSeekEvent" }, remotes)
	client:create("RemoteEvent", { Name = "HideSeekShoot" }, remotes)
	local SpectateTargets =
		client:require("StarterPlayer.StarterPlayerScripts.Client.SpectateTargets")

	it("never lets spectators watch a hidden pumpkin", function()
		local hider = client:addPlayer({ Name = "Pumpkin", character = false })
		local seeker = client:addPlayer({ Name = "Seeker", character = false })
		for _, player in { hider, seeker } do
			player:SetAttribute("InRound", true)
		end
		hider:SetAttribute("HideSeekRole", "Hider")
		seeker:SetAttribute("HideSeekRole", "Seeker")
		RS:SetAttribute("Mode", "HideSeek")
		local list = SpectateTargets.List()
		expect(table.find(list, seeker)).toBeTruthy()
		expect(table.find(list, hider)).toBeNil()
		expect(SpectateTargets.Watchable(hider)).toBe(false)
		expect(SpectateTargets.Watchable(seeker)).toBe(true)
		-- Found: now a seeker, so they can be watched.
		hider:SetAttribute("HideSeekRole", "Seeker")
		expect(SpectateTargets.Watchable(hider)).toBe(true)
		hider:SetAttribute("HideSeekRole", "Hider")
		RS:SetAttribute("Mode", "KingHunt") -- other modes: everyone in the round
		expect(SpectateTargets.Watchable(hider)).toBe(true)
		RS:SetAttribute("Mode", nil)
		expect(me:GetAttribute("InRound")).toBeNil()
	end)

	it("switches chat bubbles off while a round is on, and back on afterwards", function()
		local chat = client.game:GetService("TextChatService")
		local bubbles = client:create("BubbleChatConfiguration", {}, chat)
		bubbles.Enabled = true
		local gui = client:create("ScreenGui", { Name = "GameUI" }, me:FindFirstChild("PlayerGui"))
		local UI = client:require("StarterPlayer.StarterPlayerScripts.Client.HideSeekUI")
		UI.Mount(gui)
		client:advance(0.1)
		expect(bubbles.Enabled).toBe(true)
		RS:SetAttribute("Mode", "HideSeek")
		RS:SetAttribute("State", "Hiding")
		client:advance(0.1)
		expect(bubbles.Enabled).toBe(false)
		RS:SetAttribute("State", "Playing")
		client:advance(0.1)
		expect(bubbles.Enabled).toBe(false)
		RS:SetAttribute("State", "Results")
		client:advance(0.1)
		expect(bubbles.Enabled).toBe(true)
		RS:SetAttribute("Mode", nil)
	end)
end)

describe("Hide & Seek through the real round loop", function()
	local server = Runtime.new({ studio = true })
	local RS = server.game:GetService("ReplicatedStorage")

	it("refuses 'Start round now' while the hiders hide", function()
		local ok, err = server:runScript("ServerScriptService.Server.Main")
		if not ok then
			error(err, 0)
		end
		server:advance(1)
		local players = { server:addPlayer({ Name = "One" }), server:addPlayer({ Name = "Two" }) }
		server:advance(2)
		local admin = server:find("ReplicatedStorage.Remotes.AdminCommand")
		local forced, message = server:invokeServer(admin, players[1], "ForceHideSeek")
		expect(forced).toBe(true)
		expect(message).toMatch("Hide")
		local pad = server.game:GetService("CollectionService"):GetTagged("ReadyPad")[1]
		for i, player in players do
			player.Character:PivotTo(
				pad.CFrame + server.env.Vector3.new(i * 2 - 3, pad.Size.Y / 2 + 3, 0)
			)
		end
		local waited = 0
		while RS:GetAttribute("State") ~= "Hiding" and waited < 120 do
			server:advance(1)
			waited += 1
		end
		expect(RS:GetAttribute("State")).toBe("Hiding")
		server:advance(0.5)
		local _, answer = server:invokeServer(admin, players[1], "StartRoundNow")
		expect(answer).toMatch("already")
		-- The round used the forced pick up; pressing again moves on to the other map.
		server:advance(2) -- past the admin panel's cooldown
		local _, again = server:invokeServer(admin, players[1], "ForceHideSeek")
		expect(again).toMatch("Hide")
		expect(again == message).toBe(false)
	end)
end)

describe("A Hide & Seek round on the Midnight Market", function()
	it("hides, lets the seeker out and ends when every pumpkin is tagged", function()
		local round = newRound(4, nil, "MidnightMarket")
		local rt, RS = round.rt, round.RS
		local cfg = round.Config.HideSeek
		local seekers = round.withRole("Seeker")
		local hiders = round.withRole("Hider")
		expect(#seekers).toBe(1)
		expect(#hiders).toBe(3)
		for _, hider in hiders do
			expect(round.pumpkinOf(hider)).toBeTruthy()
		end
		rt:advance(cfg.HeadStart + 0.5)
		local seeker = seekers[1]
		local Vector3, CFrame = rt.env.Vector3, rt.env.CFrame
		for _, hider in hiders do
			rt:advance(cfg.Gun.FireCooldown + 0.1)
			local target = round.pumpkinOf(hider).PrimaryPart.Position
			-- (close and from above: the market is full of crates and stalls)
			seeker.Character:PivotTo(CFrame.new(target + Vector3.new(0, 5, 3), target))
			local gun = seeker.Backpack:FindFirstChildOfClass("Tool")
				or seeker.Character:FindFirstChildOfClass("Tool")
			if gun then
				gun.Parent = seeker.Character
			end
			rt:fireServer(round.shoot, seeker, target)
		end
		expect(RS:GetAttribute("HidersLeft")).toBe(0)
		rt:advance(2)
		expect(round.state.Done).toBe(true)
		expect(round.state.Result.Winner).toBe(cfg.Text.SeekersWin)
		expect(#rt.errors).toBe(0)
	end)
end)
