-- Game modes, playlists (src/shared/Playlists.luau) and the Ready pad maths
-- (ReadyService.Inside): the pure parts of the round loop. (modules.spec plays a whole round
-- with a player standing on the hub's Ready pad.)

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local CFrame, Vector3 = rt.env.CFrame, rt.env.Vector3
local typeof = Runtime.typeof
local ReplicatedStorage = rt.game:GetService("ReplicatedStorage")
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Playlists = rt:require("ReplicatedStorage.Shared.Playlists")

-- Runs fn with some feature switches changed, then puts them back.
local function withFeatures(changes: { [string]: boolean }, fn: () -> ())
	local saved = {}
	for name, value in changes do
		saved[name] = Config.Features[name]
		Config.Features[name] = value
	end
	local ok, err = pcall(fn)
	for name, value in saved do
		Config.Features[name] = value
	end
	if not ok then
		error(err, 0)
	end
end

local function ids(list: { any }): string
	local out = {}
	for _, playlist in list do
		table.insert(out, playlist.Id)
	end
	return table.concat(out, ",")
end

describe("Config.Modes", function()
	it("gives every mode its settings and a module in src/server/Modes", function()
		local folder = rt:find("ServerScriptService.Server.Modes")
		local count = 0
		for id, mode in Config.Modes.List do
			count += 1
			expect(mode.Name).toBeA("string")
			expect(mode.Description).toBeA("string")
			expect(mode.MinPlayers).toBeA("number")
			expect(mode.MinPlayers).toBeGreaterThanOrEqual(1)
			expect(mode.UsesDifficulty).toBeA("boolean")
			if Config.Features[mode.Feature] == nil then
				error(("%s: Config.Features.%s doesn't exist"):format(id, tostring(mode.Feature)))
			end
			expect(Config.Modes.Order).toContain(id)
			local module = folder:FindFirstChild(id)
			if not (module and module:IsA("ModuleScript")) then
				error(("src/server/Modes/%s.luau doesn't exist"):format(id))
			end
			expect(rt:source(module)).toMatch("function %w+%.Run%(")
		end
		expect(#Config.Modes.Order).toBe(count)
		expect(Config.Modes.List[Config.Modes.FallbackMode]).toBeTruthy()
		expect(Config.Modes.VoteChoices).toBeGreaterThanOrEqual(1)
		expect(Config.Modes.List.KingHunt.UsesDifficulty).toBe(true)
	end)
end)

describe("Playlists", function()
	it("looks playlists up", function()
		expect(Playlists.Get("KingHuntPatch").Map).toBe("PumpkinPatch")
		expect(Playlists.Get("Nope")).toBeNil()
		expect(Playlists.MinPlayers(Playlists.Get("KingHuntPatch"))).toBe(1)
		expect(Playlists.MinPlayers(Playlists.Get("HideSeekFarm"))).toBe(2)
		-- A playlist can ask for more players than its mode, never fewer.
		expect(Playlists.MinPlayers({
			Id = "X",
			Mode = "HideSeek",
			Map = "PumpkinFarm",
			Name = "X",
			MinPlayers = 1,
		})).toBe(2)
		expect(Playlists.MinPlayers({
			Id = "X",
			Mode = "KingHunt",
			Map = "PumpkinPatch",
			Name = "X",
			MinPlayers = 6,
		})).toBe(6)
		expect(Playlists.UsesDifficulty(Playlists.Get("KingHuntMansion"))).toBe(true)
		expect(Playlists.UsesDifficulty(Playlists.Get("ScareMaze"))).toBe(false)
		expect(Playlists.ModeName("KingHunt")).toBe(Config.Modes.List.KingHunt.Name)
		expect(Playlists.ForMap("SpookyMansion", "KingHunt").Id).toBe("KingHuntMansion")
		-- No King Hunt playlist on the Hedge Maze: a made-up one so it can still be played.
		local madeUp = Playlists.ForMap("HedgeMaze", "KingHunt")
		expect(madeUp.Mode).toBe("KingHunt")
		expect(madeUp.Map).toBe("HedgeMaze")
		expect(Playlists.ForMap("HedgeMaze").Mode).toBe("HideSeek")
	end)

	it("only offers switched-on modes that fit the ready players", function()
		withFeatures({ KingHunt = true, HideSeek = false, ScareMaze = false }, function()
			expect(ids(Playlists.Available(1))).toBe("KingHuntPatch,KingHuntMansion")
			expect(ids(Playlists.Available(8))).toBe("KingHuntPatch,KingHuntMansion")
			expect(ids(Playlists.Offer(1, 3))).toBe("KingHuntPatch,KingHuntMansion")
		end)
		withFeatures({ KingHunt = true, HideSeek = true, ScareMaze = true }, function()
			-- 1 player: King Hunt only; 2 players: everything.
			expect(ids(Playlists.Available(1))).toBe("KingHuntPatch,KingHuntMansion")
			expect(#Playlists.Available(2)).toBe(5)
			for _ = 1, 20 do
				local offer = Playlists.Offer(4, 3)
				expect(#offer).toBe(3)
				local seen = {}
				for _, playlist in offer do
					if seen[playlist.Id] then
						error(playlist.Id .. " was offered twice")
					end
					seen[playlist.Id] = true
				end
			end
		end)
		withFeatures({ KingHunt = false, HideSeek = true, ScareMaze = false }, function()
			-- Not enough players for Hide & Seek and King Hunt is off: still one choice.
			local offer = Playlists.Offer(1, 3)
			expect(#offer).toBe(1)
			expect(offer[1].Mode).toBe(Config.Modes.FallbackMode)
			expect(ids(Playlists.Offer(2, 3))).toBe("HideSeekFarm,HideSeekHedgeMaze")
		end)
		withFeatures({ KingHunt = false, HideSeek = false, ScareMaze = false }, function()
			-- Everything off: the fallback.
			expect(#Playlists.Enabled()).toBe(0)
			expect(ids(Playlists.Offer(10, 3))).toBe("KingHuntPatch")
		end)
	end)
end)

describe("Ready pad", function()
	local ReadyService = rt:require("ServerScriptService.Server.Services.ReadyService")
	local inside = ReadyService.Inside

	it("counts a flat pad's middle, edges and jumps", function()
		local pad = CFrame.new(0, 0.5, 0)
		local size = Vector3.new(10, 1, 10)
		expect(inside(Vector3.new(0, 3.5, 0), pad, size, "Block", 1, 12)).toBe(true) -- middle
		expect(inside(Vector3.new(5.8, 3.5, -5.8), pad, size, "Block", 1, 12)).toBe(true) -- corner
		expect(inside(Vector3.new(6.5, 3.5, 0), pad, size, "Block", 1, 12)).toBe(false) -- beside it
		expect(inside(Vector3.new(0, 12.9, 0), pad, size, "Block", 1, 12)).toBe(true) -- jumping
		expect(inside(Vector3.new(0, 13.5, 0), pad, size, "Block", 1, 12)).toBe(false) -- far above
		expect(inside(Vector3.new(0, -2, 0), pad, size, "Block", 1, 12)).toBe(false) -- under it
	end)

	it("handles turned, round and ball pads", function()
		-- A long thin pad turned 45 degrees: along it is inside, straight along world X isn't.
		local turned = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(45), 0)
		local long = Vector3.new(10, 1, 2)
		local along = turned.RightVector * 4 + Vector3.new(0, 3, 0)
		expect(inside(along, turned, long, "Block", 1, 12)).toBe(true)
		expect(inside(Vector3.new(4, 3, 0), turned, long, "Block", 1, 12)).toBe(false)
		-- A round pad: a cylinder stood up (its length axis X points up), 12 studs across.
		local round = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
		local disc = Vector3.new(1, 12, 12)
		expect(inside(Vector3.new(5, 3, 0), round, disc, "Cylinder", 1, 12)).toBe(true)
		expect(inside(Vector3.new(5.5, 3, 5.5), round, disc, "Cylinder", 1, 12)).toBe(false)
		-- (a square pad would count it)
		expect(inside(Vector3.new(5.5, 3, 5.5), round, disc, "Block", 1, 12)).toBe(true)
		-- A ball.
		local ball = Vector3.new(8, 8, 8)
		expect(inside(Vector3.new(4.5, 6, 0), CFrame.new(), ball, "Ball", 1, 12)).toBe(true)
		expect(inside(Vector3.new(5.5, 2, 0), CFrame.new(), ball, "Ball", 1, 12)).toBe(false)
	end)

	it("counts the hub's built pad (the hub section and the Ready pad agree)", function()
		local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
		local hub = HubBuilder.Build()
		local CollectionService = rt.game:GetService("CollectionService")
		local pads = CollectionService:GetTagged("ReadyPad")
		expect(#pads).toBe(1)
		local pad = pads[1]
		expect(pad:IsDescendantOf(hub)).toBe(true)
		local cfg = Config.Lobby.Ready
		local function on(position): boolean
			return inside(position, pad.CFrame, pad.Size, "Block", cfg.EdgeMargin, cfg.PadHeight)
		end
		-- A character's root is about 3 studs above its feet.
		local top = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
		expect(on(top + Vector3.new(0, 3, 0))).toBe(true)
		expect(on(top + Vector3.new(pad.Size.X / 2 - 0.5, 3, 0))).toBe(true)
		expect(on(top + Vector3.new(pad.Size.X / 2 + cfg.EdgeMargin + 2, 3, 0))).toBe(false)
		hub:Destroy()
	end)

	it("makes everyone ready when switched off (no players here)", function()
		expect(ReadyService.Needed()).toBe(math.max(1, Config.Lobby.Ready.MinReady))
		withFeatures({ ReadyPad = false }, function()
			ReadyService.Start() -- returns straight away
			expect(ReadyService.PadsActive()).toBe(false)
			expect(ReadyService.Count()).toBe(0)
		end)
		expect(ReplicatedStorage:GetAttribute("ReadyNeeded")).toBe(ReadyService.Needed())
	end)

	it("has its settings and the spectate settings", function()
		local ready = Config.Lobby.Ready
		for _, key in { "MinReady", "CheckSeconds", "PadHeight", "EdgeMargin", "LeaveGraceSeconds" } do
			expect(ready[key]).toBeA("number")
		end
		for _, key in
			{ "Count", "StandOnPad", "YoureReady", "NextRound", "ReadyNextRound", "VoteHint" }
		do
			expect(ready.Text[key]).toBeA("string")
		end
		local spectate = Config.Lobby.Spectate
		for _, list in { spectate.NextKeys, spectate.PreviousKeys } do
			expect(#list).toBeGreaterThan(0)
			for _, key in list do
				expect(typeof(key)).toBe("EnumItem")
			end
		end
		for _, key in
			{
				"Watching",
				"King",
				"Nobody",
				"NobodyLeft",
				"Next",
				"Previous",
				"Stop",
				"WatchButton",
			}
		do
			expect(spectate.Text[key]).toBeA("string")
		end
		for _, key in { "CancelledSeconds", "ErrorWaitSeconds", "SafetyLimitSeconds" } do
			expect(Config.Round[key]).toBeA("number")
		end
	end)
end)

describe("A round with two players, one on the Ready pad", function()
	local server = Runtime.new()
	local ServerConfig = server:require("ReplicatedStorage.Shared.Config")
	local RS = server.game:GetService("ReplicatedStorage")
	local ready, lobby

	it("takes only the player on the pad into the round", function()
		local ok, err = server:runScript("ServerScriptService.Server.Main")
		if not ok then
			error(err, 0)
		end
		server:advance(1)
		ready = server:addPlayer({ Name = "OnThePad" })
		lobby = server:addPlayer({ Name = "InTheLobby" })
		server:advance(2)
		local pad = server.game:GetService("CollectionService"):GetTagged("ReadyPad")[1]
		ready.Character:PivotTo(pad.CFrame + server.env.Vector3.new(0, pad.Size.Y / 2 + 3, 0))
		local r = ServerConfig.Round
		local waited = 0
		while
			RS:GetAttribute("State") ~= "Playing"
			and waited < ServerConfig.Voting.Seconds + r.IntermissionSeconds + 30
		do
			server:advance(1)
			waited += 1
		end
		expect(RS:GetAttribute("State")).toBe("Playing")
		expect(ready:GetAttribute("InRound")).toBe(true)
		expect(lobby:GetAttribute("InRound")).never.toBe(true)
		expect(lobby:GetAttribute("Ready")).toBe(false)
	end)

	it("streams the map to the lobby player who spectates, not to the one playing", function()
		local remote = server:find("ReplicatedStorage.Remotes.SpectateFocus")
		server:fireServer(remote, lobby, true)
		server:fireServer(remote, ready, true)
		server:fireServer(remote, lobby, "yes please") -- wrong type: ignored
		local map = server.workspace:FindFirstChild("Map")
		expect(map).toBeInstanceOf("Model")
		expect(lobby.ReplicationFocus).toBe(map:FindFirstChild("Floor", true))
		expect(ready.ReplicationFocus).toBeNil()
	end)

	it("sends the player back to the lobby, not ready, and stops the streaming", function()
		local r = ServerConfig.Round
		local waited = 0
		while
			RS:GetAttribute("State") ~= "Waiting for players"
			and waited < r.Duration + r.ResultsSeconds + 30
		do
			server:advance(1)
			waited += 1
		end
		expect(RS:GetAttribute("State")).toBe("Waiting for players")
		expect(ready:GetAttribute("InRound")).never.toBe(true)
		expect(ready:GetAttribute("Ready")).toBe(false)
		expect(lobby.ReplicationFocus).toBeNil()
		server:removePlayer(ready)
		server:removePlayer(lobby)
		server:advance(2)
	end)
end)
