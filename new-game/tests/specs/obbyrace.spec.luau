-- Spooky Obby (mode ObbyRace, map SpookyObby): the settings, the pure rules (pads, sweepers,
-- places, rewards), the course (every jump doable on Easy AND Hard with the parkour jump maths),
-- the built map (Floor, spawns, checkpoints in Index order, finish, variants, deterministic,
-- phone budget), whole rounds on the real map (three racers: one wins, one stops at a
-- checkpoint, one leaves; a solo Hard round), the server's checks (checkpoints only in order,
-- falls, goo, sweepers, anti-teleport, minimum time, Back button, respawns) and the screen.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local MODE_PATH = "ServerScriptService.Server.Modes.ObbyRace"

local function mapDef(Config: any): any
	for _, def in Config.Maps.List do
		if def.Id == "SpookyObby" then
			return def
		end
	end
	error("Config.Maps.List has no SpookyObby map")
end

local function taggedIn(rt: any, root: any, tag: string): { any }
	local list = {}
	for _, d in rt.game:GetService("CollectionService"):GetTagged(tag) do
		if d:IsDescendantOf(root) then
			table.insert(list, d)
		end
	end
	return list
end

describe("Spooky Obby settings and rules", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Rules = rt:require("ReplicatedStorage.Shared.ObbyRaceRules")
	local V3, CF = rt.env.Vector3, rt.env.CFrame

	it("has every setting the mode and screen read", function()
		local cfg = Config.ObbyRace
		for _, key in
			{
				"IntroSeconds",
				"EndAfterFirstSeconds",
				"MinSeconds",
				"SampleSeconds",
				"FallBelowCheckpoint",
				"BackCooldown",
				"TouchMargin",
				"TouchHeight",
				"HazardHeight",
				"SweeperBodyRadius",
				"SpeedTolerance",
				"SpeedSlack",
				"MaxRiseSpeed",
				"RiseSlack",
				"SpeedWindowSeconds",
			}
		do
			expect(cfg[key]).toBeA("number")
		end
		for _, id in Config.Difficulty.Order do
			local d = cfg.Difficulty[id]
			expect(d).toBeA("table")
			expect(d.TimeLimit).toBeGreaterThan(cfg.MinSeconds)
			expect(d.SweeperSpeed).toBeGreaterThan(0)
			expect(d.CoinMultiplier).toBeGreaterThan(0)
		end
		-- Easy is easier: more time, slower sweepers.
		expect(cfg.Difficulty.Easy.TimeLimit).toBeGreaterThan(cfg.Difficulty.Hard.TimeLimit)
		expect(cfg.Difficulty.Easy.SweeperSpeed).toBeLessThan(cfg.Difficulty.Hard.SweeperSpeed)
		for key, value in cfg.Text do
			expect(value).toBeA("string")
			local _ = key
		end
		expect(Config.Modes.List.ObbyRace.MinPlayers).toBe(1)
		expect(Config.Modes.List.ObbyRace.Feature).toBe("ObbyRace")
	end)

	it("touches pads, round and square, only from on top", function()
		local top = CF.new(0, 10, 0)
		local size = V3.new(12, 1.4, 12)
		expect(Rules.OnPad(V3.new(0, 13, 0), top, size, true, 1, 7)).toBe(true)
		expect(Rules.OnPad(V3.new(6.5, 13, 0), top, size, true, 1, 7)).toBe(true) -- within margin
		expect(Rules.OnPad(V3.new(5.5, 13, 5.5), top, size, true, 1, 7)).toBe(false) -- off the round
		expect(Rules.OnPad(V3.new(5.5, 13, 5.5), top, size, false, 1, 7)).toBe(true) -- on the square
		expect(Rules.OnPad(V3.new(0, 18, 0), top, size, true, 1, 7)).toBe(false) -- too high
		expect(Rules.OnPad(V3.new(0, 8, 0), top, size, true, 1, 7)).toBe(false) -- underneath
	end)

	it("turns sweepers the same on every screen and hits only what's in the way", function()
		expect(Rules.SweeperAngle(0, 36, 0)).toBe(0)
		expect(Rules.SweeperAngle(0, 36, 5)).toBeNear(180)
		expect(Rules.SweeperAngle(90, -60, 2)).toBeNear(330)
		expect(Rules.SweeperAngle(30, 60, -4)).toBe(30) -- before GO!: still
		local center = V3.new(0, 11.4, 0) -- 1.4 above a platform top at 10
		local size = V3.new(21, 1.2, 1)
		local bar = Rules.SweeperCFrame(center, 0) -- along X
		expect(Rules.SweeperHit(V3.new(6, 13, 0), bar, size, 0.5)).toBe(true) -- standing in it
		expect(Rules.SweeperHit(V3.new(6, 13, 3), bar, size, 0.5)).toBe(false) -- beside it
		expect(Rules.SweeperHit(V3.new(6, 15.5, 0), bar, size, 0.5)).toBe(false) -- jumped over
		expect(Rules.SweeperHit(V3.new(12, 13, 0), bar, size, 0.5)).toBe(false) -- past its end
		local turned = Rules.SweeperCFrame(center, 90) -- along Z now
		expect(Rules.SweeperHit(V3.new(0, 13, 6), turned, size, 0.5)).toBe(true)
		expect(Rules.SweeperHit(V3.new(6, 13, 0), turned, size, 0.5)).toBe(false)
	end)

	it("names places, sorts standings and pays rewards", function()
		expect(Rules.Ordinal(1)).toBe("1st")
		expect(Rules.Ordinal(2)).toBe("2nd")
		expect(Rules.Ordinal(3)).toBe("3rd")
		expect(Rules.Ordinal(4)).toBe("4th")
		expect(Rules.Ordinal(11)).toBe("11th")
		expect(Rules.Ordinal(12)).toBe("12th")
		expect(Rules.Ordinal(22)).toBe("22nd")
		local a = { Finished = true, Place = 2, Checkpoints = 5, ReachedAt = 9 }
		local b = { Finished = true, Place = 1, Checkpoints = 5, ReachedAt = 10 }
		local c = { Finished = false, Place = 0, Checkpoints = 4, ReachedAt = 5 }
		local d = { Finished = false, Place = 0, Checkpoints = 4, ReachedAt = 3 }
		local list = { c, a, d, b }
		table.sort(list, Rules.Sort)
		expect(list[1]).toBe(b)
		expect(list[2]).toBe(a)
		expect(list[3]).toBe(d)
		expect(list[4]).toBe(c)
		local rewards = Config.ObbyRace.Rewards
		local p1, c1 = Rules.Reward({ Finished = true, Place = 1, Checkpoints = 5 }, rewards, 1)
		expect(p1).toBe(rewards.PlacePoints[1])
		expect(c1).toBe(rewards.PlayCoins + rewards.FinishCoins + rewards.PlaceCoins[1])
		local p9, c9 = Rules.Reward({ Finished = true, Place = 9, Checkpoints = 5 }, rewards, 1)
		expect(p9).toBe(rewards.LastPoints)
		expect(c9).toBe(rewards.PlayCoins + rewards.FinishCoins)
		local p0, c0 = Rules.Reward({ Finished = false, Place = 0, Checkpoints = 2 }, rewards, 1.5)
		expect(p0).toBe(rewards.CheckpointPoints * 2)
		expect(c0).toBe(math.floor((rewards.PlayCoins + 2 * rewards.CheckpointCoins) * 1.5 + 0.5))
		-- Any finisher beats anyone who didn't finish, also with every checkpoint.
		for _, points in rewards.PlacePoints do
			expect(points).toBeGreaterThanOrEqual(rewards.LastPoints)
		end
		expect(rewards.LastPoints).toBeGreaterThan(rewards.CheckpointPoints * 6)
	end)
end)

