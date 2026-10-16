-- Crumbling Crypt (mode TileFall): the settings, the map (goo Floor, slab layers, spawns on the
-- top layer, deterministic, phone budget), whole rounds on the real map with fake players
-- (a slab you step on cracks, drops after the delay and stays gone while untouched ones stay;
-- falling through into the goo; the last one standing of three wins; solo; sudden death; a
-- leaver on Hard, which rebuilds the slabs; the anti-cheat) and the screen.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Tags = rt:require("ReplicatedStorage.Shared.Tags")
local Builder = rt:require("ServerScriptService.Server.Maps.CrumblingCrypt")
local Board = rt:require("ServerScriptService.Server.Modes.TileFallBoard")

local function mapDef(cfg: any): any
	for _, def in cfg.Maps.List do
		if def.Id == "CrumblingCrypt" then
			return def
		end
	end
	error("Config.Maps.List has no CrumblingCrypt map")
end

-- The slabs tagged TileFallTile inside `root`.
local function slabs(_runtime: any, root: any): { any }
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag(Tags.TileFallTile) then
			table.insert(list, d)
		end
	end
	return list
end

describe("Crumbling Crypt settings", function()
	it("has both difficulties, and Easy really is easier", function()
		local cfg = Config.TileFall
		local easy, hard = cfg.Difficulty.Easy, cfg.Difficulty.Hard
		expect(easy).toBeTruthy()
		expect(hard).toBeTruthy()
		for _, level in { easy, hard } do
			for _, key in
				{
					"Layers",
					"TileSize",
					"CrumbleSeconds",
					"GraceSeconds",
					"Duration",
					"SuddenDeathAfter",
					"RewardMultiplier",
				}
			do
				expect(level[key]).toBeA("number")
			end
		end
		expect(easy.Layers).toBe(5)
		expect(hard.Layers).toBe(4)
		expect(easy.TileSize).toBeGreaterThan(hard.TileSize)
		expect(easy.CrumbleSeconds).toBeGreaterThan(hard.CrumbleSeconds)
		expect(easy.GraceSeconds).toBeGreaterThan(hard.GraceSeconds)
		expect(Config.Modes.List.TileFall.MinPlayers).toBe(1)
		expect(Config.Features.TileFall).toBeA("boolean")
		-- The lowest layer is above the "out" height, and you can't jump back up a layer.
		local def = mapDef(Config)
		local lowest = def.Board.TopHeight - (easy.Layers - 1) * def.Board.LayerSpacing
		expect(lowest).toBeGreaterThan(cfg.OutHeight + 5)
		expect(def.Board.LayerSpacing).toBeGreaterThan(cfg.StandReach + 1)
		expect(def.SpawnRadius).toBeLessThan(def.Board.Size / 2 - 2)
	end)
end)

