-- ScareMaze: the pure rules (teams, the keep-moving rule with made-up positions and times,
-- scores), the map (a way from the entrance to the exit, traps along it, tags), and a whole
-- round on the real map with three players: one runs to the exit, one stands still, one is a
-- Haunter who BOOs.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Vector3, CFrame = rt.env.Vector3, rt.env.CFrame
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Rules = rt:require("ReplicatedStorage.Shared.ScareMazeRules")
local Tags = rt:require("ReplicatedStorage.Shared.Tags")
local MazeGen = rt:require("ServerScriptService.Server.Maps.MazeGen")
local Builder = rt:require("ServerScriptService.Server.Maps.ScareMaze")

local function mapDef(): any
	for _, def in Config.Maps.List do
		if def.Id == "ScareMaze" then
			return def
		end
	end
	error("Config.Maps.List has no ScareMaze map")
end

describe("ScareMaze settings", function()
	it("has every setting the mode, map and screen read", function()
		local cfg = Config.ScareMaze
		for _, key in
			{
				"Duration",
				"IntroSeconds",
				"MinPlayersForHaunters",
				"HaunterRatio",
				"StopSeconds",
				"MinMoveStuds",
				"SampleSeconds",
				"StartGraceSeconds",
				"ScareGraceSeconds",
				"CatchCreditRange",
				"CatchCreditSeconds",
			}
		do
			expect(cfg[key]).toBeA("number")
		end
		expect(cfg.OutBecomeHaunters).toBeA("boolean")
		expect(cfg.Boo.Cooldown).toBeGreaterThan(0)
		for _, kind in { "Scarecrow", "Zombie", "Bats", "Ghost", "Patrol" } do
			expect(cfg.Traps.Kinds[kind]).toBeA("table")
			expect(cfg.Traps.Kinds[kind].Sound.SoundId).toBeA("string")
		end
		for _, kind in { "Scarecrow", "Zombie", "Bats", "Ghost", "Boo" } do
			expect(cfg.Jumpscare.Faces[kind].Emoji).toBeA("string")
		end
		-- Standing next to a scare must never keep anyone safe for ever.
		local graceAndStop = cfg.Traps.SlowSeconds + cfg.ScareGraceSeconds + cfg.StopSeconds
		expect(cfg.Traps.PersonalCooldown).toBeGreaterThan(graceAndStop)
		expect(cfg.Traps.PersonalCooldown).toBeGreaterThan(
			cfg.Boo.SlowSeconds + cfg.ScareGraceSeconds + cfg.StopSeconds
		)
		expect(cfg.Text.SurvivorHint:format(cfg.StopSeconds)).toMatch("%d")
		expect(Config.Modes.List.ScareMaze.Feature).toBe("ScareMaze")
	end)
end)

