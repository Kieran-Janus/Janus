-- Web Scour (Config.Minigames.WebScour): the maths in src/shared/WebScourRules.luau, the
-- Spider Grove section, and whole hunts against the real WebScourService (start at the
-- lantern, catch critters, rejected catches, coins, best time, cooldowns, two hunters).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rules = Runtime.new()
local Vector3 = rules.env.Vector3
local Config = rules:require("ReplicatedStorage.Shared.Config")
local WebScourRules = rules:require("ReplicatedStorage.Shared.WebScourRules")
local cfg = Config.Minigames.WebScour

describe("WebScourRules", function()
	it("picks different spots, never more than there are", function()
		local rng = rules.env.Random.new(4)
		local picked = WebScourRules.PickSpots(16, 6, rng)
		expect(#picked).toBe(6)
		local seen = {}
		for _, index in picked do
			expect(index).toBeGreaterThanOrEqual(1)
			expect(index).toBeLessThanOrEqual(16)
			expect(seen[index]).toBeNil()
			seen[index] = true
		end
		expect(#WebScourRules.PickSpots(3, 6, rng)).toBe(3)
		expect(#WebScourRules.PickSpots(0, 6, rng)).toBe(0)
	end)

	it("pays per critter, plus the finish and time bonus only when all are found", function()
		local c = { CoinsPerCritter = 2, FinishCoins = 20, TimeBonusPerSecond = 0.5, MaxCoins = 50 }
		expect(WebScourRules.Coins(c, 0, 6, 30)).toBe(0)
		expect(WebScourRules.Coins(c, 4, 6, 30)).toBe(8) -- no bonus without all of them
		expect(WebScourRules.Coins(c, 6, 6, 10)).toBe(12 + 20 + 5)
		expect(WebScourRules.Coins(c, 6, 6, 400)).toBe(50) -- capped
		expect(WebScourRules.Coins(c, 9, 6, 0)).toBe(32) -- never more critters than there were
		expect(WebScourRules.Coins(cfg, cfg.Critters, cfg.Critters, cfg.TimeLimit)).toBeLessThanOrEqual(
			cfg.MaxCoins
		)
	end)

	it("only counts honest catches", function()
		local base = {
			Now = 10,
			Started = 5,
			Deadline = 50,
			LastFind = 9,
			AlreadyFound = false,
			Distance = 10,
		}
		local function with(changes: { [string]: any }): any
			local check = table.clone(base)
			for k, v in changes do
				check[k] = v
			end
			return WebScourRules.CheckFind(check, cfg)
		end
		expect(with({})).toBeNil()
		expect(with({ Now = 51 })).toBe("Over")
		expect(with({ AlreadyFound = true })).toBe("Found")
		expect(with({ Now = 5.1, LastFind = nil })).toBe("TooSoon")
		expect(with({ LastFind = 9.95 })).toBe("TooFast")
		expect(with({ Distance = cfg.MaxReach + 1 })).toBe("TooFar")
		expect(with({ Distance = 0 / 0 })).toBe("TooFar")
	end)

	it("turns clock hours into points and times into text", function()
		local x, y = WebScourRules.ClockPoint(12, 2)
		expect(x).toBeNear(0)
		expect(y).toBeNear(2)
		x, y = WebScourRules.ClockPoint(3, 2)
		expect(x).toBeNear(2)
		expect(y).toBeNear(0)
		expect(WebScourRules.FormatTime(23.44)).toBe("23.4s")
		expect(WebScourRules.FormatTime(65.25)).toBe("1:05.2")
		expect(WebScourRules.FormatWait(42)).toBe("42s")
		expect(WebScourRules.FormatWait(125)).toBe("2m 05s")
	end)
end)

describe("Config.Minigames.WebScour", function()
	it("has sensible numbers and every text line", function()
		expect(cfg.Critters).toBeGreaterThanOrEqual(1)
		expect(cfg.TimeLimit).toBeGreaterThan(5)
		expect(cfg.MaxReach).toBeGreaterThan(cfg.CatchPromptDistance)
		expect(cfg.RewardCooldown).toBeGreaterThanOrEqual(0)
		for _, kind in cfg.CritterKinds do
			expect(cfg.CritterColors[kind]).toBeTruthy()
		end
		for _, key in { "Start", "Catch", "Miss", "Tick", "AllFound", "TimeUp" } do
			expect((cfg.Sounds :: any)[key].SoundId).toBeA("string")
		end
		expect(cfg.Text.Progress:format(4, 6)).toBe("4/6 found")
		for _, web in cfg.Grove.Webs do
			expect(cfg.Grove.Trees[web.Between[1]]).toBeTruthy()
			expect(cfg.Grove.Trees[web.Between[2]]).toBeTruthy()
		end
	end)
end)

describe("Spider Grove (Sections/WebScour)", function()
	local rt = Runtime.new()
	local Lobby = rt:require("ReplicatedStorage.Shared.Lobby")
	local HubLayout = rt:require("ServerScriptService.Server.Hub.HubLayout")
	local Section = rt:require("ServerScriptService.Server.Hub.Sections.WebScour")
	local CollectionService = rt.game:GetService("CollectionService")
	local C = rt:require("ReplicatedStorage.Shared.Config")

	it("builds the grove inside its zone with a lantern and 12-20 hiding spots", function()
		local hub = rt:create("Model", { Name = "Hub" }, rt.workspace)
		local area = Section.Build(hub, HubLayout.Zone("WebScour"))
		expect(area.Name).toBe("WebScour")
		local starts = CollectionService:GetTagged("WebScourStart")
		expect(#starts).toBe(1)
		expect(starts[1]:FindFirstChildOfClass("ProximityPrompt").ActionText).toBe(
			C.Minigames.WebScour.Prompt.ActionText
		)
		local spots = CollectionService:GetTagged("WebScourSpot")
		expect(#spots).toBeGreaterThanOrEqual(12)
		expect(#spots).toBeLessThanOrEqual(20)
		for _, spot in spots do
			expect(spot.Transparency).toBe(1)
			expect(spot.CanCollide).toBe(false)
			expect(Lobby.InZone(spot.Position, "WebScour", 1)).toBe(true)
			expect(spot.Position.Y).toBeGreaterThan(Lobby.GroundY())
			expect(spot.Position.Y).toBeLessThan(Lobby.GroundY() + 20)
		end
		local parts = rt:parts(area)
		for _, part in parts do
			expect(part.Size.X).toBeFinite()
			expect(part.Size.Y).toBeGreaterThan(0)
		end
		expect(area:FindFirstChild("GroveSpider", true)).toBeTruthy()
		expect(#area:FindFirstChild("Webs"):GetChildren()).toBeGreaterThanOrEqual(3)
		T.note(("%d parts, %d hiding spots"):format(#parts, #spots))
		area:Destroy()
	end)

	it("builds only an empty model while switched off", function()
		local hub = rt:create("Model", { Name = "Hub2" }, rt.workspace)
		C.Features.WebScour = false
		local ok, area = pcall(Section.Build, hub, HubLayout.Zone("WebScour"))
		C.Features.WebScour = true
		expect(ok).toBe(true)
		expect(#area:GetChildren()).toBe(0)
	end)
end)

-- A server with the hub, saves, the shop and Web Scour running.
local function server()
	local rt = Runtime.new({ studio = true })
	local services = "ServerScriptService.Server.Services."
	for _, name in { "HubService", "DataService", "ShopService", "AdminService", "WebScourService" } do
		rt:require(services .. name).Start()
	end
	return rt
end

-- The WebScourRun messages sent to `player` so far.
local function messages(rt: any, player: any): { any }
	local out = {}
	for _, call in rt:calls("RemoteEvent", "FireClient") do
		if call.instance.Name == "WebScourRun" and call.args[1] == player then
			table.insert(out, call.args[2])
		end
	end
	return out
end

local function last(rt: any, player: any, op: string): any
	local list = messages(rt, player)
	for i = #list, 1, -1 do
		if list[i].Op == op then
			return list[i]
		end
	end
	return nil
end

local function lantern(rt: any): any
	return rt.game:GetService("CollectionService"):GetTagged("WebScourStart")[1]
end

-- Puts the player on the ground in front of the lantern.
local function toLantern(rt: any, player: any)
	local look = lantern(rt).CFrame.LookVector
	local spot = lantern(rt).Position + look * 3 - rt.env.Vector3.new(0, 3.5, 0)
	player.Character:PivotTo(rt.env.CFrame.new(spot))
end

-- Uses the lantern's button (standing next to it).
local function press(rt: any, player: any)
	toLantern(rt, player)
	rt:triggerPrompt(lantern(rt):FindFirstChildOfClass("ProximityPrompt"), player)
end

-- A player standing in front of the lantern, save loaded.
local function hunter(rt: any, name: string): any
	local player = rt:addPlayer({ Name = name })
	rt:advance(1)
	toLantern(rt, player)
	return player
end

local function catch(rt: any, player: any, runId: number, id: number)
	rt:fireServer(rt:find("ReplicatedStorage.Remotes.WebScourAction"), player, "Catch", runId, id)
	rt:flush()
end

describe("WebScourService", function()
	it("plays a whole hunt: start, rejected catches, all found, coins and best time", function()
		local rt = server()
		local player = hunter(rt, "Hunter")
		local prompt = lantern(rt):FindFirstChildOfClass("ProximityPrompt")
		expect(prompt).toBeTruthy()
		press(rt, player)
		local start = last(rt, player, "Start")
		expect(start).toBeTruthy()
		expect(#start.Critters).toBe(cfg.Critters)
		expect(start.TimeLimit).toBe(cfg.TimeLimit)
		local data = rt:require("ServerScriptService.Server.Services.DataService").Get(player)
		local coinsBefore = data.Coins

		-- Too soon after the start, then a made-up critter and a wrong hunt number: ignored.
		catch(rt, player, start.RunId, 1)
		expect(last(rt, player, "Miss").Reason).toBe("TooSoon")
		rt:advance(1)
		catch(rt, player, start.RunId, 99)
		catch(rt, player, start.RunId + 5, 1)
		expect(last(rt, player, "Found")).toBeNil()

		-- Too far away: the client hears so and the critter stays.
		local character = player.Character
		local home = character:GetPivot()
		character:PivotTo(home + rt.env.Vector3.new(0, 0, 0) + lantern(rt).CFrame.LookVector * 60)
		catch(rt, player, start.RunId, 1)
		expect(last(rt, player, "Miss").Reason).toBe("TooFar")
		character:PivotTo(home)

		-- Walk up to each critter and catch them all (not too fast).
		for id = 1, #start.Critters do
			rt:advance(0.5)
			character:PivotTo(
				rt.env.CFrame.new(start.Critters[id].Position + rt.env.Vector3.new(0, 0, 4))
			)
			catch(rt, player, start.RunId, id)
			if id == 1 then
				catch(rt, player, start.RunId, 2) -- right after: too fast
				expect(last(rt, player, "Miss").Reason).toBe("TooFast")
				catch(rt, player, start.RunId, 1) -- caught already: ignored
			end
		end
		local finish = last(rt, player, "End")
		expect(finish.Reason).toBe("AllFound")
		expect(finish.Found).toBe(cfg.Critters)
		expect(finish.Coins).toBeGreaterThan(cfg.FinishCoins)
		expect(data.Coins).toBe(coinsBefore + finish.Coins)
		expect(finish.NewBest).toBe(true)
		expect(data.Minigames.WebScourBest).toBeGreaterThan(0)
		expect(data.Minigames.WebScourBest).toBeLessThan(cfg.TimeLimit)

		-- Straight away again: a short breather first.
		local count = #messages(rt, player)
		press(rt, player)
		expect(last(rt, player, "Note").Text).toBe(cfg.Text.Wait)
		expect(#messages(rt, player)).toBe(count + 1)

		-- After the breather it starts, but pays nothing until RewardCooldown is over.
		rt:advance(cfg.StartCooldown + 0.5)
		press(rt, player)
		local second = last(rt, player, "Start")
		expect(second.RunId).toBe(start.RunId + 1)
		expect(second.CooldownLeft).toBeGreaterThan(0)
		for id = 1, #second.Critters do
			rt:advance(0.5)
			character:PivotTo(rt.env.CFrame.new(second.Critters[id].Position))
			catch(rt, player, second.RunId, id)
		end
		local again = last(rt, player, "End")
		expect(again.RunId).toBe(second.RunId)
		expect(again.Coins).toBe(0)
		expect(again.CooldownLeft).toBeGreaterThan(0)
		expect(data.Coins).toBe(coinsBefore + finish.Coins)
	end)

	it(
		"pays the critters found when time runs out, and stops hunts on Stop, leaving or a round",
		function()
			local rt = server()
			local player = hunter(rt, "Slowpoke")
			press(rt, player)
			local start = last(rt, player, "Start")
			for id = 1, 2 do
				rt:advance(1)
				player.Character:PivotTo(rt.env.CFrame.new(start.Critters[id].Position))
				catch(rt, player, start.RunId, id)
			end
			rt:advance(cfg.TimeLimit)
			local ended = last(rt, player, "End")
			expect(ended.Reason).toBe("TimeUp")
			expect(ended.Found).toBe(2)
			expect(ended.Coins).toBe(2 * cfg.CoinsPerCritter)
			expect(ended.NewBest).toBe(false)

			-- Stop button.
			rt:advance(cfg.StartCooldown + 1)
			press(rt, player)
			local second = last(rt, player, "Start")
			rt:fireServer(
				rt:find("ReplicatedStorage.Remotes.WebScourAction"),
				player,
				"Stop",
				second.RunId
			)
			rt:flush()
			expect(last(rt, player, "End").Reason).toBe("Stopped")
			expect(last(rt, player, "End").Coins).toBe(0)

			-- Joining a round.
			rt:advance(cfg.StartCooldown + 1)
			press(rt, player)
			player:SetAttribute("InRound", true)
			rt:advance(cfg.CheckSeconds * 2 + 0.1)
			expect(last(rt, player, "End").Reason).toBe("Round")
			press(rt, player)
			expect(last(rt, player, "Note").Text).toBe(cfg.Text.InRound)
			player:SetAttribute("InRound", nil)

			-- Walking away from the grove.
			rt:advance(cfg.StartCooldown + 1)
			press(rt, player)
			player.Character:PivotTo(
				player.Character:GetPivot() + rt.env.Vector3.new(cfg.LeaveDistance + 20, 0, 0)
			)
			rt:advance(cfg.CheckSeconds * 2 + 0.1)
			expect(last(rt, player, "End").Reason).toBe("Left")
			expect(#rt.errors).toBe(0)
		end
	)

	it("saves the coin cooldown, so joining another server doesn't skip it", function()
		-- Server 1: a paying hunt saves when the coins were paid.
		local rt = server()
		local player = hunter(rt, "Hopper")
		local data = rt:require("ServerScriptService.Server.Services.DataService").Get(player)
		press(rt, player)
		local start = last(rt, player, "Start")
		expect(start.CooldownLeft).toBe(0)
		for id = 1, #start.Critters do
			rt:advance(0.5)
			player.Character:PivotTo(rt.env.CFrame.new(start.Critters[id].Position))
			catch(rt, player, start.RunId, id)
		end
		expect(last(rt, player, "End").Coins).toBeGreaterThan(0)
		local paidAt = data.Minigames.WebScourLastReward
		expect(paidAt).toBeGreaterThan(0)
		expect(paidAt).toBeLessThanOrEqual(rt.env.os.time())

		-- Server 2 (a different server: nothing in its memory), same save, 30 s later.
		local other = server()
		local again = hunter(other, "Hopper")
		local saved = other:require("ServerScriptService.Server.Services.DataService").Get(again)
		saved.Minigames.WebScourLastReward = other.env.os.time() - 30
		local coins = saved.Coins
		press(other, again)
		local second = last(other, again, "Start")
		expect(second.CooldownLeft).toBeNear(cfg.RewardCooldown - 30, 1)
		for id = 1, #second.Critters do
			other:advance(0.5)
			again.Character:PivotTo(other.env.CFrame.new(second.Critters[id].Position))
			catch(other, again, second.RunId, id)
		end
		local ended = last(other, again, "End")
		expect(ended.Reason).toBe("AllFound")
		expect(ended.Coins).toBe(0)
		expect(ended.CooldownLeft).toBeGreaterThan(0)
		expect(saved.Coins).toBe(coins)

		-- A save stamped by a server whose clock ran ahead never waits longer than the cooldown.
		saved.Minigames.WebScourLastReward = other.env.os.time() + 100000
		other:advance(cfg.StartCooldown + 1)
		press(other, again)
		local third = last(other, again, "Start")
		expect(third.RunId).toBe(second.RunId + 1)
		expect(third.CooldownLeft).toBeLessThanOrEqual(cfg.RewardCooldown)

		-- Once the cooldown is over, hunts pay again.
		other:fireServer(
			other:find("ReplicatedStorage.Remotes.WebScourAction"),
			again,
			"Stop",
			third.RunId
		)
		other:flush()
		saved.Minigames.WebScourLastReward = other.env.os.time() - cfg.RewardCooldown - 1
		other:advance(cfg.StartCooldown + 1)
		press(other, again)
		expect(last(other, again, "Start").CooldownLeft).toBe(0)
		expect(#rt.errors + #other.errors).toBe(0)
	end)

	it(
		"lets two players hunt at once, each with their own critters, and cleans up leavers",
		function()
			local rt = server()
			local a = hunter(rt, "Ann")
			local b = hunter(rt, "Bob")
			press(rt, a)
			press(rt, b)
			local startA, startB = last(rt, a, "Start"), last(rt, b, "Start")
			expect(startA).toBeTruthy()
			expect(startB).toBeTruthy()
			rt:advance(1)
			a.Character:PivotTo(rt.env.CFrame.new(startA.Critters[1].Position))
			catch(rt, a, startA.RunId, 1)
			expect(last(rt, a, "Found").Found).toBe(1)
			expect(last(rt, b, "Found")).toBeNil()
			-- Bob can't catch with Ann's hunt number for a hunt he doesn't have.
			rt:removePlayer(b)
			rt:advance(cfg.TimeLimit + 1)
			expect(last(rt, a, "End").Reason).toBe("TimeUp")
			expect(#rt.errors).toBe(0)
		end
	)

	it("can be started from the F8 admin panel, and does nothing while switched off", function()
		local rt = server()
		local player = rt:addPlayer({ Name = "Owner" })
		rt:advance(1)
		local ok, message = rt:invokeServer(
			rt:find("ReplicatedStorage.Remotes.AdminCommand"),
			player,
			"WebScourStart"
		)
		expect(ok).toBe(true)
		expect(message).toMatch("Hunt started")
		expect(last(rt, player, "Start")).toBeTruthy()

		local off = Runtime.new()
		local C = off:require("ReplicatedStorage.Shared.Config")
		C.Features.WebScour = false
		off:require("ServerScriptService.Server.Services.HubService").Start()
		off:require("ServerScriptService.Server.Services.WebScourService").Start()
		expect(off:find("ReplicatedStorage.Remotes.WebScourRun")).toBeTruthy()
		expect(off:find("ReplicatedStorage.Remotes.WebScourAction")).toBeTruthy()
		expect(#off.game:GetService("CollectionService"):GetTagged("WebScourStart")).toBe(0)
	end)
end)

describe("WebScourUI", function()
	it("shows only your critters, catches one, and shows the finish banner", function()
		local srv = server()
		local client = Runtime.new({ client = true })
		client:replicateFrom(srv)
		local player = client.game:GetService("Players").LocalPlayer
		local gui = client:create("ScreenGui", { Name = "GameUI" }, player.PlayerGui)
		client:require("StarterPlayer.StarterPlayerScripts.Client.WebScourUI").Mount(gui)
		client:advance(0.5)
		local run = client:find("ReplicatedStorage.Remotes.WebScourRun")
		local V3 = client.env.Vector3
		local root = player.Character:GetPivot().Position
		local list = {}
		for i = 1, 3 do
			local kind = cfg.CritterKinds[(i - 1) % #cfg.CritterKinds + 1]
			table.insert(list, { Id = i, Position = root + V3.new(i * 3, 2, 0), Kind = kind })
		end
		client:fire(run, "OnClientEvent", {
			Op = "Start",
			RunId = 1,
			TimeLimit = cfg.TimeLimit,
			Critters = list,
			Best = 0,
			CooldownLeft = 0,
		})
		client:advance(0.2)
		local folder = client.workspace:FindFirstChild("WebScourCritters")
		expect(folder).toBeTruthy()
		expect(#folder:GetChildren()).toBe(3)
		expect(gui.WebScour.Visible).toBe(true)
		expect(gui.WebScour.Progress.Text).toBe("0/3 found")

		-- The "Catch!" button on critter 2 asks the server.
		local second = folder:FindFirstChild(list[2].Kind .. "2")
		client:triggerPrompt(second.Hitbox:FindFirstChildOfClass("ProximityPrompt"), player)
		local sent = client:calls("RemoteEvent", "FireServer")
		local args = sent[#sent].args
		expect(args[1]).toBe("Catch")
		expect(args[2]).toBe(1)
		expect(args[3]).toBe(2)
		client:fire(run, "OnClientEvent", { Op = "Found", RunId = 1, Id = 2, Found = 1, Total = 3 })
		expect(gui.WebScour.Progress.Text).toBe("1/3 found")

		client:fire(run, "OnClientEvent", {
			Op = "End",
			RunId = 1,
			Reason = "TimeUp",
			Found = 1,
			Total = 3,
			Coins = 2,
			Best = 0,
			NewBest = false,
			CooldownLeft = 0,
		})
		client:advance(0.2)
		expect(gui.WebScour.Visible).toBe(false)
		expect(gui.WebScourBanner.Visible).toBe(true)
		expect(gui.WebScourBanner.Title.Text).toBe(cfg.Text.TimeUp)
		expect(gui.WebScourBanner.Coins.Text).toMatch("%+2")
		client:advance(cfg.BannerSeconds + 2)
		expect(gui.WebScourBanner.Visible).toBe(false)
		expect(client.workspace:FindFirstChild("WebScourCritters")).toBeNil()
		expect(#client.errors).toBe(0)
	end)
end)