describe("Spooky Obby course", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Rules = rt:require("ReplicatedStorage.Shared.ObbyRaceRules")
	local ParkourLogic = rt:require("ReplicatedStorage.Shared.ParkourLogic")
	local def = mapDef(Config)

	for _, difficulty in { "Easy", "Hard" } do
		it(("has every jump doable on %s (ParkourLogic.Check)"):format(difficulty), function()
			local course = Rules.Course(def.Course, difficulty)
			local problems = ParkourLogic.Check(course :: any)
			if #problems > 0 then
				error(table.concat(problems, "\n"))
			end
			local checkpoints, hardest = 0, 0
			local jumps = {}
			for i, step in course do
				if step.Kind == "Checkpoint" then
					checkpoints += 1
				end
				if step.Kind ~= "Hazard" then
					table.insert(jumps, i)
				end
			end
			for k = 2, #jumps do
				local a, b = jumps[k - 1], jumps[k]
				local gap = ParkourLogic.Jump(
					course[a],
					ParkourLogic.StepCFrame(course, a),
					course[b],
					ParkourLogic.StepCFrame(course, b)
				)
				hardest = math.max(hardest, gap)
			end
			expect(checkpoints).toBeGreaterThanOrEqual(4)
			expect(checkpoints).toBeLessThanOrEqual(6)
			-- Easy stays really easy.
			if difficulty == "Easy" then
				expect(hardest).toBeLessThanOrEqual(4)
			end
			T.note(
				("%d pieces, %d checkpoints, longest gap %.1f studs"):format(
					#course,
					checkpoints,
					hardest
				)
			)
		end)
	end

	it("gives Easy more checkpoints and Hard more to dodge", function()
		local function count(difficulty: string, kind: string): number
			local n = 0
			for _, step in Rules.Course(def.Course, difficulty) do
				if step.Kind == kind then
					n += 1
				end
			end
			return n
		end
		expect(count("Easy", "Checkpoint")).toBeGreaterThan(count("Hard", "Checkpoint"))
		expect(count("Hard", "Hazard")).toBeGreaterThan(count("Easy", "Hazard"))
		for _, step in def.Course do
			if step.Only ~= nil then
				expect(step.Only == "Easy" or step.Only == "Hard").toBe(true)
			end
		end
	end)
end)