describe("Crumbling Crypt map", function()
	local def = mapDef(Config)
	local model

	it("builds the goo Floor, the slab layers and the spawns on the top layer", function()
		model = Builder.Build(def)
		local floor = model:FindFirstChild("Floor")
		expect(floor).toBeInstanceOf("Part")
		expect(floor:HasTag(Tags.TileFallGoo)).toBe(true)
		local gooY = floor.Position.Y + floor.Size.Y / 2
		local easy = Config.TileFall.Difficulty.Easy
		local count = Board.Count(def.Board, easy.TileSize)
		local all = slabs(rt, model)
		expect(#all).toBe(count * count * easy.Layers)
		local perLayer = {}
		for _, slab in all do
			local layer = slab:GetAttribute("Layer")
			perLayer[layer] = (perLayer[layer] or 0) + 1
			local top = slab.Position.Y + slab.Size.Y / 2
			expect(top).toBeNear(Board.LayerTop(gooY, def.Board, layer), 1e-3)
			expect(slab.CanCollide).toBe(true)
			expect(slab.Anchored).toBe(true)
		end
		for layer = 1, easy.Layers do
			expect(perLayer[layer]).toBe(count * count)
		end
		local topY = Board.LayerTop(gooY, def.Board, 1)
		local spawns = model:FindFirstChild(def.SpawnFolder):GetChildren()
		expect(#spawns).toBe(def.Spawns)
		for _, spawn in spawns do
			expect(spawn.Position.Y - spawn.Size.Y / 2).toBeNear(topY, 1e-3)
			-- Right over a top-layer slab.
			local over = false
			for _, slab in all do
				local d = slab.CFrame:PointToObjectSpace(spawn.Position)
				if
					slab:GetAttribute("Layer") == 1
					and math.abs(d.X) <= slab.Size.X / 2
					and math.abs(d.Z) <= slab.Size.Z / 2
				then
					over = true
				end
			end
			expect(over).toBe(true)
		end
	end)

	it("keeps decorations walk-through and stays inside the phone budget", function()
		local parts, lights = 0, 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			elseif d:IsA("Light") and d.Enabled then
				lights += 1
			end
		end
		expect(parts).toBeLessThan(3000)
		expect(lights).toBeLessThanOrEqual(16)
		-- Nothing solid sticks up within jumping reach round the slabs except the slabs.
		local half = def.Board.Size / 2
		local floor = model:FindFirstChild("Floor")
		local gooY = floor.Position.Y + floor.Size.Y / 2
		for _, d in model:GetDescendants() do
			if
				d:IsA("BasePart")
				and d.CanCollide
				and not d:HasTag(Tags.TileFallTile)
				and d ~= floor
			then
				local p = d.Position
				local close = math.abs(p.X - floor.Position.X) < half + 16
					and math.abs(p.Z - floor.Position.Z) < half + 16
				local high = p.Y + d.Size.Y / 2 > gooY + Config.TileFall.OutHeight
				if close and high then
					error(("%s is solid next to the slabs"):format(d:GetFullName()))
				end
			end
		end
		T.note(("%d parts, %d lights"):format(parts, lights))
	end)

	it("builds the same map every time", function()
		local again = Builder.Build(def)
		local a, b = slabs(rt, model), slabs(rt, again)
		expect(#rt:parts(again)).toBe(#rt:parts(model))
		expect(#a).toBe(#b)
		for i = 1, #a do
			expect(a[i].Position).toBeNear(b[i].Position, 1e-6)
		end
		model:Destroy()
		again:Destroy()
	end)

	it("builds Hard's board: fewer floors of smaller slabs at the same heights", function()
		local folder = rt:create("Folder", { Name = "Holder" })
		local hard = Config.TileFall.Difficulty.Hard
		local tiles = Board.Build(
			folder,
			rt.env.Vector3.new(0, 0, 0),
			def.Board,
			hard.Layers,
			hard.TileSize,
			def.Colors
		)
		local count = Board.Count(def.Board, hard.TileSize)
		expect(#slabs(rt, tiles)).toBe(count * count * hard.Layers)
		expect(tiles:GetAttribute("Layers")).toBe(4)
		expect(count).toBeGreaterThan(
			Board.Count(def.Board, Config.TileFall.Difficulty.Easy.TileSize)
		)
		folder:Destroy()
	end)
end)

-- A server with the real map and a running round. Returns a world table.
local function startRound(names: { string }, difficulty: string, tweak: ((any) -> ())?): any
	local server = Runtime.new()
	local w: any = {
		server = server,
		Config = server:require("ReplicatedStorage.Shared.Config"),
		RS = server.game:GetService("ReplicatedStorage"),
		V3 = server.env.Vector3,
		CF = server.env.CFrame,
		MapService = server:require("ServerScriptService.Server.Services.MapService"),
		Mode = server:require("ServerScriptService.Server.Modes.TileFall"),
		players = {},
	}
	if tweak then
		tweak(w.Config)
	end
	for _, name in names do
		table.insert(w.players, server:addPlayer({ Name = name }))
	end
	server:advance(1)
	w.map = w.MapService.Load("CrumblingCrypt")
	w.gooY = w.map.Floor.Position.Y + w.map.Floor.Size.Y / 2
	w.level = w.Config.TileFall.Difficulty[difficulty]
	local RS, SV3, SCF = w.RS, w.V3, w.CF
	RS:SetAttribute("Mode", "TileFall")
	server.env.task.spawn(function()
		w.result = w.Mode.Run({
			Map = w.map,
			Players = w.players,
			Difficulty = difficulty,
			Playlist = w.Config.Modes.Playlists[1],
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
					server.env.task.wait(1)
				end
			end,
			Teleport = function(player: any, spawn: any)
				player.Character:PivotTo(
					SCF.new(spawn.Position + SV3.new(0, w.Config.Maps.SpawnHeight, 0))
				)
			end,
			AliveHumanoid = function(player: any): any
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				return if humanoid and humanoid.Health > 0 then humanoid else nil
			end,
		})
	end)
	server:flush()
	function w.at(player: any): any
		return player.Character.HumanoidRootPart.Position
	end
	-- The slab whose footprint holds (x, z) on `layer`.
	function w.slabAt(x: number, z: number, layer: number): any
		for _, slab in slabs(server, w.map.Model) do
			if slab:GetAttribute("Layer") == layer then
				local d = slab.CFrame:PointToObjectSpace(SV3.new(x, slab.Position.Y, z))
				if math.abs(d.X) <= slab.Size.X / 2 and math.abs(d.Z) <= slab.Size.Z / 2 then
					return slab
				end
			end
		end
		return nil
	end
	-- Walks `player` (14 studs/s) to (x, z) on the level they're on.
	function w.walk(player: any, x: number, z: number)
		for _ = 1, 200 do
			local now = w.at(player)
			local flat = SV3.new(x - now.X, 0, z - now.Z)
			if flat.Magnitude < 0.5 then
				return
			end
			player.Character:PivotTo(SCF.new(now + flat.Unit * math.min(1.4, flat.Magnitude)))
			server:advance(0.1)
		end
	end
	-- Drops `player` straight down to `y` (falling is always allowed).
	function w.dropTo(player: any, y: number)
		local now = w.at(player)
		player.Character:PivotTo(SCF.new(now.X, y, now.Z))
	end
	-- Advances until Run returned (at most `seconds`).
	function w.finish(seconds: number)
		local waited = 0
		while w.result == nil and waited < seconds do
			server:advance(0.5)
			waited += 0.5
		end
		expect(w.result).toBeTruthy()
	end
	return w
end

describe("A Crumbling Crypt round, alone", function()
	local w = startRound({ "Hopper" }, "Easy")
	local cfg = w.Config.TileFall
	local player = w.players[1]
	local spawnSlab, farSlab, firstGone

	it("starts frozen on a top-layer slab with 'Get ready', alone", function()
		expect(w.RS:GetAttribute("State")).toBe("Get ready")
		expect(w.RS:GetAttribute("TileFallSolo")).toBe(true)
		expect(w.RS:GetAttribute("Alive")).toBe(1)
		expect(player:GetAttribute("TileFallState")).toBe("In")
		local at = w.at(player)
		spawnSlab = w.slabAt(at.X, at.Z, 1)
		expect(spawnSlab).toBeTruthy()
		farSlab = w.slabAt(2 * w.map.Floor.Position.X - at.X, 2 * w.map.Floor.Position.Z - at.Z, 1)
		expect(farSlab).toBeTruthy()
		expect(farSlab).never.toBe(spawnSlab)
	end)

	it("cracks nothing during the safe start, then cracks the slab you stand on", function()
		w.server:advance(cfg.IntroSeconds + 0.2)
		expect(w.RS:GetAttribute("State")).toBe("Playing")
		w.server:advance(w.level.GraceSeconds - 0.5)
		expect(spawnSlab:GetAttribute("TileState")).toBeNil()
		w.server:advance(0.7)
		expect(spawnSlab:GetAttribute("TileState")).toBe("Cracking")
		expect(spawnSlab.Color).toBeNear(cfg.CrackColor)
		expect(spawnSlab.CanCollide).toBe(true) -- still solid while it cracks
	end)

	it("drops it after the delay, for good, and leaves the slabs nobody touched", function()
		-- Walk off towards the middle.
		local centre = w.map.Floor.Position
		w.walk(player, centre.X, centre.Z)
		expect(spawnSlab:GetAttribute("TileState")).toBe("Gone")
		expect(spawnSlab.CanCollide).toBe(false)
		expect(spawnSlab.Transparency).toBe(1)
		firstGone = spawnSlab
		expect(farSlab:GetAttribute("TileState")).toBeNil()
		expect(farSlab.CanCollide).toBe(true)
		local cracked = 0
		for _, slab in slabs(w.server, w.map.Model) do
			if slab:GetAttribute("TileState") ~= nil then
				cracked += 1
			end
		end
		-- Only the slabs along the path.
		expect(cracked).toBeLessThan(8)
		T.note(cracked, "slabs cracked walking to the middle")
	end)

	it("falls through to the next layer (cracking it), then into the goo: out", function()
		local at = w.at(player)
		local layer2 = Board.LayerTop(w.gooY, mapDef(w.Config).Board, 2)
		w.dropTo(player, layer2 + 3)
		w.server:advance(0.25)
		local below = w.slabAt(at.X, at.Z, 2)
		expect(below:GetAttribute("TileState")).toBe("Cracking")
		expect(player:GetAttribute("TileFallState")).toBe("In")
		w.dropTo(player, w.gooY + 3)
		w.server:advance(0.25)
		expect(player:GetAttribute("TileFallState")).toBe("Out")
		expect(player:GetAttribute("Out")).toBe(true) -- a ghost now (GhostService)
		expect(w.RS:GetAttribute("Alive")).toBe(0)
		-- The first slab never came back.
		expect(firstGone:GetAttribute("TileState")).toBe("Gone")
	end)

	it("ends with the seconds you stayed up and cleans up", function()
		w.finish(3)
		local result = w.result
		expect(#result.Rows).toBe(1)
		local row = result.Rows[1]
		expect(row.Survived).toBe(false)
		expect(row.Top).toBe(false)
		expect(row.Score).toBeGreaterThanOrEqual(math.floor(w.level.GraceSeconds))
		expect(row.Coins).toBe(cfg.Rewards.PlayCoins * w.level.RewardMultiplier)
		expect(result.ScoreLabel).toBe(cfg.Text.ScoreLabel)
		expect(result.Winner).toBe(cfg.Text.SoloFell:format(row.Score))
		expect(player:GetAttribute("TileFallState")).toBeNil()
		expect(w.RS:GetAttribute("Alive")).toBeNil()
		expect(w.RS:GetAttribute("TileFallSolo")).toBeNil()
		w.Mode.Cleanup() -- safe to call again
		w.MapService.Unload()
	end)
end)

describe("A Crumbling Crypt round, alone, until the clock runs out", function()
	local w = startRound({ "Stayer" }, "Easy", function(config: any)
		config.TileFall.Difficulty.Easy.Duration = 8
		config.TileFall.Difficulty.Easy.GraceSeconds = 100
		config.TileFall.SuddenDeath.On = false
	end)
	local cfg = w.Config.TileFall
	local player = w.players[1]

	it("survives, celebrates and gets the solo prize", function()
		w.server:advance(cfg.IntroSeconds + 0.2)
		w.server:advance(8)
		expect(player:GetAttribute("TileFallState")).toBe("Winner")
		expect(w.result).toBeNil() -- the winner's moment on the map first
		w.finish(cfg.CelebrateSeconds + 2)
		local row = w.result.Rows[1]
		expect(row.Survived).toBe(true)
		expect(row.Top).toBe(true)
		expect(row.Score).toBeGreaterThanOrEqual(7)
		expect(row.Coins).toBe(cfg.Rewards.PlayCoins + cfg.Rewards.SoloSurviveCoins)
		expect(w.result.Winner).toBe(cfg.Text.SoloSurvived)
		expect(player:GetAttribute("TileFallState")).toBeNil()
		w.MapService.Unload()
	end)
end)

describe("Crumbling Crypt sudden death", function()
	local w = startRound({ "Waiter", "Other" }, "Easy", function(config: any)
		config.TileFall.Difficulty.Easy.GraceSeconds = 100
		config.TileFall.Difficulty.Easy.SuddenDeathAfter = 2
	end)
	local cfg = w.Config.TileFall

	it("cracks random slabs by itself after a while", function()
		w.server:advance(cfg.IntroSeconds + 0.2)
		w.server:advance(1)
		expect(w.RS:GetAttribute("TileFallSuddenDeath")).toBeNil()
		w.server:advance(1.3)
		expect(w.RS:GetAttribute("TileFallSuddenDeath")).toBe(true)
		local cracked = 0
		for _, slab in slabs(w.server, w.map.Model) do
			if slab:GetAttribute("TileState") ~= nil then
				cracked += 1
			end
		end
		expect(cracked).toBe(cfg.SuddenDeath.Tiles)
		w.server:advance(cfg.SuddenDeath.Every)
		local more = 0
		for _, slab in slabs(w.server, w.map.Model) do
			if slab:GetAttribute("TileState") ~= nil then
				more += 1
			end
		end
		expect(more).toBe(cfg.SuddenDeath.Tiles * 2 + cfg.SuddenDeath.Grow)
		w.Mode.Cleanup()
		expect(w.RS:GetAttribute("TileFallSuddenDeath")).toBeNil()
		w.MapService.Unload()
	end)
end)

describe("A Crumbling Crypt round with three players", function()
	local w = startRound({ "Faller", "Resetter", "Champ" }, "Easy")
	local cfg = w.Config.TileFall
	local faller, resetter, champ = w.players[1], w.players[2], w.players[3]

	it("counts a fall and a reset as out, and ends with the last one standing", function()
		w.server:advance(cfg.IntroSeconds + 0.2)
		expect(w.RS:GetAttribute("Alive")).toBe(3)
		w.dropTo(faller, w.gooY + 2)
		w.server:advance(0.3)
		expect(faller:GetAttribute("TileFallState")).toBe("Out")
		expect(w.RS:GetAttribute("Alive")).toBe(2)
		w.server:advance(0.3)
		resetter.Character:FindFirstChildOfClass("Humanoid").Health = 0
		w.server:advance(0.2)
		expect(resetter:GetAttribute("TileFallState")).toBe("Out")
		expect(w.RS:GetAttribute("Alive")).toBe(1)
		w.server:advance(1.2)
		expect(champ:GetAttribute("TileFallState")).toBe("Winner")
		w.finish(cfg.CelebrateSeconds + 2)
		local rows = w.result.Rows
		expect(#rows).toBe(3)
		expect(rows[1].Name).toBe(champ.DisplayName)
		expect(rows[1].Top).toBe(true)
		expect(rows[1].Survived).toBe(true)
		expect(rows[1].Badge).toBe(cfg.Text.BadgeWinner)
		expect(rows[1].Coins).toBe(cfg.Rewards.PlayCoins + cfg.Rewards.PlaceCoins[1])
		expect(rows[2].Name).toBe(resetter.DisplayName)
		expect(rows[2].Stat).toBe(cfg.Text.StatPlace:format("2nd"))
		expect(rows[2].Top).toBe(false)
		expect(rows[3].Name).toBe(faller.DisplayName)
		expect(rows[3].Badge).toBe(cfg.Text.BadgeFell)
		expect(rows[3].Coins).toBe(cfg.Rewards.PlayCoins + cfg.Rewards.PlaceCoins[3])
		expect(w.result.Winner).toBe(cfg.Text.WinnerOne:format(champ.DisplayName))
		-- A respawned (dead) player stays out: no trip back onto the slabs.
		w.server:spawnCharacter(resetter)
		w.server:advance(0.2)
		expect(resetter:GetAttribute("TileFallState")).toBeNil()
		w.MapService.Unload()
	end)
end)

describe("A Hard Crumbling Crypt round with a leaver and a cheat", function()
	-- (No cracking from standing still here: the harness has no gravity, so nobody would fall.)
	local w = startRound({ "Leaver", "Cheat", "Stays" }, "Hard", function(config: any)
		config.TileFall.Difficulty.Hard.GraceSeconds = 100
	end)
	local cfg = w.Config.TileFall
	local leaver, cheat, stays = w.players[1], w.players[2], w.players[3]

	it("rebuilds the slabs for Hard", function()
		local hard = cfg.Difficulty.Hard
		local count = Board.Count(mapDef(w.Config).Board, hard.TileSize)
		local all = slabs(w.server, w.map.Model)
		expect(#all).toBe(count * count * hard.Layers)
		-- Everyone still starts on a slab.
		for _, player in w.players do
			local at = w.at(player)
			expect(w.slabAt(at.X, at.Z, 1)).toBeTruthy()
		end
	end)

	it("puts a teleporter back and counts a player who left the crypt out", function()
		w.server:advance(cfg.IntroSeconds + 0.2)
		local start = w.at(cheat)
		cheat.Character:PivotTo(w.CF.new(start + w.V3.new(30, 0, 0)))
		w.server:advance(0.15)
		expect(cheat:GetAttribute("TileFallState")).toBe("In")
		expect((w.at(cheat) - start).Magnitude).toBeLessThan(1)
		-- Flying straight up is put back too.
		cheat.Character:PivotTo(w.CF.new(start + w.V3.new(0, 40, 0)))
		w.server:advance(0.15)
		expect(w.at(cheat).Y).toBeLessThan(start.Y + 1)
		-- Hovering with no slab underneath is out after MaxAirSeconds.
		-- (below Hard's lowest floor: nothing underneath, still above the goo)
		local floors = w.Config.TileFall.Difficulty.Hard.Layers
		local below = start.Y - floors * mapDef(w.Config).Board.LayerSpacing
		expect(w.slabAt(start.X, start.Z, 5)).toBeNil() -- Hard has no fifth floor
		w.dropTo(cheat, below + 5)
		w.server:advance(cfg.MaxAirSeconds + 0.3)
		expect(cheat:GetAttribute("TileFallState")).toBe("Out")
	end)

	it("ends when the leaver is gone, without them in the results", function()
		w.server:removePlayer(leaver)
		w.server:advance(0.1)
		expect(w.RS:GetAttribute("Alive")).toBe(1)
		w.finish(cfg.CelebrateSeconds + 3)
		local rows = w.result.Rows
		expect(#rows).toBe(2)
		expect(rows[1].Name).toBe(stays.DisplayName)
		expect(rows[1].Top).toBe(true)
		local hard = cfg.Difficulty.Hard
		expect(rows[1].Coins).toBe(
			(cfg.Rewards.PlayCoins + cfg.Rewards.PlaceCoins[1]) * hard.RewardMultiplier
		)
		expect(rows[2].Name).toBe(cheat.DisplayName)
		w.Mode.Cleanup()
		w.MapService.Unload()
	end)
end)

describe("Crumbling Crypt screen", function()
	local client = Runtime.new({ client = true })
	local CConfig = client:require("ReplicatedStorage.Shared.Config")
	local CTags = client:require("ReplicatedStorage.Shared.Tags")
	local RS = client.game:GetService("ReplicatedStorage")
	local CollectionService = client.game:GetService("CollectionService")
	local me = client.localPlayer
	local gui = client:create("ScreenGui", { Name = "GameUI" }, me:FindFirstChild("PlayerGui"))
	local UI = client:require("StarterPlayer.StarterPlayerScripts.Client.TileFallUI")
	local text = CConfig.TileFall.Text
	local root

	it("mounts hidden outside a Crumbling Crypt round", function()
		UI.Mount(gui)
		root = gui:FindFirstChild("TileFall")
		expect(root).toBeTruthy()
		expect(root.Visible).toBe(false)
	end)

	it("shows Get ready, GO!, players left and the clock", function()
		RS:SetAttribute("Mode", "TileFall")
		RS:SetAttribute("TileFallSolo", false)
		me:SetAttribute("InRound", true)
		me:SetAttribute("TileFallState", "In")
		RS:SetAttribute("State", "Get ready")
		client:advance(0.1)
		expect(root.Visible).toBe(true)
		expect(root.Message.Text).toBe(text.GetReady)
		expect(root.SubMessage.Text).toBe(text.Hint)
		RS:SetAttribute("State", "Playing")
		RS:SetAttribute("Alive", 3)
		RS:SetAttribute("TimeLeft", 75)
		client:advance(0.1)
		expect(root.Message.Text).toBe(text.Go)
		expect(root.Info.Text.Text).toBe(text.PlayersLeft:format(3) .. "  |  1:15")
	end)

	it("says you fell in and shows Watching while you're a ghost", function()
		me:SetAttribute("TileFallState", "Out")
		client:advance(0.1)
		expect(root.Message.Text).toBe(text.Out)
		expect(root.Watching.Visible).toBe(true)
	end)

	it("throws confetti for the winner", function()
		me:SetAttribute("TileFallState", "Winner")
		client:advance(0.1)
		expect(root.Message.Text).toBe(text.Winner)
		expect(gui:FindFirstChild("FxConfetti")).toBeTruthy()
	end)

	it("shakes a cracking slab and drops a falling piece, then cleans up", function()
		local camera = client.workspace.CurrentCamera
		local slab = client:create("Part", {
			Name = "Slab",
			Anchored = true,
			Size = client.env.Vector3.new(12, 1.6, 12),
			CFrame = client.env.CFrame.new(
				camera.CFrame.Position + client.env.Vector3.new(0, -10, -10)
			),
		}, client.workspace)
		CollectionService:AddTag(slab, CTags.TileFallTile)
		local home = slab.CFrame
		slab:SetAttribute("CrumbleAt", client.workspace:GetServerTimeNow() + 1)
		slab:SetAttribute("TileState", "Cracking")
		client:advance(0.1)
		expect((slab.CFrame.Position - home.Position).Magnitude).toBeGreaterThan(0)
		expect((slab.CFrame.Position - home.Position).Magnitude).toBeLessThanOrEqual(
			CConfig.TileFall.Effects.ShakeStuds * 1.5
		)
		slab:SetAttribute("TileState", "Gone")
		slab.Transparency = 1
		client:advance(0.05)
		expect(slab.CFrame.Position).toBeNear(home.Position, 1e-6)
		local piece = camera:FindFirstChild("FallingSlab")
		expect(piece).toBeTruthy()
		expect(piece:HasTag(CTags.TileFallTile)).toBe(false)
		expect(piece.CanCollide).toBe(false)
		client:advance(CConfig.TileFall.Effects.FallSeconds + 0.6)
		expect(camera:FindFirstChild("FallingSlab")).toBeNil()
	end)

	it("hides everything when the round is over", function()
		RS:SetAttribute("State", "Results")
		client:advance(0.1)
		expect(root.Visible).toBe(false)
	end)
end)