describe("ScareMazeRules teams", function()
	it("has no Haunters with fewer than 3 players, then 20% (at least 1)", function()
		local cfg = Config.ScareMaze
		local count = function(n: number): number
			return Rules.HaunterCount(n, cfg.HaunterRatio, cfg.MinPlayersForHaunters)
		end
		expect(count(0)).toBe(0)
		expect(count(1)).toBe(0)
		expect(count(2)).toBe(0)
		expect(count(3)).toBe(1)
		expect(count(9)).toBe(1)
		expect(count(10)).toBe(2)
		expect(count(32)).toBe(6)
		-- Always at least one Survivor, whatever the ratio.
		expect(Rules.HaunterCount(3, 0.9, 3)).toBe(2)
		expect(Rules.HaunterCount(3, 0, 3)).toBe(1)
	end)

	it("splits a list into two teams that cover everyone once", function()
		local list = {}
		for i = 1, 12 do
			table.insert(list, i)
		end
		local survivors, haunters = Rules.PickTeams(list, 0.2, 3, rt.env.Random.new(4))
		expect(#haunters).toBe(2)
		expect(#survivors).toBe(10)
		local seen = {}
		for _, team in { survivors, haunters } do
			for _, n in team do
				if seen[n] then
					error(("%d is in both teams"):format(n))
				end
				seen[n] = true
			end
		end
		for i = 1, 12 do
			expect(seen[i]).toBe(true)
		end
		expect(#list).toBe(12) -- the list given isn't changed
		local s2, h2 = Rules.PickTeams({ "A", "B" }, 0.2, 3, rt.env.Random.new(1))
		expect(#s2).toBe(2)
		expect(#h2).toBe(0)
	end)
end)

describe("ScareMazeRules keep moving", function()
	local MIN, STOP = 4, 3

	-- Feeds samples 0.2 s apart; `at(t)` gives the position at time t. Returns the time the
	-- player would be out (stillFor >= STOP), or nil if never within `seconds`.
	local function outAt(at: (number) -> Vector3, seconds: number, grace: number?): number?
		local tracker = Rules.NewTracker(0)
		if grace then
			Rules.Grace(tracker, grace)
		end
		local t = 0
		while t <= seconds + 1e-6 do
			if Rules.Update(tracker, at(t), t, MIN) >= STOP then
				return t
			end
			t += 0.2
		end
		return nil
	end

	it("puts someone who stands still out after 3 seconds", function()
		local out = outAt(function()
			return Vector3.new(5, 3, 5)
		end, 10)
		expect(out).toBeNear(3, 0.21)
	end)

	it("never puts someone who keeps walking out", function()
		expect(outAt(function(t)
			return Vector3.new(t * 16, 3, 0)
		end, 30)).toBeNil()
		-- Back and forth along a corridor counts as moving too.
		expect(outAt(function(t)
			return Vector3.new(math.sin(t) * 8, 3, 0)
		end, 30)).toBeNil()
	end)

	it("doesn't count jumping on the spot or tiny wiggles as moving", function()
		local jump = outAt(function(t)
			return Vector3.new(0, 3 + math.abs(math.sin(t * 3)) * 7, 0)
		end, 10)
		expect(jump).toBeNear(3, 0.21)
		local wiggle = outAt(function(t)
			return Vector3.new(math.sin(t * 5) * 1.5, 3, 0)
		end, 10)
		expect(wiggle).toBeNear(3, 0.21)
	end)

	it("starts counting again after a grace, and when you stop after walking", function()
		local still = function()
			return Vector3.zero
		end
		expect(outAt(still, 10, 2)).toBeNear(5, 0.21) -- 2 s safe + 3 s
		-- Walk for 4 s, then stop: out 3 s after stopping.
		local out = outAt(function(t)
			return Vector3.new(math.min(t, 4) * 16, 3, 0)
		end, 20)
		expect(out).toBeNear(7, 0.45)
		-- A grace given later (a jumpscare) resets the clock.
		local tracker = Rules.NewTracker(0)
		expect(Rules.Update(tracker, Vector3.zero, 0, MIN)).toBe(0)
		expect(Rules.Update(tracker, Vector3.zero, 2, MIN)).toBeNear(2)
		Rules.Grace(tracker, 4)
		expect(Rules.Update(tracker, Vector3.zero, 3, MIN)).toBe(0)
		expect(Rules.Update(tracker, Vector3.zero, 5, MIN)).toBeNear(1)
		Rules.Grace(tracker, 1) -- a shorter grace doesn't shorten the one running
		expect(tracker.GraceUntil).toBe(4)
	end)

	it("drives the meter and the 3-2-1", function()
		expect(Rules.Meter(0, STOP)).toBe(1)
		expect(Rules.Meter(1.5, STOP)).toBeNear(0.5)
		expect(Rules.Meter(5, STOP)).toBe(0)
		expect(Rules.SecondsLeft(0.5, STOP)).toBe(3)
		expect(Rules.SecondsLeft(1.2, STOP)).toBe(2)
		expect(Rules.SecondsLeft(2.9, STOP)).toBe(1)
		expect(Rules.SecondsLeft(3, STOP)).toBe(0)
	end)

	it("checks boxes, teleports and scores", function()
		local box = CFrame.new(10, 5, 0) * CFrame.Angles(0, math.rad(90), 0)
		-- Turned 90 degrees: its long side (Z, 10) runs along the world X axis.
		expect(Rules.InBox(Vector3.new(14, 3, 0), box, Vector3.new(2, 10, 10), 0)).toBe(true)
		expect(Rules.InBox(Vector3.new(10, 3, 4), box, Vector3.new(2, 10, 10), 0)).toBe(false)
		expect(Rules.InBox(Vector3.new(10, 3, 1.5), box, Vector3.new(2, 10, 10), 1)).toBe(true)
		expect(Rules.TooFast(Vector3.zero, Vector3.new(4, 0, 0), 0.2, 40, 14)).toBe(false)
		expect(Rules.TooFast(Vector3.zero, Vector3.new(150, 0, 0), 0.2, 40, 14)).toBe(true)
		expect(Rules.TooFast(Vector3.zero, Vector3.new(0, 300, 0), 0.2, 40, 14)).toBe(false) -- falling
		local rewards = Config.ScareMaze.Rewards
		local score, coins = Rules.Score({ Escaped = true, TimeLeft = 100, Catches = 0 }, rewards)
		expect(score).toBe(rewards.EscapePoints + math.floor(100 * rewards.PointsPerSecondLeft))
		expect(coins).toBe(
			rewards.PlayCoins + rewards.EscapeCoins + math.floor(100 * rewards.CoinsPerSecondLeft)
		)
		score, coins = Rules.Score({ Escaped = false, TimeLeft = 0, Catches = 2 }, rewards)
		expect(score).toBe(2 * rewards.PointsPerCatch)
		expect(coins).toBe(rewards.PlayCoins + 2 * rewards.CoinsPerCatch)
	end)
end)

describe("ScareMaze map", function()
	local def = mapDef()
	local layout = def.Layout
	local plan = Builder.Plan(def)

	it("always has a way from the entrance to the exit", function()
		expect(plan.Entrance.Y).toBe(plan.Height) -- south row
		expect(plan.Exit.Y).toBe(1) -- north row
		local route = plan.Route
		expect(route[1].X).toBe(plan.Entrance.X)
		expect(route[#route].X).toBe(plan.Exit.X)
		for i = 2, #route do
			local a, b = route[i - 1], route[i]
			local dx, dy = b.X - a.X, b.Y - a.Y
			expect(math.abs(dx) + math.abs(dy)).toBe(1)
			local side = if dx == 1 then "E" elseif dx == -1 then "W" elseif dy == 1 then "S" else "N"
			if MazeGen.HasWall(plan.Maze, a.X, a.Y, side) then
				error(("a wall blocks the way between %d,%d and %d,%d"):format(a.X, a.Y, b.X, b.Y))
			end
		end
		T.note(
			("%d x %d cells, the way out is %d cells long"):format(plan.Width, plan.Height, #route)
		)
	end)

	it("puts the traps along the way out and in side paths", function()
		expect(#plan.Traps).toBe(layout.Traps)
		expect(#plan.Patrols).toBe(layout.Patrols)
		local onRoute = {}
		for _, cell in plan.Route do
			onRoute[cell.X .. "," .. cell.Y] = true
		end
		local routeTraps = 0
		for _, trap in plan.Traps do
			expect(table.find(layout.TrapKinds, trap.Kind)).toBeTruthy()
			if onRoute[trap.Cell.X .. "," .. trap.Cell.Y] then
				routeTraps += 1
			end
		end
		expect(routeTraps).toBeGreaterThanOrEqual(
			math.floor(layout.Traps * layout.RouteTrapShare) - 1
		)
		expect(routeTraps).toBeLessThan(#plan.Traps) -- some in side paths
		expect(#plan.HauntCells).toBe(layout.HauntSpawns)
		T.note(
			("%d traps on the way out, %d in side paths"):format(
				routeTraps,
				#plan.Traps - routeTraps
			)
		)
	end)

	it("builds the tagged parts the mode needs, under the part budget", function()
		local model = Builder.Build(def)
		local function taggedIn(tag: string): { any }
			local list = {}
			for _, d in model:GetDescendants() do
				if d:HasTag(tag) then
					table.insert(list, d)
				end
			end
			return list
		end
		local exits = taggedIn(Tags.MazeExit)
		expect(#exits).toBe(1)
		local triggers = taggedIn(Tags.ScareTrigger)
		expect(#triggers).toBe(layout.Traps + layout.Patrols)
		for _, trigger in triggers do
			local kind = trigger:GetAttribute("Kind")
			expect(Config.ScareMaze.Traps.Kinds[kind]).toBeA("table")
			expect(trigger.CanCollide).toBe(false)
			expect(trigger.CanQuery).toBe(false)
			if kind == "Scarecrow" or kind == "Patrol" then
				local actor = nil
				for _, child in trigger.Parent:GetChildren() do
					if child:GetAttribute("ScareActor") then
						actor = child
					end
				end
				expect(actor).toBeTruthy()
			end
		end
		expect(#taggedIn(Tags.SurvivorSpawn)).toBe(def.Spawns)
		expect(#taggedIn(Tags.HauntSpawn)).toBe(layout.HauntSpawns)
		-- Stepping out of the exit cell through the gap in the north wall lands in MazeExit.
		local Config2 = Config.Maps
		local exitCell = plan.Exit
		local x = plan.West + (exitCell.X - 0.5) * plan.CellSize
		local z = plan.North - plan.Thickness / 2 - 2
		local outside = Config2.Origin + Vector3.new(x, 3.5, z)
		local exit = exits[1]
		expect(Rules.InBox(outside, exit.CFrame, exit.Size, 0)).toBe(true)
		-- Every trap's trigger covers its cell's middle (where Survivors walk).
		for _, trap in plan.Traps do
			local middle = Config2.Origin
				+ Vector3.new(
					plan.West + (trap.Cell.X - 0.5) * plan.CellSize,
					3.5,
					plan.North + (trap.Cell.Y - 0.5) * plan.CellSize
				)
			local covered = false
			for _, trigger in triggers do
				if Rules.InBox(middle, trigger.CFrame, trigger.Size, 0) then
					covered = true
				end
			end
			expect(covered).toBe(true)
		end
		local parts = #rt:parts(model)
		expect(parts).toBeLessThan(1800)
		T.note(("%d parts"):format(parts))
		model:Destroy()
	end)
end)

describe("A ScareMaze round", function()
	local server = Runtime.new()
	local SConfig = server:require("ReplicatedStorage.Shared.Config")
	local SRules = server:require("ReplicatedStorage.Shared.ScareMazeRules")
	local RS = server.game:GetService("ReplicatedStorage")
	local SV3, SCF = server.env.Vector3, server.env.CFrame
	local cfg = SConfig.ScareMaze
	local DataService = server:require("ServerScriptService.Server.Services.DataService")
	local MapService = server:require("ServerScriptService.Server.Services.MapService")
	local Mode = server:require("ServerScriptService.Server.Modes.ScareMaze")
	local ATTR = SRules.Attributes
	local players, result, map
	local runner, sitter, haunter

	local function aliveHumanoid(player: any): any
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return humanoid
		end
		return nil
	end

	it("splits three players into 2 Survivors and 1 Haunter", function()
		DataService.Start()
		players = {
			server:addPlayer({ Name = "Runner" }),
			server:addPlayer({ Name = "Sitter" }),
			server:addPlayer({ Name = "Spooky" }),
		}
		server:advance(1)
		map = MapService.Load("ScareMaze")
		local ctx = {
			Map = map,
			Players = players,
			Difficulty = SConfig.Difficulty.Default,
			Playlist = SConfig.Modes.Playlists[1],
			SetState = function(state: string, timeLeft: number)
				RS:SetAttribute("State", state)
				RS:SetAttribute("TimeLeft", timeLeft)
			end,
			Countdown = function(state: string, seconds: number, stopIf: (() -> boolean)?)
				for remaining = seconds, 1, -1 do
					if stopIf and stopIf() then
						return
					end
					RS:SetAttribute("State", state)
					RS:SetAttribute("TimeLeft", remaining)
					server.env.task.wait(1) -- the harness's virtual clock, not Lune's
				end
			end,
			Teleport = function(player: any, spawn: any)
				player.Character:PivotTo(
					SCF.new(spawn.Position + SV3.new(0, SConfig.Maps.SpawnHeight, 0))
				)
			end,
			AliveHumanoid = aliveHumanoid,
		}
		RS:SetAttribute("Mode", "ScareMaze")
		server.env.task.spawn(function()
			result = Mode.Run(ctx)
		end)
		server:flush()
		local survivors = {}
		for _, player in players do
			local team = player:GetAttribute(ATTR.Team)
			if team == "Haunters" then
				haunter = player
			else
				expect(team).toBe("Survivors")
				expect(player:GetAttribute(ATTR.State)).toBe("Running")
				table.insert(survivors, player)
			end
		end
		expect(haunter).toBeTruthy()
		expect(#survivors).toBe(2)
		runner, sitter = survivors[1], survivors[2]
		expect(RS:GetAttribute("Alive")).toBe(2)
		expect(RS:GetAttribute("State")).toBe("Get ready")
		-- Survivors start in the field, the Haunter in the maze.
		local spawnY = map.Floor.Position.Y + map.Floor.Size.Y / 2
		expect(runner.Character:GetPivot().Position.Y).toBeGreaterThan(spawnY)
		expect(haunter.Character:FindFirstChild("Head"):FindFirstChild("ScareMazeTag")).toBeTruthy()
		expect(runner.CameraMaxZoomDistance).toBe(cfg.SurvivorMaxZoom)
	end)

	it(
		"lets the Haunter BOO a Survivor, puts the one who stands still out, and the runner escapes",
		function()
			server:advance(cfg.IntroSeconds + 0.1)
			expect(RS:GetAttribute("State")).toBe("Playing")
			-- The Haunter floats next to the Sitter and BOOs.
			local sitterAt = sitter.Character:GetPivot()
			haunter.Character:PivotTo(sitterAt * SCF.new(4, 0, 0))
			local boo = server:find("ReplicatedStorage.Remotes.ScareMazeBoo")
			server:fireServer(boo, haunter)
			expect(haunter:GetAttribute(ATTR.BooReadyAt)).toBeGreaterThan(
				server.workspace:GetServerTimeNow()
			)
			local booed = false
			for _, call in server:calls("RemoteEvent", "FireClient") do
				if
					call.instance.Name == "ScareMazeScare"
					and call.args[1] == sitter
					and call.args[2] == "Boo"
				then
					booed = true
				end
			end
			expect(booed).toBe(true)
			server:fireServer(boo, runner) -- not a Haunter: ignored
			expect(runner:GetAttribute(ATTR.BooReadyAt)).toBeNil()

			-- The Runner walks (straight, at 20 studs/s) to the exit; the Sitter doesn't move.
			local exit = nil
			for _, d in map.Model:GetDescendants() do
				if d:HasTag("MazeExit") then
					exit = d
				end
			end
			local target = exit.Position + SV3.new(0, -3, 0)
			local escapedAfter = nil
			local sitterOutAfter = nil
			for step = 1, 300 do
				local at = runner.Character:GetPivot().Position
				local flat = SV3.new(target.X - at.X, 0, target.Z - at.Z)
				if flat.Magnitude > 1 then
					local move = flat.Unit * math.min(2, flat.Magnitude)
					runner.Character:PivotTo(SCF.new(at + move))
				end
				server:advance(0.1)
				if not sitterOutAfter and sitter:GetAttribute(ATTR.State) == "Out" then
					sitterOutAfter = step * 0.1
				end
				if runner:GetAttribute(ATTR.State) == "Escaped" then
					escapedAfter = step * 0.1
					break
				end
			end
			expect(escapedAfter).toBeTruthy()
			expect(sitterOutAfter).toBeTruthy()
			-- The BOO's slow + grace pushed the Sitter's 3 seconds back.
			expect(sitterOutAfter).toBeGreaterThan(cfg.StopSeconds + cfg.StartGraceSeconds)
			expect(haunter:GetAttribute(ATTR.Catches)).toBe(1)
			T.note(
				("sitter out after %.1f s, runner escaped after %.1f s"):format(
					sitterOutAfter,
					escapedAfter
				)
			)
			local data = DataService.Get(runner)
			expect(data.Stats.ScareMazeEscapes).toBe(1)
		end
	)

	it("turns the Sitter into a Haunter, ends when nobody is left running, and scores", function()
		server:advance(cfg.OutToHaunterDelay + 0.5)
		local waited = 0
		while result == nil and waited < 10 do
			server:advance(1)
			waited += 1
		end
		expect(result).toBeTruthy()
		expect(result.ScoreLabel).toBe(cfg.Text.ScoreLabel)
		expect(#result.Rows).toBe(3)
		local byName = {}
		for _, row in result.Rows do
			byName[row.Name] = row
		end
		local r = byName[runner.DisplayName]
		expect(r.Badge).toBe(cfg.Text.BadgeEscaped)
		expect(r.Survived).toBe(true)
		expect(r.Top).toBe(true)
		expect(r.Coins).toBeGreaterThan(cfg.Rewards.EscapeCoins)
		expect(result.Rows[1].Name).toBe(runner.DisplayName)
		local s = byName[sitter.DisplayName]
		expect(s.Badge).toBe(cfg.Text.BadgeStopped)
		expect(s.Survived).toBe(false)
		expect(s.Coins).toBe(cfg.Rewards.PlayCoins)
		local h = byName[haunter.DisplayName]
		expect(h.Team).toBe(cfg.Text.TeamHaunter)
		expect(h.Score).toBe(cfg.Rewards.PointsPerCatch)
		expect(h.Coins).toBe(cfg.Rewards.PlayCoins + cfg.Rewards.CoinsPerCatch)
		expect(result.Winner).toBe(cfg.Text.WinnerSome:format(1, 2))
		-- Everything the round set is cleared.
		for _, player in players do
			expect(player:GetAttribute(ATTR.Team)).toBeNil()
			expect(player:GetAttribute(ATTR.State)).toBeNil()
		end
		expect(RS:GetAttribute("Alive")).toBeNil()
		expect(map.Model:FindFirstChild("ScareFX")).toBeNil()
		expect(haunter.Character:FindFirstChild("Head"):FindFirstChild("ScareMazeTag")).toBeNil()
		Mode.Cleanup() -- safe to call again
		MapService.Unload()
	end)
end)

describe("ScareMaze screen", function()
	local client = Runtime.new({ client = true })
	local CConfig = client:require("ReplicatedStorage.Shared.Config")
	local CV3 = client.env.Vector3
	local RS = client.game:GetService("ReplicatedStorage")
	-- What the server would have replicated once a ScareMaze round is on.
	local remotes = client:create("Folder", { Name = "Remotes" }, RS)
	local booRemote = client:create("RemoteEvent", { Name = "ScareMazeBoo" }, remotes)
	local scareRemote = client:create("RemoteEvent", { Name = "ScareMazeScare" }, remotes)
	local me = client.localPlayer
	local gui = client:create("ScreenGui", { Name = "GameUI" }, me:FindFirstChild("PlayerGui"))
	local UI = client:require("StarterPlayer.StarterPlayerScripts.Client.ScareMazeUI")
	local text = CConfig.ScareMaze.Text
	local root, meter, boo, countdown

	it("mounts hidden outside a ScareMaze round", function()
		UI.Mount(gui)
		root = gui:FindFirstChild("ScareMaze")
		expect(root).toBeTruthy()
		meter = root:FindFirstChild("KeepMoving")
		boo = root:FindFirstChild("BooButton")
		countdown = root:FindFirstChild("Countdown")
		expect(root.Visible).toBe(false)
	end)

	it("shows a Survivor the KEEP MOVING meter, then the 3-2-1 when they stand still", function()
		RS:SetAttribute("Mode", "ScareMaze")
		RS:SetAttribute("State", "Playing")
		RS:SetAttribute("Alive", 3)
		me:SetAttribute("InRound", true)
		me:SetAttribute("ScareTeam", "Survivors")
		me:SetAttribute("ScareState", "Running")
		client:advance(0.1)
		expect(root.Visible).toBe(true)
		expect(meter.Visible).toBe(true)
		expect(boo.Visible).toBe(false)
		expect(root:FindFirstChild("TeamTitle").Text).toBe(text.YouAreSurvivor)
		expect(root.Info.Text.Text).toMatch("3")
		client:advance(1.5)
		expect(meter.Label.Text).toBe(text.Move)
		expect(countdown.Visible).toBe(true)
		expect(countdown.Text).toBe("2")
		-- Walking fills it back up.
		me.Character:PivotTo(me.Character:GetPivot() + CV3.new(10, 0, 0))
		client:advance(0.1)
		expect(countdown.Visible).toBe(false)
		expect(meter.Label.Text).toBe(text.KeepMoving)
	end)

	it("plays the jumpscare the server sends", function()
		client:fire(scareRemote, "OnClientEvent", "Zombie")
		client:advance(0.05)
		local overlay = me.PlayerGui:FindFirstChild("ScareMazeJumpscare")
		expect(overlay).toBeTruthy()
		expect(overlay.Enabled).toBe(true)
		client:advance(CConfig.ScareMaze.Jumpscare.Seconds + 0.2)
		expect(overlay.Enabled).toBe(false)
		client:fire(scareRemote, "OnClientEvent", { "not a kind" }) -- ignored
		client:advance(0.05)
		expect(overlay.Enabled).toBe(false)
	end)

	it("gives a Haunter the BOO button (and key) and outlines running Survivors", function()
		local other = client:addPlayer({ Name = "Runner" })
		other:SetAttribute("ScareTeam", "Survivors")
		other:SetAttribute("ScareState", "Running")
		me:SetAttribute("ScareTeam", "Haunters")
		me:SetAttribute("BooReadyAt", 0)
		client:advance(1)
		expect(boo.Visible).toBe(true)
		expect(meter.Visible).toBe(false)
		client:triggerAction("ScareMazeBoo")
		local fired = 0
		for _, call in client:calls("RemoteEvent", "FireServer") do
			if call.instance == booRemote then
				fired += 1
			end
		end
		expect(fired).toBe(1)
		expect(other.Character:FindFirstChild("ScareMazeXRay")).toBeTruthy()
		-- On cooldown: pressing again sends nothing.
		me:SetAttribute("BooReadyAt", client.workspace:GetServerTimeNow() + 5)
		client:advance(0.1)
		expect(boo:FindFirstChild("Cooldown").Visible).toBe(true)
		client:triggerAction("ScareMazeBoo")
		expect(#client:calls("RemoteEvent", "FireServer")).toBe(fired)
	end)

	it("hides everything when the round is over", function()
		RS:SetAttribute("State", "Results")
		client:advance(1)
		expect(root.Visible).toBe(false)
		local runner = client.game:GetService("Players"):FindFirstChild("Runner")
		expect(runner.Character:FindFirstChild("ScareMazeXRay")).toBeNil()
	end)
end)