describe("Spooky Obby map", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Tags = rt:require("ReplicatedStorage.Shared.Tags")
	local Builder = rt:require("ServerScriptService.Server.Maps.SpookyObby")
	local def = mapDef(Config)
	local model

	it("builds the Floor, the spawns and the tagged parts", function()
		model = Builder.Build(def)
		model.Parent = rt.workspace -- (tags are found in the game tree)
		local floor = model:FindFirstChild("Floor")
		expect(floor).toBeInstanceOf("Part")
		local spawns = model:FindFirstChild(def.SpawnFolder)
		expect(#spawns:GetChildren()).toBe(def.Spawns)
		local top = floor.Position.Y + floor.Size.Y / 2
		for _, spawn in spawns:GetChildren() do
			local p = spawn.Position
			expect(math.abs(p.X - floor.Position.X)).toBeLessThan(floor.Size.X / 2)
			expect(math.abs(p.Z - floor.Position.Z)).toBeLessThan(floor.Size.Z / 2)
			expect(p.Y).toBeGreaterThanOrEqual(top - 0.01)
		end
		local checkpoints = taggedIn(rt, model, Tags.ObbyCheckpoint)
		local expected = 0
		for _, step in def.Course do
			if step.Kind == "Checkpoint" then
				expected += 1
			end
		end
		expect(#checkpoints).toBe(expected)
		expect(#taggedIn(rt, model, Tags.ObbyFinish)).toBe(1)
		expect(#taggedIn(rt, model, Tags.ObbyHazard)).toBeGreaterThan(0)
		expect(#taggedIn(rt, model, Tags.ObbySweeper)).toBeGreaterThanOrEqual(2)
		-- Every sweeper bar is walk-through and knows how to turn.
		for _, bar in taggedIn(rt, model, Tags.ObbySweeper) do
			expect(bar.CanCollide).toBe(false)
			expect(bar:GetAttribute("Center")).toBeA("Vector3")
			expect(bar:GetAttribute("BaseSpeed")).toBeA("number")
		end
		-- Variants say which difficulty they are for.
		local variants = taggedIn(rt, model, Tags.ObbyVariant)
		expect(#variants).toBeGreaterThan(0)
		for _, v in variants do
			local only = v:GetAttribute("Only")
			expect(only == "Easy" or only == "Hard").toBe(true)
		end
	end)

	it("numbers the checkpoints 1, 2, 3... along the course, ending at the finish", function()
		local checkpoints = taggedIn(rt, model, Tags.ObbyCheckpoint)
		table.sort(checkpoints, function(a, b)
			return a:GetAttribute("Index") < b:GetAttribute("Index")
		end)
		local origin = model:FindFirstChild("Floor").Position
		local last = 0
		for i, pad in checkpoints do
			expect(pad:GetAttribute("Index")).toBe(i)
			expect(pad:GetAttribute("Facing")).toBeA("Vector3")
			local along = pad.Position.Z - origin.Z
			expect(along).toBeGreaterThan(last) -- further along every time
			last = along
		end
		local finish = taggedIn(rt, model, Tags.ObbyFinish)[1]
		expect(finish.Position.Z - origin.Z).toBeGreaterThan(last)
		-- The course runs away from the lobby (the lobby is round the world origin).
		expect(finish.Position.Z).toBeGreaterThan(origin.Z)
	end)

	it("is the same every time and fits the phone budget", function()
		local again = Builder.Build(def)
		local a, b = rt:parts(model), rt:parts(again)
		expect(#b).toBe(#a)
		for i = 1, #a, 37 do
			expect(b[i].Position).toBeNear(a[i].Position, 1e-6)
		end
		local lights = 0
		for _, d in model:GetDescendants() do
			if d:IsA("Light") and d.Enabled then
				lights += 1
			end
		end
		expect(#a).toBeLessThan(3000)
		expect(lights).toBeLessThanOrEqual(20)
		T.note(("%d parts, %d lights"):format(#a, lights))
		again:Destroy()
	end)

	it("keeps the space over the plaza clear for the round's floor checks", function()
		local MapService = rt:require("ServerScriptService.Server.Services.MapService")
		local map = MapService.Load("SpookyObby")
		for _ = 1, 10 do
			expect(MapService.RandomFloorPoint(map, 6, 40, 3)).toBeA("Vector3")
		end
		MapService.Unload()
		model:Destroy()
	end)
end)

-- A server with the real map loaded and helpers to run a round and move racers.
local function newRace(difficulty: string): any
	local server = Runtime.new()
	local s: any = {
		rt = server,
		Config = server:require("ReplicatedStorage.Shared.Config"),
		Rules = server:require("ReplicatedStorage.Shared.ObbyRaceRules"),
		Tags = server:require("ReplicatedStorage.Shared.Tags"),
		RS = server.game:GetService("ReplicatedStorage"),
		V3 = server.env.Vector3,
		CF = server.env.CFrame,
		MapService = server:require("ServerScriptService.Server.Services.MapService"),
		Mode = server:require(MODE_PATH),
	}
	s.cfg = s.Config.ObbyRace
	s.ATTR = s.Rules.Attributes
	function s.start(players: { any })
		s.map = s.MapService.Load("SpookyObby")
		s.RS:SetAttribute("Mode", "ObbyRace")
		for _, p in players do
			p:SetAttribute("InRound", true)
		end
		server.env.task.spawn(function()
			s.result = s.Mode.Run({
				Map = s.map,
				Players = players,
				Difficulty = difficulty,
				Playlist = s.Config.Modes.Playlists[1],
				SetState = function(state: string, timeLeft: number)
					s.RS:SetAttribute("State", state)
					s.RS:SetAttribute("TimeLeft", timeLeft)
				end,
				Countdown = function(state: string, seconds: number, stopIf: (() -> boolean)?)
					for remaining = seconds, 1, -1 do
						if stopIf and stopIf() then
							return
						end
						s.RS:SetAttribute("State", state)
						s.RS:SetAttribute("TimeLeft", remaining)
						server.env.task.wait(1)
					end
				end,
				Teleport = function(player: any, spawn: any)
					player.Character:PivotTo(s.CF.new(spawn.Position + s.V3.new(0, 4, 0)))
				end,
				AliveHumanoid = function(player: any): any
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					return if humanoid and humanoid.Health > 0 then humanoid else nil
				end,
			})
		end)
		server:flush()
	end
	function s.at(player: any): any
		return player.Character.HumanoidRootPart.Position
	end
	-- The checkpoints still on the map, in order, then the finish.
	function s.pads(): ({ any }, any)
		local list = taggedIn(server, s.map.Model, s.Tags.ObbyCheckpoint)
		table.sort(list, function(a, b)
			return a:GetAttribute("Index") < b:GetAttribute("Index")
		end)
		return list, taggedIn(server, s.map.Model, s.Tags.ObbyFinish)[1]
	end
	function s.topOf(part: any): any
		return s.V3.new(part.Position.X, part.Position.Y + part.Size.X / 2, part.Position.Z)
	end
	--[[
		Walks `player` at `speed` studs/s in a straight line to 6 studs above `target` (a pad's
		top), the way a racer would get there (high enough to clear sweepers and goo on the
		way). Returns false if the server sent them back on the way.
	]]
	function s.walk(player: any, target: any, speed: number?, height: number?): boolean
		local v = speed or 14
		local goal = target + s.V3.new(0, height or 6, 0)
		local start = s.at(player)
		-- Up, across at a height clear of everything (a jump, in a real game), then down.
		local cruise = math.max(start.Y, goal.Y) + 3
		local legs = {
			s.V3.new(start.X, cruise, start.Z),
			s.V3.new(goal.X, cruise, goal.Z),
			goal,
		}
		for _, point in legs do
			for _ = 1, 400 do
				local here = s.at(player)
				local d = point - here
				if d.Magnitude < 0.05 then
					break
				end
				local step = d.Unit * math.min(v * 0.1, d.Magnitude)
				player.Character:PivotTo(s.CF.new(here + step))
				server:advance(0.1)
				if (s.at(player) - (here + step)).Magnitude > 3 then
					return false -- moved by the server
				end
			end
		end
		return true
	end
	function s.backs(player: any): number
		return player:GetAttribute(s.ATTR.Back) or 0
	end
	return s
end

describe("A Spooky Obby round (Easy, three racers)", function()
	local s = newRace("Easy")
	local server = s.rt
	local winner, slowpoke, leaver
	local checkpoints, finish

	it("starts everyone frozen on the plaza with the course for Easy", function()
		winner = server:addPlayer({ Name = "Winner" })
		slowpoke = server:addPlayer({ Name = "Slowpoke" })
		leaver = server:addPlayer({ Name = "Leaver" })
		s.start({ winner, slowpoke, leaver })
		expect(s.RS:GetAttribute("State")).toBe("Get ready")
		local floor = s.map.Floor
		local floorTop = floor.Position.Y + floor.Size.Y / 2
		for _, p in { winner, slowpoke, leaver } do
			local at = s.at(p)
			expect(math.abs(at.X - floor.Position.X)).toBeLessThan(floor.Size.X / 2)
			expect(at.Y).toBeGreaterThan(floorTop)
			expect(p.Character.Humanoid.WalkSpeed).toBe(0)
			expect(p:GetAttribute(s.ATTR.Checkpoint)).toBe(0)
		end
		checkpoints, finish = s.pads()
		expect(#checkpoints).toBe(5) -- Easy keeps its extra checkpoint
		expect(winner:GetAttribute(s.ATTR.Total)).toBe(5)
		for _, d in s.map.Model:GetDescendants() do
			if d:GetAttribute("Only") == "Hard" then
				error("a Hard-only piece is still there: " .. d:GetFullName())
			end
		end
		for _, bar in taggedIn(server, s.map.Model, s.Tags.ObbySweeper) do
			expect(bar:GetAttribute("Speed")).toBeNear(
				bar:GetAttribute("BaseSpeed") * s.cfg.Difficulty.Easy.SweeperSpeed
			)
		end
	end)

	it("says GO! and lets them walk", function()
		server:advance(s.cfg.IntroSeconds + 0.2)
		expect(s.RS:GetAttribute("State")).toBe("Playing")
		expect(s.RS:GetAttribute("ObbyStartedAt")).toBeA("number")
		expect(winner.Character.Humanoid.WalkSpeed).toBeGreaterThan(0)
	end)

	it("counts checkpoints only in order", function()
		-- Slowpoke runs past checkpoint 1 straight to checkpoint 2: it doesn't count.
		s.walk(
			slowpoke,
			s.V3.new(
				checkpoints[1].Position.X + 30,
				s.topOf(checkpoints[1]).Y,
				checkpoints[1].Position.Z
			)
		)
		s.walk(slowpoke, s.topOf(checkpoints[2]))
		expect(slowpoke:GetAttribute(s.ATTR.Checkpoint)).toBe(0)
		-- Back to checkpoint 1, then 2: both count.
		expect(s.walk(slowpoke, s.topOf(checkpoints[1]))).toBe(true)
		expect(slowpoke:GetAttribute(s.ATTR.Checkpoint)).toBe(1)
		expect(s.walk(slowpoke, s.topOf(checkpoints[2]))).toBe(true)
		expect(slowpoke:GetAttribute(s.ATTR.Checkpoint)).toBe(2)
	end)

	it("sends a racer who falls back to their last checkpoint", function()
		local before = s.backs(slowpoke)
		local here = s.at(slowpoke)
		slowpoke.Character:PivotTo(s.CF.new(here + s.V3.new(3, -20, 0))) -- falling is never too fast
		server:advance(0.3)
		expect(s.backs(slowpoke)).toBe(before + 1)
		expect(slowpoke:GetAttribute(s.ATTR.BackReason)).toBe("Fell")
		local pad = s.topOf(checkpoints[2])
		expect((s.at(slowpoke) - pad).Magnitude).toBeLessThan(7)
		expect(slowpoke:GetAttribute(s.ATTR.Checkpoint)).toBe(2)
	end)

	it("puts a racer who teleports back, without the checkpoint", function()
		local before = s.backs(slowpoke)
		slowpoke.Character:PivotTo(s.CF.new(s.topOf(checkpoints[4]) + s.V3.new(0, 3, 0)))
		server:advance(0.3)
		expect(s.backs(slowpoke)).toBe(before + 1)
		expect(slowpoke:GetAttribute(s.ATTR.BackReason)).toBe("TooFast")
		expect(slowpoke:GetAttribute(s.ATTR.Checkpoint)).toBe(2)
		expect((s.at(slowpoke) - s.topOf(checkpoints[2])).Magnitude).toBeLessThan(7)
	end)

	it("sends back whoever stands in goo or in a sweeper's way", function()
		-- Goo on the second sweeper platform: walk onto it at standing height.
		local goo
		for _, part in taggedIn(server, s.map.Model, s.Tags.ObbyHazard) do
			if not goo or part.Position.Z < goo.Position.Z then
				goo = part
			end
		end
		local gooTop = s.V3.new(goo.Position.X, goo.Position.Y + goo.Size.Y / 2, goo.Position.Z)
		s.walk(slowpoke, s.topOf(checkpoints[3]))
		expect(slowpoke:GetAttribute(s.ATTR.Checkpoint)).toBe(3)
		local before = s.backs(slowpoke)
		s.walk(slowpoke, gooTop) -- (over the sweeper bars)
		s.walk(slowpoke, gooTop, nil, 2.75) -- (standing in it)
		server:advance(0.2)
		expect(s.backs(slowpoke)).toBe(before + 1)
		expect(slowpoke:GetAttribute(s.ATTR.BackReason)).toBe("Goo")
		-- A sweeper: stand still where the bar goes round, and it comes.
		local bar = taggedIn(server, s.map.Model, s.Tags.ObbySweeper)[1]
		local center = bar:GetAttribute("Center")
		local platformTop = center.Y - 1.4
		local spot = s.V3.new(center.X + 6, platformTop, center.Z)
		before = s.backs(slowpoke)
		local reason = nil
		s.walk(slowpoke, spot, nil, 3)
		for _ = 1, 120 do
			if s.backs(slowpoke) > before then
				reason = slowpoke:GetAttribute(s.ATTR.BackReason)
				break
			end
			server:advance(0.1)
		end
		expect(reason).toBe("Swept")
	end)

	it("lets the Back button send you back, not too often", function()
		local remote = server:find("ReplicatedStorage.Remotes.ObbyRaceBack")
		local before = s.backs(slowpoke)
		server:fireServer(remote, slowpoke)
		expect(s.backs(slowpoke)).toBe(before + 1)
		expect(slowpoke:GetAttribute(s.ATTR.BackReason)).toBe("Button")
		server:fireServer(remote, slowpoke) -- cooldown
		expect(s.backs(slowpoke)).toBe(before + 1)
		server:advance(s.cfg.BackCooldown + 0.1)
		server:fireServer(remote, slowpoke, "junk", 42) -- arguments are ignored
		expect(s.backs(slowpoke)).toBe(before + 2)
	end)

	it("brings a racer who resets back to their checkpoint", function()
		slowpoke.Character.Humanoid.Health = 0
		server:advance(0.5)
		server:spawnCharacter(slowpoke)
		server:advance(0.5)
		expect((s.at(slowpoke) - s.topOf(checkpoints[3])).Magnitude).toBeLessThan(7)
		expect(slowpoke:GetAttribute(s.ATTR.Checkpoint)).toBe(3)
	end)

	it("doesn't count a finish that is too fast, then lets the winner finish", function()
		-- Leaver leaves mid-race.
		s.walk(leaver, s.topOf(checkpoints[1]))
		expect(leaver:GetAttribute(s.ATTR.Checkpoint)).toBe(1)
		server:removePlayer(leaver)
		local minimum = s.cfg.MinSeconds
		s.cfg.MinSeconds = 100000
		for _, pad in checkpoints do
			expect(s.walk(winner, s.topOf(pad))).toBe(true)
		end
		expect(winner:GetAttribute(s.ATTR.Checkpoint)).toBe(5)
		expect(winner:GetAttribute(s.ATTR.Rank)).toBe(1)
		local before = s.backs(winner)
		s.walk(winner, s.topOf(finish))
		server:advance(0.2)
		expect(winner:GetAttribute(s.ATTR.Place)).toBeNil()
		expect(s.backs(winner)).toBe(before + 1)
		expect(winner:GetAttribute(s.ATTR.BackReason)).toBe("TooFast")
		s.cfg.MinSeconds = minimum
		expect(s.walk(winner, s.topOf(finish))).toBe(true)
		server:advance(0.2)
		expect(winner:GetAttribute(s.ATTR.Place)).toBe(1)
		expect(winner:GetAttribute(s.ATTR.Time)).toBeGreaterThan(minimum)
		expect(s.RS:GetAttribute("ObbyFinished")).toBe(1)
		expect(s.RS:GetAttribute("ObbyLeader")).toBe(winner.DisplayName)
	end)

	it("ends EndAfterFirstSeconds after the first finisher and scores everyone", function()
		local waited = 0
		while s.result == nil and waited < s.cfg.EndAfterFirstSeconds + 5 do
			server:advance(1)
			waited += 1
		end
		expect(s.result).toBeTruthy()
		expect(waited).toBeGreaterThan(s.cfg.EndAfterFirstSeconds - 3)
		local result = s.result
		expect(result.ScoreLabel).toBe(s.cfg.Text.ScoreLabel)
		expect(#result.Rows).toBe(2) -- the leaver isn't listed
		local r = s.cfg.Rewards
		local w, sp = result.Rows[1], result.Rows[2]
		expect(w.Name).toBe(winner.DisplayName)
		expect(w.Top).toBe(true)
		expect(w.Survived).toBe(true)
		expect(w.Badge).toBe("1st")
		expect(w.Score).toBe(r.PlacePoints[1])
		expect(w.Coins).toBe(r.PlayCoins + r.FinishCoins + r.PlaceCoins[1])
		expect(w.Stat).toBeA("string")
		expect(sp.Name).toBe(slowpoke.DisplayName)
		expect(sp.Top).toBe(false)
		expect(sp.Badge).toBe(s.cfg.Text.BadgeCheckpoint:format(3))
		expect(sp.Score).toBe(r.CheckpointPoints * 3)
		expect(sp.Coins).toBe(r.PlayCoins + 3 * r.CheckpointCoins)
		expect(result.Winner).toBe(s.cfg.Text.WinnerOne:format(winner.DisplayName))
		-- Everything the round set is cleared.
		for _, p in { winner, slowpoke } do
			for _, name in s.ATTR do
				expect(p:GetAttribute(name)).toBeNil()
			end
		end
		expect(s.RS:GetAttribute("ObbyStartedAt")).toBeNil()
		expect(s.RS:GetAttribute("ObbyFinished")).toBeNil()
		s.Mode.Cleanup() -- safe again
		s.MapService.Unload()
		if #server.errors > 0 then
			error(tostring(server.errors[1]))
		end
	end)
end)

describe("A solo Spooky Obby round (Hard)", function()
	local s = newRace("Hard")
	local server = s.rt
	local solo

	it("plays Hard's course and ends as soon as the only racer finishes", function()
		solo = server:addPlayer({ Name = "Solo" })
		s.start({ solo })
		local checkpoints, finish = s.pads()
		expect(#checkpoints).toBe(4) -- no Easy-only checkpoint
		expect(solo:GetAttribute(s.ATTR.Total)).toBe(4)
		local crossBars = 0
		for _, bar in taggedIn(server, s.map.Model, s.Tags.ObbySweeper) do
			if bar.Name == "CrossBar" then
				crossBars += 1
			end
		end
		expect(crossBars).toBeGreaterThan(0)
		for _, d in s.map.Model:GetDescendants() do
			if d:GetAttribute("Only") == "Easy" then
				error("an Easy-only piece is still there: " .. d:GetFullName())
			end
		end
		server:advance(s.cfg.IntroSeconds + 0.2)
		for _, pad in checkpoints do
			expect(s.walk(solo, s.topOf(pad))).toBe(true)
		end
		expect(s.walk(solo, s.topOf(finish))).toBe(true)
		server:advance(1)
		expect(s.result).toBeTruthy()
		local row = s.result.Rows[1]
		local r = s.cfg.Rewards
		expect(#s.result.Rows).toBe(1)
		expect(row.Top).toBe(true)
		expect(row.Coins).toBe(
			math.floor(
				(r.PlayCoins + r.FinishCoins + r.PlaceCoins[1])
						* s.cfg.Difficulty.Hard.CoinMultiplier
					+ 0.5
			)
		)
		s.MapService.Unload()
	end)

	it("ends with nobody when the only racer leaves, and when time runs out nobody wins", function()
		local quitter = server:addPlayer({ Name = "Quitter" })
		s.result = nil
		s.start({ quitter })
		server:advance(s.cfg.IntroSeconds + 0.2)
		server:removePlayer(quitter)
		server:advance(1)
		expect(s.result).toBeTruthy()
		expect(#s.result.Rows).toBe(0)
		expect(s.result.Winner).toBe(s.cfg.Text.WinnerNone)
		s.MapService.Unload()
		-- Time runs out with a racer who never leaves the plaza.
		local sitter = server:addPlayer({ Name = "Sitter" })
		s.result = nil
		s.start({ sitter })
		server:advance(s.cfg.IntroSeconds + s.cfg.Difficulty.Hard.TimeLimit + 1)
		expect(s.result).toBeTruthy()
		expect(s.result.Rows[1].Top).toBe(false)
		expect(s.result.Rows[1].Badge).toBe(s.cfg.Text.BadgeStart)
		expect(s.result.Rows[1].Coins).toBe(
			math.floor(s.cfg.Rewards.PlayCoins * s.cfg.Difficulty.Hard.CoinMultiplier + 0.5)
		)
		s.MapService.Unload()
		if #server.errors > 0 then
			error(tostring(server.errors[1]))
		end
	end)
end)

describe("Spooky Obby screen", function()
	local client = Runtime.new({ client = true })
	local Config = client:require("ReplicatedStorage.Shared.Config")
	local RS = client.game:GetService("ReplicatedStorage")
	local V3, CF = client.env.Vector3, client.env.CFrame
	local remotes = client:create("Folder", { Name = "Remotes" }, RS)
	local backRemote = client:create("RemoteEvent", { Name = "ObbyRaceBack" }, remotes)
	local me = client.localPlayer
	local gui = client:create("ScreenGui", { Name = "GameUI" }, me:FindFirstChild("PlayerGui"))
	local UI = client:require("StarterPlayer.StarterPlayerScripts.Client.ObbyRaceUI")
	local text = Config.ObbyRace.Text
	local root, back, message

	it("mounts hidden outside a Spooky Obby round", function()
		UI.Mount(gui)
		root = gui:FindFirstChild("ObbyRace")
		back = root:FindFirstChild("BackButton")
		message = root:FindFirstChild("Message")
		expect(root.Visible).toBe(false)
		RS:SetAttribute("Mode", "KingHunt")
		RS:SetAttribute("State", "Playing")
		client:advance(0.1)
		expect(root.Visible).toBe(false)
	end)

	it("shows Get ready with a 3-2-1, then GO!, the counter, time and place", function()
		RS:SetAttribute("Mode", "ObbyRace")
		RS:SetAttribute("State", "Intermission")
		me:SetAttribute("InRound", true)
		me:SetAttribute("ObbyTotal", 5)
		me:SetAttribute("ObbyCheckpoint", 0)
		me:SetAttribute("ObbyRank", 2)
		RS:SetAttribute("State", "Get ready")
		RS:SetAttribute("TimeLeft", 3)
		client:advance(0.1)
		expect(root.Visible).toBe(true)
		expect(back.Visible).toBe(false) -- not before GO!
		expect(message.Text).toBe(text.GetReady)
		expect(root.Countdown.Visible).toBe(true)
		expect(root.Countdown.Text).toBe("3")
		RS:SetAttribute("State", "Playing")
		RS:SetAttribute("TimeLeft", 83)
		client:advance(0.1)
		expect(message.Text).toBe(text.Go)
		expect(root.Countdown.Visible).toBe(false)
		expect(back.Visible).toBe(true)
		local pill = root.Info.Text.Text
		expect(pill).toMatch("Checkpoint 0/5")
		expect(pill).toMatch("1:23")
		expect(pill).toMatch("2nd place")
	end)

	it("celebrates a checkpoint and says why you were sent back", function()
		me:SetAttribute("ObbyCheckpoint", 1)
		client:advance(0.1)
		expect(message.Text).toBe(text.CheckpointReached:format(1, 5))
		expect(root.Info.Text.Text).toMatch("Checkpoint 1/5")
		me:SetAttribute("ObbyBackReason", "Goo")
		me:SetAttribute("ObbyBack", 1)
		client:advance(0.1)
		expect(message.Text).toBe(text.Goo:format(1))
	end)

	it("sends Back to checkpoint from the button and the key, respecting the cooldown", function()
		client:advance(0.5) -- (the remote is looked up in its own thread)
		local function sent(): number
			local n = 0
			for _, call in client:calls("RemoteEvent", "FireServer") do
				if call.instance == backRemote then
					n += 1
				end
			end
			return n
		end
		me:SetAttribute("ObbyBackReadyAt", 0)
		client:fire(back, "Activated")
		expect(sent()).toBe(1)
		client:triggerAction("ObbyRaceBack")
		expect(sent()).toBe(2)
		me:SetAttribute("ObbyBackReadyAt", client.workspace:GetServerTimeNow() + 5)
		client:fire(back, "Activated")
		expect(sent()).toBe(2)
	end)

	it("turns the ghost sweepers while racing", function()
		local map = client:create("Model", { Name = "Map" }, client.workspace)
		local center = V3.new(0, 10, 50)
		local bar = client:create("Part", {
			Name = "Bar",
			Size = V3.new(21, 1.2, 1),
			CFrame = CF.new(center),
			Anchored = true,
		}, map)
		bar:SetAttribute("Center", center)
		bar:SetAttribute("Speed", 90)
		bar:SetAttribute("Phase", 0)
		client.game:GetService("CollectionService"):AddTag(bar, "ObbySweeper")
		local camera = client.workspace.CurrentCamera
		camera.CFrame = CF.new(center + V3.new(0, 10, 20))
		RS:SetAttribute("ObbyStartedAt", client.workspace:GetServerTimeNow())
		client:advance(1)
		local look = bar.CFrame.RightVector
		expect(math.abs(look.X)).toBeLessThan(0.2) -- turned about 90 degrees
		expect(bar.Position).toBeNear(center, 1e-3)
	end)

	it("shows FINISHED! with the place, then hides when the round is over", function()
		me:SetAttribute("ObbyTime", 61.5)
		me:SetAttribute("ObbyPlace", 2)
		client:advance(0.1)
		expect(message.Text).toBe(text.Finished)
		expect(root.SubMessage.Text).toMatch("2nd place")
		expect(back.Visible).toBe(false)
		RS:SetAttribute("State", "Results")
		client:advance(0.1)
		expect(root.Visible).toBe(false)
		if #client.errors > 0 then
			error(tostring(client.errors[1]))
		end
	end)
end)
