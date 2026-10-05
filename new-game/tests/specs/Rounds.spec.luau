--!strict
-- Game modes, playlists (src/shared/Playlists.luau) and the Ready pad maths
-- (ReadyService.Inside): the pure parts of the round loop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(t: any)
	local Config = require(ReplicatedStorage.Shared.Config) :: any
	local Playlists = require(ReplicatedStorage.Shared.Playlists) :: any

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

	t.test("every mode has its settings and a module in src/server/Modes", function()
		local count = 0
		for id, mode in Config.Modes.List do
			count += 1
			t.eq(type(mode.Name), "string", id .. ".Name")
			t.eq(type(mode.Description), "string", id .. ".Description")
			t.eq(type(mode.MinPlayers), "number", id .. ".MinPlayers")
			t.ok(mode.MinPlayers >= 1, id .. ".MinPlayers is at least 1")
			t.eq(type(mode.UsesDifficulty), "boolean", id .. ".UsesDifficulty")
			t.ok(Config.Features[mode.Feature] ~= nil, id .. ": Config.Features." .. mode.Feature)
			t.ok(table.find(Config.Modes.Order, id), id .. " is in Config.Modes.Order")
			local module = t.Server.Modes:FindFirstChild(id)
			t.ok(module and module:IsA("ModuleScript"), "src/server/Modes/" .. id .. ".luau")
			local source = t.readFile("src/server/Modes/" .. id .. ".luau")
			t.ok(source and source:find("function %w+%.Run%("), id .. " has a Run function")
		end
		t.eq(count, #Config.Modes.Order, "Order lists every mode once")
		t.ok(Config.Modes.List[Config.Modes.FallbackMode], "FallbackMode is a real mode")
		t.ok(Config.Modes.VoteChoices >= 1, "VoteChoices")
		t.eq(Config.Modes.List.KingHunt.UsesDifficulty, true, "King Hunt keeps the difficulty vote")
	end)

	t.test("playlist lookups", function()
		t.eq(Playlists.Get("KingHuntPatch").Map, "PumpkinPatch")
		t.eq(Playlists.Get("Nope"), nil)
		t.eq(Playlists.MinPlayers(Playlists.Get("KingHuntPatch")), 1)
		t.eq(Playlists.MinPlayers(Playlists.Get("HideSeekFarm")), 2)
		-- A playlist can ask for more players than its mode, never fewer.
		t.eq(
			Playlists.MinPlayers({
				Id = "X",
				Mode = "HideSeek",
				Map = "PumpkinFarm",
				Name = "X",
				MinPlayers = 1,
			}),
			2
		)
		t.eq(
			Playlists.MinPlayers({
				Id = "X",
				Mode = "KingHunt",
				Map = "PumpkinPatch",
				Name = "X",
				MinPlayers = 6,
			}),
			6
		)
		t.eq(Playlists.UsesDifficulty(Playlists.Get("KingHuntMansion")), true)
		t.eq(Playlists.UsesDifficulty(Playlists.Get("ScareMaze")), false)
		t.eq(Playlists.ModeName("KingHunt"), Config.Modes.List.KingHunt.Name)
		t.eq(Playlists.ForMap("SpookyMansion", "KingHunt").Id, "KingHuntMansion")
		-- No King Hunt playlist on the Hedge Maze: a made-up one so it can still be played.
		local madeUp = Playlists.ForMap("HedgeMaze", "KingHunt")
		t.eq(madeUp.Mode, "KingHunt")
		t.eq(madeUp.Map, "HedgeMaze")
		t.eq(Playlists.ForMap("HedgeMaze").Mode, "HideSeek")
	end)

	t.test("the vote only offers switched-on modes that fit the ready players", function()
		withFeatures({ KingHunt = true, HideSeek = false, ScareMaze = false }, function()
			t.eq(ids(Playlists.Available(1)), "KingHuntPatch,KingHuntMansion")
			t.eq(ids(Playlists.Available(8)), "KingHuntPatch,KingHuntMansion")
			t.eq(ids(Playlists.Offer(1, 3)), "KingHuntPatch,KingHuntMansion")
		end)
		withFeatures({ KingHunt = true, HideSeek = true, ScareMaze = true }, function()
			t.eq(
				ids(Playlists.Available(1)),
				"KingHuntPatch,KingHuntMansion",
				"1 player: King Hunt only"
			)
			t.eq(#Playlists.Available(2), 5, "2 players: everything")
			for _ = 1, 20 do
				local offer = Playlists.Offer(4, 3)
				t.eq(#offer, 3, "VoteChoices picks")
				local seen = {}
				for _, playlist in offer do
					t.ok(not seen[playlist.Id], "no playlist offered twice")
					seen[playlist.Id] = true
				end
			end
		end)
		withFeatures({ KingHunt = false, HideSeek = true, ScareMaze = false }, function()
			-- Not enough players for Hide & Seek and King Hunt is off: still one choice.
			local offer = Playlists.Offer(1, 3)
			t.eq(#offer, 1)
			t.eq(offer[1].Mode, Config.Modes.FallbackMode)
			t.eq(ids(Playlists.Offer(2, 3)), "HideSeekFarm,HideSeekHedgeMaze")
		end)
		withFeatures({ KingHunt = false, HideSeek = false, ScareMaze = false }, function()
			t.eq(#Playlists.Enabled(), 0)
			t.eq(ids(Playlists.Offer(10, 3)), "KingHuntPatch", "everything off: fallback")
		end)
	end)

	t.test("Ready pad: flat pad, edges and height", function()
		local ReadyService = require(t.Server.Services.ReadyService) :: any
		local inside = ReadyService.Inside
		local pad = CFrame.new(0, 0.5, 0)
		local size = Vector3.new(10, 1, 10)
		t.ok(inside(Vector3.new(0, 3.5, 0), pad, size, "Block", 1, 12), "standing in the middle")
		t.ok(inside(Vector3.new(5.8, 3.5, -5.8), pad, size, "Block", 1, 12), "feet over the corner")
		t.ok(not inside(Vector3.new(6.5, 3.5, 0), pad, size, "Block", 1, 12), "next to the pad")
		t.ok(inside(Vector3.new(0, 12.9, 0), pad, size, "Block", 1, 12), "jumping")
		t.ok(not inside(Vector3.new(0, 13.5, 0), pad, size, "Block", 1, 12), "far above")
		t.ok(not inside(Vector3.new(0, -2, 0), pad, size, "Block", 1, 12), "under the floor")
	end)

	t.test("Ready pad: turned, round and ball pads", function()
		local ReadyService = require(t.Server.Services.ReadyService) :: any
		local inside = ReadyService.Inside
		-- A long thin pad turned 45 degrees: along it is inside, straight along world X isn't.
		local turned = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(45), 0)
		local long = Vector3.new(10, 1, 2)
		local along = turned.RightVector * 4 + Vector3.new(0, 3, 0)
		t.ok(inside(along, turned, long, "Block", 1, 12), "along the turned pad")
		t.ok(not inside(Vector3.new(4, 3, 0), turned, long, "Block", 1, 12), "off the turned pad")
		-- A round pad: a cylinder stood up (its length axis X points up), 12 studs across.
		local round = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
		local disc = Vector3.new(1, 12, 12)
		t.ok(inside(Vector3.new(5, 3, 0), round, disc, "Cylinder", 1, 12), "on the disc")
		t.ok(not inside(Vector3.new(5.5, 3, 5.5), round, disc, "Cylinder", 1, 12), "past the rim")
		t.ok(
			inside(Vector3.new(5.5, 3, 5.5), round, disc, "Block", 1, 12),
			"(a square pad would count it)"
		)
		-- A ball.
		local ball = Vector3.new(8, 8, 8)
		t.ok(inside(Vector3.new(4.5, 6, 0), CFrame.new(), ball, "Ball", 1, 12), "on the ball")
		t.ok(
			not inside(Vector3.new(5.5, 2, 0), CFrame.new(), ball, "Ball", 1, 12),
			"beside the ball"
		)
	end)

	t.test("Ready pad switched off: everyone is ready (no players in tests)", function()
		local ReadyService = require(t.Server.Services.ReadyService) :: any
		t.eq(ReadyService.Needed(), math.max(1, Config.Lobby.Ready.MinReady))
		withFeatures({ ReadyPad = false }, function()
			ReadyService.Start() -- returns straight away
			t.eq(ReadyService.PadsActive(), false)
			t.eq(ReadyService.Count(), 0)
		end)
		t.eq(ReplicatedStorage:GetAttribute("ReadyNeeded"), ReadyService.Needed())
	end)

	t.test("Ready pad and spectate settings", function()
		local ready = Config.Lobby.Ready
		for _, key in { "MinReady", "CheckSeconds", "PadHeight", "EdgeMargin", "LeaveGraceSeconds" } do
			t.eq(type(ready[key]), "number", "Lobby.Ready." .. key)
		end
		for _, key in
			{ "Count", "StandOnPad", "YoureReady", "NextRound", "ReadyNextRound", "VoteHint" }
		do
			t.eq(type(ready.Text[key]), "string", "Lobby.Ready.Text." .. key)
		end
		local spectate = Config.Lobby.Spectate
		for _, list in { spectate.NextKeys, spectate.PreviousKeys } do
			t.ok(#list > 0, "at least one key")
			for _, key in list do
				t.eq(typeof(key), "EnumItem")
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
			t.eq(type(spectate.Text[key]), "string", "Lobby.Spectate.Text." .. key)
		end
		for _, key in { "CancelledSeconds", "ErrorWaitSeconds", "SafetyLimitSeconds" } do
			t.eq(type(Config.Round[key]), "number", "Round." .. key)
		end
	end)
end
