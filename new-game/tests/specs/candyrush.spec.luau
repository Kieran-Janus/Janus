-- Candy Rush (the lobby candy race): the rules (lanes, candy spots, the winner, coins), the stand
-- the hub builds, whole races on the server (two players, a forfeit, a solo run, the admin
-- test, a player leaving) and the client screen.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

describe("CandyRushRules", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Rules = rt:require("ServerScriptService.Server.Minigames.CandyRushRules")
	local Vector2 = rt.env.Vector2

	it("gives everyone one lane and lets them keep it", function()
		local lanes = Rules.AssignLanes({}, {
			{ Key = "A", Lanes = { 2 } },
			{ Key = "B", Lanes = { 2, 3 } }, -- standing between two pads: the free one
			{ Key = "C", Lanes = { 1 } },
		}, 4)
		expect(lanes[1]).toBe("C")
		expect(lanes[2]).toBe("A")
		expect(lanes[3]).toBe("B")
		expect(lanes[4]).toBeNil()
		-- A stepped off for a moment (still in the grace time): D can't take A's pad.
		local kept = Rules.AssignLanes(lanes, {
			{ Key = "D", Lanes = { 2 } },
			{ Key = "B", Lanes = { 3 } },
		}, 4, { A = true })
		expect(kept[2]).toBe("A")
		expect(kept[3]).toBe("B")
		expect(kept[1]).toBeNil() -- C left
		-- After the grace time D gets it.
		local lost = Rules.AssignLanes(lanes, { { Key = "D", Lanes = { 2 } } }, 4)
		expect(lost[2]).toBe("D")
		-- Racing lanes and lanes the stand doesn't have are never given out.
		local blocked = Rules.AssignLanes(
			{},
			{ { Key = "E", Lanes = { 1, 5 } } },
			4,
			nil,
			{ [1] = true }
		)
		expect(blocked[1]).toBeNil()
		expect(blocked[5]).toBeNil()
		-- On two pads at once: the lowest one.
		expect(Rules.AssignLanes({}, { { Key = "F", Lanes = { 3, 1 } } }, 4)[1]).toBe("F")
	end)

	it("keeps every candy inside its own lane of the board", function()
		local rng = rt.env.Random.new(7)
		for lane = 1, 4 do
			local rect = Rules.LaneRect(lane, 4, 24, 12, 2.4, 0.4, 1.8)
			local left = -12 + (lane - 1) * 6
			expect(rect.XMin).toBeGreaterThanOrEqual(left + 1.6 - 1e-6)
			expect(rect.XMax).toBeLessThanOrEqual(left + 6 - 1.6 + 1e-6)
			expect(rect.YMin).toBeGreaterThanOrEqual(-6 + 1.8 + 1.6 - 1e-6)
			expect(rect.YMax).toBeLessThanOrEqual(6 - 1.6 + 1e-6)
			local last = Vector2.new(rect.XMin, rect.YMin)
			for _ = 1, 25 do
				local spot = Rules.RandomSpot(rect, rng, last, 2.4)
				expect(spot.X >= rect.XMin and spot.X <= rect.XMax).toBe(true)
				expect(spot.Y >= rect.YMin and spot.Y <= rect.YMax).toBe(true)
				last = spot
			end
		end
		-- Lane 1 is on the left.
		expect(Rules.LaneRect(1, 4, 24, 12, 2.4, 0.4, 1.8).XMax).toBeLessThan(
			Rules.LaneRect(2, 4, 24, 12, 2.4, 0.4, 1.8).XMin
		)
		-- A lane too narrow for a candy still gives one spot in its middle.
		local tiny = Rules.LaneRect(2, 6, 6, 3, 2.4, 0.4, 1.8)
		expect(tiny.XMin).toBe(tiny.XMax)
		expect(tiny.XMin).toBeNear(-3 + 1.5, 1e-6)
		expect(tiny.YMin).toBe(tiny.YMax)
	end)

	it("decides who wins", function()
		local function runners(list)
			local out = {}
			for _, r in list do
				table.insert(out, { Key = r[1], Popped = r[2], Out = r[3] == true })
			end
			return out
		end
		local function decide(list, solo, timedOut)
			return Rules.Decide(runners(list), 10, solo, timedOut)
		end
		local who, why = decide({ { "A", 10 }, { "B", 4 } }, false, false)
		expect(who).toBe("A")
		expect(why).toBe("Finished")
		who, why = decide({ { "A", 3 }, { "B", 4 } }, false, false)
		expect(who).toBeNil()
		expect(why).toBe("Running")
		who, why = decide({ { "A", 2 }, { "B", 4, true }, { "C", 5, true } }, false, false)
		expect(who).toBe("A") -- everyone else left
		expect(why).toBe("LastStanding")
		who, why = decide({ { "A", 6 }, { "B", 4 } }, false, true)
		expect(who).toBe("A")
		expect(why).toBe("TimeUp")
		who, why = decide({ { "A", 4 }, { "B", 4 } }, false, true)
		expect(who).toBeNil()
		expect(why).toBe("Tie")
		who, why = decide({ { "A", 0 }, { "B", 0 } }, false, true)
		expect(who).toBeNil() -- nobody grabbed anything
		expect(why).toBe("Tie")
		who, why = decide({ { "A", 4, true }, { "B", 4, true } }, false, false)
		expect(why).toBe("Empty")
		who, why = decide({ { "A", 10 } }, true, false)
		expect(who).toBe("A")
		expect(why).toBe("Finished")
		who, why = decide({ { "A", 3 } }, true, false)
		expect(why).toBe("Running") -- one player is a solo run, not a "last one standing" win
		who, why = decide({ { "A", 3 } }, true, true)
		expect(who).toBeNil()
		expect(why).toBe("TimeUp")
		who, why = decide({ { "A", 3, true } }, true, false)
		expect(why).toBe("Left")
	end)

	it("pays coins only for real play, with cooldowns and a daily cap", function()
		local cfg = {
			WinCoins = 25,
			PlayCoins = 5,
			SoloCoins = 5,
			MinCandies = 3,
			CooldownSeconds = 15,
			SoloCooldownSeconds = 300,
			DailyCap = 40,
		}
		local day = 86400 * 100
		local now = day + 50
		local record = { Day = 0, CoinsToday = 0, LastReward = 0, LastSolo = 0 }
		local coins, after, note = Rules.Reward(record, "Win", 10, now, cfg)
		expect(coins).toBe(25)
		expect(note).toBeNil()
		expect(after.Day).toBe(100)
		expect(after.CoinsToday).toBe(25)
		expect(after.LastReward).toBe(now)
		expect(record.CoinsToday).toBe(0) -- the record passed in is not changed
		coins, _, note = Rules.Reward(after, "Play", 10, now + 5, cfg)
		expect(coins).toBe(0)
		expect(note).toBe("Cooldown")
		coins, _, note = Rules.Reward(after, "Play", 2, now + 20, cfg)
		expect(coins).toBe(0)
		expect(note).toBe("TooFew")
		local capped
		coins, capped, note = Rules.Reward(after, "Win", 10, now + 20, cfg)
		expect(coins).toBe(15) -- only 15 left today
		expect(note).toBe("DailyCap")
		coins, _, note = Rules.Reward(capped, "Win", 10, now + 40, cfg)
		expect(coins).toBe(0)
		expect(note).toBe("DailyCap")
		coins = Rules.Reward(capped, "Win", 10, day + 86400 + 10, cfg)
		expect(coins).toBe(25) -- a new day
		-- Solo coins have their own cooldown.
		local solo
		coins, solo = Rules.Reward(record, "Solo", 10, now, cfg)
		expect(coins).toBe(5)
		expect(solo.LastSolo).toBe(now)
		coins, _, note = Rules.Reward(solo, "Solo", 10, now + 60, cfg)
		expect(coins).toBe(0)
		expect(note).toBe("Cooldown")
		coins = Rules.Reward(solo, "Win", 10, now + 60, cfg)
		expect(coins).toBe(25)
		-- No cap at all.
		local open = table.clone(cfg)
		open.DailyCap = 0
		coins = Rules.Reward(
			{ Day = 100, CoinsToday = 9999, LastReward = 0, LastSolo = 0 },
			"Win",
			10,
			now,
			open
		)
		expect(coins).toBe(25)
	end)

	it("has complete settings in Config.Minigames.CandyRush", function()
		local cfg = Config.Minigames.CandyRush
		for _, key in
			{
				"Candies",
				"MinPlayers",
				"CountdownSeconds",
				"MaxRaceSeconds",
				"MinClickSeconds",
				"ClickDistance",
			}
		do
			expect(cfg[key]).toBeA("number")
		end
		expect(cfg.MinPlayers).toBeGreaterThanOrEqual(2)
		for _, key in
			{ "WinCoins", "PlayCoins", "SoloCoins", "MinCandies", "CooldownSeconds", "DailyCap" }
		do
			expect(cfg.Rewards[key]).toBeA("number")
		end
		expect(cfg.Rewards.SoloCoins).toBeLessThan(cfg.Rewards.WinCoins)
		expect(#cfg.Candy.Kinds).toBeGreaterThan(0)
		expect(#cfg.Stand.LaneColors).toBeGreaterThanOrEqual(6)
		for name, spec in cfg.Sounds do
			if type(spec.SoundId) ~= "string" then
				error("Sounds." .. name .. " has no SoundId")
			end
		end
		for key, value in cfg.Text do
			if type(value) ~= "string" then
				error("Text." .. key .. " is not a string")
			end
		end
	end)
end)

-- A server with just the Candy Rush stand (and DataService for coins).
local function standWorld()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	Config.Features.CandyRush = true
	local Tags = rt:require("ReplicatedStorage.Shared.Tags")
	local CollectionService = rt.game:GetService("CollectionService")
	local hub = rt:create("Model", { Name = "Hub" }, rt.workspace)
	local HubLayout = rt:require("ServerScriptService.Server.Hub.HubLayout")
	local area = rt:require("ServerScriptService.Server.Hub.Sections.CandyRush")
		.Build(hub, HubLayout.Zone("CandyRush"))
	local w = {
		rt = rt,
		Config = Config,
		Tags = Tags,
		CS = CollectionService,
		area = area,
		hub = hub,
		Vector3 = rt.env.Vector3,
		CFrame = rt.env.CFrame,
	}
	function w.pad(lane: number)
		for _, pad in CollectionService:GetTagged(Tags.CandyRushPad) do
			if pad:GetAttribute("Lane") == lane then
				return pad
			end
		end
		error("no pad for lane " .. lane)
	end
	function w.standOn(player, lane: number)
		local pad = w.pad(lane)
		player.Character:PivotTo(w.CFrame.new(pad.Position + w.Vector3.new(0, 3, 0)))
	end
	function w.walkAway(player)
		player.Character:PivotTo(w.CFrame.new(w.Vector3.new(0, 4, 40)))
	end
	function w.station()
		return CollectionService:GetTagged(Tags.CandyRushStation)[1]
	end
	function w.candyOf(player)
		local folder = w.station():FindFirstChild("Candies")
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("OwnerUserId") == player.UserId then
				return child
			end
		end
		return nil
	end
	function w.click(player, candy)
		rt:fire(candy.PrimaryPart:FindFirstChildOfClass("ClickDetector"), "MouseClick", player)
	end
	-- Waits for `player`'s next candy and clicks it (a person needs a moment to click).
	function w.pop(player)
		local candy = nil
		for _ = 1, 20 do
			rt:advance(0.25)
			candy = w.candyOf(player)
			if candy then
				break
			end
		end
		assert(candy, "no candy for " .. player.Name)
		rt:advance(0.15)
		w.click(player, candy)
		assert(candy.Parent == nil, "the click didn't pop the candy")
		return candy
	end
	function w.status()
		return w.station():FindFirstChild("ScoreboardGui", true).Status.Text
	end
	function w.lastState(player)
		local state = nil
		for _, call in rt:calls("RemoteEvent", "FireClient") do
			if call.instance.Name == "CandyRushState" and call.args[1] == player then
				state = call.args[2]
			end
		end
		return state
	end
	return w
end

describe("The Candy Rush stand", function()
	local w = standWorld()
	local Config, Tags, CS = w.Config, w.Tags, w.CS
	local Lobby = w.rt:require("ReplicatedStorage.Shared.Lobby")

	it("is a tagged station with a board and a pad per lane, inside its zone", function()
		expect(w.area.Name).toBe("CandyRush")
		local stations = CS:GetTagged(Tags.CandyRushStation)
		expect(#stations).toBe(1)
		expect(stations[1]:IsA("Model")).toBe(true)
		expect(stations[1]:IsDescendantOf(w.area)).toBe(true)
		local boards = CS:GetTagged(Tags.CandyRushBoard)
		expect(#boards).toBe(1)
		expect(boards[1]:IsDescendantOf(stations[1])).toBe(true)
		expect(Lobby.InZone(boards[1].Position, "CandyRush")).toBe(true)
		local pads = CS:GetTagged(Tags.CandyRushPad)
		expect(#pads).toBe(Config.Minigames.CandyRush.Stand.Lanes)
		local seen = {}
		for _, pad in pads do
			local lane = pad:GetAttribute("Lane")
			expect(lane).toBeA("number")
			expect(seen[lane]).toBeNil()
			seen[lane] = true
			expect(pad:IsDescendantOf(stations[1])).toBe(true)
			expect(Lobby.InZone(pad.Position, "CandyRush")).toBe(true)
		end
		local scoreboard = stations[1]:FindFirstChild("ScoreboardGui", true)
		expect(scoreboard).toBeInstanceOf("SurfaceGui")
		expect(scoreboard:FindFirstChild("Status")).toBeInstanceOf("TextLabel")
		expect(scoreboard:FindFirstChild("Record")).toBeInstanceOf("TextLabel")
		local sign = stations[1]:FindFirstChild("Lettering", true)
		expect(sign.Title.Text).toBe(Config.Minigames.CandyRush.Text.SignTitle)
		expect(sign.Subtitle.Text).toBe(Config.Minigames.CandyRush.Text.SignSubtitle)
		for _, part in w.rt:parts(w.area) do
			expect(part.Size.X > 0 and part.Size.Y > 0 and part.Size.Z > 0).toBe(true)
			expect(part.Anchored).toBe(true)
		end
		T.note(("%d parts"):format(#w.rt:parts(w.area)))
	end)

	it("puts lane 1 on the left as you face the board", function()
		local board = CS:GetTagged(Tags.CandyRushBoard)[1]
		local one, two = w.pad(1).Position, w.pad(2).Position
		local toBoard = (board.Position - one) * w.Vector3.new(1, 0, 1)
		local right = toBoard.Unit:Cross(w.Vector3.yAxis)
		expect((two - one):Dot(right)).toBeGreaterThan(0)
	end)

	it("builds an empty model with the feature off", function()
		Config.Features.CandyRush = false
		local hub = w.rt:create("Model", { Name = "OtherHub" }, w.rt.workspace)
		local HubLayout = w.rt:require("ServerScriptService.Server.Hub.HubLayout")
		local area = w.rt
			:require("ServerScriptService.Server.Hub.Sections.CandyRush")
			.Build(hub, HubLayout.Zone("CandyRush"))
		Config.Features.CandyRush = true
		expect(area.Name).toBe("CandyRush")
		expect(#area:GetChildren()).toBe(0)
	end)
end)

describe("Candy Rush races", function()
	local w = standWorld()
	local rt, Config = w.rt, w.Config
	local cfg = Config.Minigames.CandyRush
	local DataService = rt:require("ServerScriptService.Server.Services.DataService")
	local Service = rt:require("ServerScriptService.Server.Services.CandyRushService")
	local a, b

	it("starts and creates its remote", function()
		DataService.Start()
		Service.Start()
		expect(rt:find("ReplicatedStorage.Remotes.CandyRushState")).toBeInstanceOf("RemoteEvent")
		a = rt:addPlayer({ Name = "Amy" })
		b = rt:addPlayer({ Name = "Ben" })
		rt:advance(3)
		expect(a:GetAttribute("DataReady")).toBe(true)
		expect(w.status()).toBe(cfg.Text.Idle)
	end)

	it("counts down once two players stand on pads", function()
		w.standOn(a, 1)
		rt:advance(0.5)
		local state = w.lastState(a)
		expect(state.Phase).toBe("Waiting")
		expect(state.YourLane).toBe(1)
		expect(state.Needed).toBe(1)
		expect(state.SoloIn).toBeGreaterThan(0) -- alone: a solo run starts soon
		expect(w.status()).toBe(cfg.Text.SoloSoon:format(state.SoloIn))
		w.standOn(b, 2)
		rt:advance(0.5)
		expect(w.lastState(b).Phase).toBe("Countdown")
		expect(w.lastState(b).YourLane).toBe(2)
		expect(tonumber(w.status())).toBeGreaterThan(0)
		rt:advance(cfg.CountdownSeconds)
		state = w.lastState(a)
		expect(state.Phase).toBe("Live")
		expect(state.InRace).toBe(true)
		expect(state.Solo).toBe(false)
		expect(#state.Lanes).toBe(2)
		expect(w.candyOf(a)).toBeInstanceOf("Model")
		expect(w.candyOf(b)).toBeInstanceOf("Model")
	end)

	it("only lets you grab your own candy, and not instantly", function()
		rt:advance(0.3)
		local candy = w.candyOf(a)
		w.click(b, candy) -- Ben clicks Amy's candy: nothing happens
		expect(candy.Parent).never.toBeNil()
		local fresh = w.candyOf(b)
		w.click(b, fresh) -- Ben's own: popped
		expect(fresh.Parent).toBeNil()
		local next = nil
		for _ = 1, 50 do
			rt:advance(0.02)
			next = w.candyOf(b)
			if next then
				break
			end
		end
		expect(next).toBeInstanceOf("Model")
		w.click(b, next) -- the moment it appears: faster than a person can click, ignored
		expect(next.Parent).never.toBeNil()
		-- The candy is in Ben's lane, in front of the board.
		expect(next:GetAttribute("Lane")).toBe(2)
		local fromPad = (next:GetPivot().Position - w.pad(2).Position).Magnitude
		expect(fromPad).toBeLessThan(cfg.ClickDistance)
	end)

	it("takes grabs the screen spotted (CandyRushGrab) with the same checks", function()
		local grab = rt:find("ReplicatedStorage.Remotes.CandyRushGrab")
		expect(grab).toBeInstanceOf("RemoteEvent")
		rt:advance(0.3)
		local amys = w.candyOf(a)
		local bens = w.candyOf(b)
		rt:fireServer(grab, b, amys) -- someone else's candy: nothing
		expect(amys.Parent).never.toBeNil()
		rt:fireServer(grab, b, "not a candy") -- junk: nothing
		rt:fireServer(grab, b, bens) -- your own: popped
		expect(bens.Parent).toBeNil()
		rt:fireServer(grab, b, bens) -- the same candy again: nothing more
	end)

	it("pays the first to grab them all and counts the win", function()
		local coinsA = DataService.Get(a).Coins
		local coinsB = DataService.Get(b).Coins
		for _ = 1, 3 do
			w.pop(b)
		end
		for _ = 1, cfg.Candies do
			w.pop(a)
		end
		local state = w.lastState(a)
		expect(state.Phase).toBe("Results")
		expect(state.Winner.UserId).toBe(a.UserId)
		expect(state.Coins).toBe(cfg.Rewards.WinCoins)
		expect(state.Time).toBeGreaterThan(0)
		expect(DataService.Get(a).Coins).toBe(coinsA + cfg.Rewards.WinCoins)
		expect(DataService.Get(a).Minigames.CandyRushWins).toBe(1)
		expect(DataService.Get(b).Coins).toBe(coinsB + cfg.Rewards.PlayCoins)
		expect(w.lastState(b).Winner.Name).toBe(a.DisplayName)
		expect(w.status()).toBe(cfg.Text.Wins:format(a.DisplayName))
		expect(w.candyOf(a)).toBeNil()
		expect(w.candyOf(b)).toBeNil()
		T.note(("Amy finished in %.1fs"):format(state.Time))
	end)

	it("starts a rematch, and the last one on a pad wins when the other leaves", function()
		rt:advance(cfg.ResultsSeconds + cfg.CountdownSeconds + 1)
		expect(w.lastState(a).Phase).toBe("Live")
		for _ = 1, 3 do
			w.pop(a)
		end
		w.walkAway(b)
		rt:advance(cfg.LeaveGraceSeconds + 1)
		local state = w.lastState(a)
		expect(state.Phase).toBe("Results")
		expect(state.Winner.UserId).toBe(a.UserId)
		expect(state.Reason).toBe("LastStanding")
		expect(state.Note).toBe("Cooldown") -- won again too soon for more coins
		expect(state.Coins).toBe(0)
		expect(w.lastState(b).Out).toBe(true)
		expect(DataService.Get(a).Minigames.CandyRushWins).toBe(2)
	end)

	it("runs a solo race against the clock for someone alone", function()
		rt:advance(cfg.ResultsSeconds + 1)
		expect(w.lastState(b)).toBeNil() -- Ben walked away: his screen is hidden
		expect(w.lastState(a).Phase).toBe("Waiting")
		expect(w.lastState(a).SoloIn).toBeGreaterThan(0)
		rt:advance(cfg.Solo.AfterSeconds + cfg.CountdownSeconds + 0.5)
		local state = w.lastState(a)
		expect(state.Phase).toBe("Live")
		expect(state.Solo).toBe(true)
		local coins = DataService.Get(a).Coins
		for _ = 1, cfg.Candies do
			w.pop(a)
		end
		state = w.lastState(a)
		expect(state.Phase).toBe("Results")
		expect(state.Winner.UserId).toBe(a.UserId)
		expect(state.NewBest).toBe(true)
		expect(state.Best).toBeGreaterThan(0)
		expect(DataService.Get(a).Minigames.CandyRushBest).toBe(state.Best)
		expect(DataService.Get(a).Coins).toBe(coins + cfg.Rewards.SoloCoins)
		expect(DataService.Get(a).Minigames.CandyRushWins).toBe(2) -- solo runs aren't wins
	end)

	it("doesn't start again for someone who never clicks", function()
		rt:advance(cfg.ResultsSeconds + cfg.Solo.AfterSeconds + cfg.CountdownSeconds + 1)
		expect(w.lastState(a).Phase).toBe("Live")
		rt:advance(cfg.MaxRaceSeconds + 1)
		expect(w.lastState(a).Reason).toBe("TimeUp")
		rt:advance(cfg.ResultsSeconds + cfg.Solo.AfterSeconds + cfg.CountdownSeconds + 2)
		expect(w.lastState(a)).toBeNil() -- benched until Amy steps off the pad
		w.walkAway(a)
		rt:advance(1)
		w.standOn(a, 3)
		rt:advance(1)
		expect(w.lastState(a).YourLane).toBe(3)
	end)

	it("starts a solo test from the admin command", function()
		w.walkAway(a)
		rt:advance(2)
		local ok, message = Service.StartSolo(b)
		expect(ok).toBe(true)
		expect(message).toBeA("string")
		rt:advance(0.5)
		local state = w.lastState(b)
		expect(state.Phase).toBe("Countdown")
		expect(state.Solo).toBe(true)
		rt:advance(cfg.CountdownSeconds + 0.5)
		expect(w.lastState(b).Phase).toBe("Live")
		expect(w.candyOf(b)).toBeInstanceOf("Model")
	end)

	it("cleans up when a player leaves in the middle of a race", function()
		rt:removePlayer(b)
		rt:advance(1)
		expect(#w.station().Candies:GetChildren()).toBe(0)
		rt:advance(cfg.ResultsSeconds + 1)
		expect(w.status()).toBe(cfg.Text.Idle)
		expect(#rt.errors).toBe(0)
	end)
end)

describe("The Candy Rush screen", function()
	local client = Runtime.new({ client = true })
	local Config = client:require("ReplicatedStorage.Shared.Config")
	Config.Features.CandyRush = true
	local cfg = Config.Minigames.CandyRush
	local me = client.game:GetService("Players").LocalPlayer
	local remotes =
		client:create("Folder", { Name = "Remotes" }, client.game:GetService("ReplicatedStorage"))
	local remote = client:create("RemoteEvent", { Name = "CandyRushState" }, remotes)
	local gui = client:create("ScreenGui", { Name = "GameUI" }, me:WaitForChild("PlayerGui"))
	local Color3 = client.env.Color3

	local function lanes(popped: number)
		return {
			{
				Lane = 1,
				UserId = me.UserId,
				Name = me.DisplayName,
				Popped = popped,
				Out = false,
				Color = Color3.new(1, 0, 1),
			},
			{
				Lane = 2,
				UserId = 999,
				Name = "Ben",
				Popped = 2,
				Out = false,
				Color = Color3.new(0, 1, 0),
			},
		}
	end

	it("mounts hidden and shows the race while you are on a pad", function()
		client:require("StarterPlayer.StarterPlayerScripts.Client.CandyRushUI").Mount(gui)
		client:advance(1)
		local panel = gui:FindFirstChild("CandyRush")
		expect(panel).toBeInstanceOf("Frame")
		expect(panel.Visible).toBe(false)
		client:fire(remote, "OnClientEvent", {
			Phase = "Countdown",
			Count = 3,
			Total = 10,
			Solo = false,
			Lanes = lanes(0),
			Needed = 0,
			InRace = false,
			YourLane = 1,
		})
		expect(panel.Visible).toBe(true)
		expect(gui.CandyRushCountdown.Visible).toBe(true)
		expect(gui.CandyRushCountdown.Text).toBe("3")
		client:fire(remote, "OnClientEvent", {
			Phase = "Live",
			Total = 10,
			Solo = false,
			Lanes = lanes(7),
			Needed = 0,
			InRace = true,
			YourLane = 1,
			StartedAt = 0,
		})
		expect(panel.YourCandies.Text).toBe("7/10")
		expect(panel.Lanes.Lane1.PlayerName.Text).toBe(cfg.Text.You)
		expect(panel.Lanes.Lane2.PlayerName.Text).toBe("Ben")
		expect(gui.CandyRushCountdown.Text).toBe(cfg.Text.Go)
	end)

	it("shows the winner banner, then hides when you leave", function()
		client:fire(remote, "OnClientEvent", {
			Phase = "Results",
			Total = 10,
			Solo = false,
			Lanes = lanes(10),
			Needed = 0,
			InRace = true,
			YourLane = 1,
			Winner = { UserId = me.UserId, Name = me.DisplayName },
			Reason = "Finished",
			Coins = 25,
			Time = 8.4,
		})
		expect(gui.CandyRushBanner.Visible).toBe(true)
		expect(gui.CandyRushBanner.Title.Text).toBe(cfg.Text.YouWin)
		expect(gui.CandyRushBanner.Details.Text).toMatch("25")
		client:fire(remote, "OnClientEvent", nil)
		expect(gui.CandyRush.Visible).toBe(false)
	end)

	it("bounces candies in and outlines yours", function()
		local station = client:create("Model", { Name = "CandyStand" }, client.workspace)
		client.game:GetService("CollectionService"):AddTag(station, "CandyRushStation")
		local folder = client:create("Folder", { Name = "Candies" }, station)
		client:advance(0.1)
		local candy = client:create("Model", { Name = "Candy_Lane1" })
		local part = client:create(
			"Part",
			{ Name = "Hitbox", Size = client.env.Vector3.new(2, 2, 1) },
			candy
		)
		candy.PrimaryPart = part
		candy:SetAttribute("Lane", 1)
		candy:SetAttribute("OwnerUserId", me.UserId)
		candy.Parent = folder
		client:advance(0.05)
		expect(candy:FindFirstChildOfClass("Highlight")).toBeInstanceOf("Highlight")
		expect(part.Size.X).toBeLessThan(2) -- growing
		client:advance(1)
		expect(part.Size.X).toBeNear(2, 1e-3)
		expect(#client.errors).toBe(0)
	end)
end)
