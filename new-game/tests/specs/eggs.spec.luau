-- Easter eggs (Config.EasterEggs): the rules in src/shared/EasterEggRules.luau, the egg list,
-- placing eggs next to their anchors in the built hub (Sections/EasterEggs), collecting them
-- through the real EasterEggService (button, touch, distance, rounds, once only, coins, the
-- toast, the admin reset) and EasterEggUI (hidden once found, toast, list panel).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local base = Runtime.new()
local Config = base:require("ReplicatedStorage.Shared.Config")
local EasterEggRules = base:require("ReplicatedStorage.Shared.EasterEggRules")
local cfg = Config.EasterEggs

describe("EasterEggRules", function()
	it("turns id lists into attribute text and back", function()
		expect(EasterEggRules.JoinIds({ "A", "B" })).toBe("A,B")
		expect(EasterEggRules.ParseIds("A,B")).toEqual({ "A", "B" })
		expect(EasterEggRules.ParseIds(nil)).toEqual({})
		expect(EasterEggRules.ParseIds("")).toEqual({})
	end)

	it("counts found eggs among the ones in the game", function()
		local found, total = EasterEggRules.Count({ A = true, Z = true }, { "A", "B", "C" })
		expect(found).toBe(1)
		expect(total).toBe(3)
		-- Before the server says which eggs are in the game: the whole Config list.
		found, total = EasterEggRules.Count({}, nil)
		expect(found).toBe(0)
		expect(total).toBe(#cfg.List)
	end)

	it("makes Coins attributes safe", function()
		expect(EasterEggRules.Coins(50, 500)).toBe(50)
		expect(EasterEggRules.Coins(12.7, 500)).toBe(12)
		expect(EasterEggRules.Coins(-5, 500)).toBe(0)
		expect(EasterEggRules.Coins(1e9, 500)).toBe(500)
		expect(EasterEggRules.Coins("lots", 500)).toBe(0)
		expect(EasterEggRules.Coins(0 / 0, 500)).toBe(0)
	end)

	it("only counts honest grabs", function()
		local ok = { AlreadyFound = false, InRound = false, SinceLastTry = math.huge, Distance = 3 }
		local function with(changes: { [string]: any }): any
			local check = table.clone(ok)
			for k, v in changes do
				check[k] = v
			end
			return EasterEggRules.CheckCollect(check, cfg)
		end
		expect(with({})).toBeNil()
		expect(with({ AlreadyFound = true })).toBe("Found")
		expect(with({ InRound = true })).toBe("InRound")
		expect(with({ SinceLastTry = 0 })).toBe("TooFast")
		expect(with({ Distance = cfg.ReachDistance + 1 })).toBe("TooFar")
		expect(with({ Teleported = true })).toBe("Teleported")
	end)
end)

describe("Config.EasterEggs", function()
	it(
		"lists about ten eggs with unique ids, fair coins, a look, an anchor and a riddle",
		function()
			expect(#cfg.List).toBeGreaterThanOrEqual(8)
			expect(#cfg.List).toBeLessThanOrEqual(14)
			local seen = {}
			for _, egg in cfg.List do
				expect(egg.Id).toMatch("^%w+$") -- letters and digits: saved, and kept in attributes
				expect(seen[egg.Id]).toBeNil()
				seen[egg.Id] = true
				expect(egg.Name).toBeA("string")
				expect(egg.Coins).toBeGreaterThanOrEqual(25)
				expect(egg.Coins).toBeLessThanOrEqual(100)
				expect(egg.Hint).toBeA("string")
				expect(#egg.Hint).toBeGreaterThan(10)
				expect(egg.Anchor).toBeA("string")
				expect(typeof(egg.Offset)).toBe("Vector3")
				expect(cfg.Icons[egg.Look or "GoldenPumpkin"]).toBeA("string")
			end
			-- The first one: a golden pumpkin behind the Pumpkin Shop, worth 50.
			local shop = EasterEggRules.Def("ShopPumpkin")
			expect(shop.Coins).toBe(50)
			expect(shop.Anchor).toBe("Shop")
			expect(cfg.Text.Toast:format(50, "Coins", 3, 10)).toBe(
				"Easter egg found! +50 Coins (3/10)"
			)
		end
	)
end)

-- Every egg part (tagged EasterEgg) under `root`, by EggId.
local function eggsIn(rt: any, root: any): { [string]: any }
	local out = {}
	for _, part in rt.game:GetService("CollectionService"):GetTagged("EasterEgg") do
		if part:IsDescendantOf(root) then
			out[part:GetAttribute("EggId")] = part
		end
	end
	return out
end

describe("Sections/EasterEggs", function()
	local rt = Runtime.new()
	local C = rt:require("ReplicatedStorage.Shared.Config")
	local Lobby = rt:require("ReplicatedStorage.Shared.Lobby")
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
	local Section = rt:require("ServerScriptService.Server.Hub.Sections.EasterEggs")

	it("hides every egg next to its anchor once the hub is built", function()
		local hub = HubBuilder.Build()
		rt:flush()
		local eggs = eggsIn(rt, hub.EasterEggs)
		local placed = 0
		for _, egg in C.EasterEggs.List do
			local part = eggs[egg.Id]
			if Section.Anchor(hub, egg.Anchor) == nil then
				expect(part).toBeNil() -- e.g. ParkourFinish while the parkour is off
				T.note(egg.Id .. " left out: no " .. egg.Anchor .. " in this hub")
				continue
			end
			expect(part).toBeTruthy()
			placed += 1
			expect(part:GetAttribute("Coins")).toBe(egg.Coins)
			expect(part.Parent.Name).toBe(egg.Name)
			expect(part.Parent.PrimaryPart).toBe(part)
			expect(part:FindFirstChildOfClass("ProximityPrompt")).toBeTruthy()
			expect(part.CanTouch).toBe(C.EasterEggs.TouchToCollect)
			expect(part.CanCollide).toBe(false)
			-- Close to where it was asked to be (it may step aside up to 4 studs).
			local anchor = Section.Anchor(hub, egg.Anchor)
			local wanted = (anchor * rt.env.CFrame.new(egg.Offset)).Position
			local flat =
				rt.env.Vector3.new(part.Position.X - wanted.X, 0, part.Position.Z - wanted.Z)
			expect(flat.Magnitude).toBeLessThanOrEqual(4.5)
		end
		expect(placed).toBeGreaterThanOrEqual(8)
		-- The golden pumpkin behind the shop, inside the shop's corner of the lobby.
		local shop = eggs.ShopPumpkin
		expect(Lobby.InZone(shop.Position, "Shop", 1)).toBe(true)
		local toCentre = rt.env.Vector3.new(-shop.Position.X, 0, -shop.Position.Z).Magnitude
		local shopCentre = Lobby.ZoneCFrame("Shop").Position
		expect(toCentre).toBeGreaterThan(
			rt.env.Vector3.new(shopCentre.X, 0, shopCentre.Z).Magnitude
		)
		T.note(("%d eggs placed"):format(placed))
	end)

	it("puts back only the eggs that are missing", function()
		local hub = HubBuilder.Build()
		rt:flush()
		local eggs = eggsIn(rt, hub)
		local before = eggs.GraveCandy.Position
		eggs.GraveCandy.Parent:Destroy()
		expect(Section.PlaceMissing(hub)).toEqual({ "GraveCandy" })
		expect(eggsIn(rt, hub).GraveCandy.Position).toBeNear(before, 1e-3)
		expect(Section.PlaceMissing(hub)).toEqual({})
	end)

	it("places nothing while switched off", function()
		C.Features.EasterEggs = false
		local ok, hub = pcall(HubBuilder.Build)
		rt:flush()
		C.Features.EasterEggs = true
		expect(ok).toBe(true)
		expect(#hub.EasterEggs:GetChildren()).toBe(0)
	end)
end)

-- A server with the hub, saves, the shop and the eggs running.
local function server(options: any?)
	local rt = Runtime.new(options or { studio = true })
	local services = "ServerScriptService.Server.Services."
	for _, name in
		{ "HubService", "DataService", "ShopService", "AdminService", "EasterEggService" }
	do
		rt:require(services .. name).Start()
	end
	rt:flush()
	return rt
end

local function toasts(rt: any, player: any): { any }
	local out = {}
	for _, call in rt:calls("RemoteEvent", "FireClient") do
		if call.instance.Name == "EasterEggFound" and call.args[1] == player then
			table.insert(out, call.args[2])
		end
	end
	return out
end

-- Puts the player next to an egg and waits there as long as it takes to have walked (the
-- anti-teleport check, Config.EasterEggs.AntiTeleport, only remembers WindowSeconds).
local function standBy(rt: any, player: any, part: any, distance: number)
	player.Character:PivotTo(rt.env.CFrame.new(part.Position + rt.env.Vector3.new(distance, 2, 0)))
	rt:advance(cfg.AntiTeleport.WindowSeconds + 0.5)
end

describe("EasterEggService", function()
	it("gives an egg's coins once, with a toast, and remembers it", function()
		local rt = server()
		local hub = rt.workspace.Hub
		local eggs = eggsIn(rt, hub)
		local player = rt:addPlayer({ Name = "Finder" })
		rt:advance(1)
		local data = rt:require("ServerScriptService.Server.Services.DataService").Get(player)
		local coins = data.Coins
		local active = rt.game:GetService("ReplicatedStorage"):GetAttribute("EasterEggsActive")
		expect(active).toMatch("ShopPumpkin")
		local total = #EasterEggRules.ParseIds(active)

		-- Too far away: nothing.
		local shop = eggs.ShopPumpkin
		standBy(rt, player, shop, cfg.ReachDistance + 10)
		rt:triggerPrompt(shop:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(data.EasterEggs.ShopPumpkin).toBeNil()

		-- Close enough: +50 and a toast.
		rt:advance(1)
		standBy(rt, player, shop, 3)
		rt:triggerPrompt(shop:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(data.EasterEggs.ShopPumpkin).toBe(true)
		expect(data.Coins).toBe(coins + 50)
		local toast = toasts(rt, player)[1]
		expect(toast.Name).toBe("Shy Shop Pumpkin")
		expect(toast.Coins).toBe(50)
		expect(toast.Found).toBe(1)
		expect(toast.Total).toBe(total)
		expect(player:GetAttribute("EasterEggsFound")).toBe("ShopPumpkin")

		-- Again: nothing more.
		rt:advance(1)
		rt:triggerPrompt(shop:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(data.Coins).toBe(coins + 50)
		expect(#toasts(rt, player)).toBe(1)

		-- Walking into another one collects it too.
		rt:advance(1)
		local grave = eggs.GraveCandy
		standBy(rt, player, grave, 1)
		rt:fire(grave, "Touched", player.Character.HumanoidRootPart)
		expect(data.EasterEggs.GraveCandy).toBe(true)
		expect(data.Coins).toBe(coins + 50 + grave:GetAttribute("Coins"))
		expect(toasts(rt, player)[2].Found).toBe(2)

		-- Not while in a round.
		rt:advance(1)
		local patch = eggs.PatchGold
		standBy(rt, player, patch, 2)
		player:SetAttribute("InRound", true)
		rt:triggerPrompt(patch:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(data.EasterEggs.PatchGold).toBeNil()
		player:SetAttribute("InRound", nil)

		-- F8 > "Easter eggs: reset mine".
		rt:advance(1)
		local ok = rt:invokeServer(
			rt:find("ReplicatedStorage.Remotes.AdminCommand"),
			player,
			"EasterEggsReset"
		)
		expect(ok).toBe(true)
		expect(next(data.EasterEggs)).toBeNil()
		expect(player:GetAttribute("EasterEggsFound")).toBe("")

		-- F8 > "Reset my save": found eggs show again at once, and the list of Robux purchases
		-- already granted is kept (so none can be granted twice).
		rt:advance(1)
		standBy(rt, player, shop, 3)
		rt:triggerPrompt(shop:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(player:GetAttribute("EasterEggsFound")).toBe("ShopPumpkin")
		table.insert(data.Receipts, "purchase-7")
		rt:advance(1)
		ok = rt:invokeServer(rt:find("ReplicatedStorage.Remotes.AdminCommand"), player, "ResetSave")
		expect(ok).toBe(true)
		expect(next(data.EasterEggs)).toBeNil()
		expect(player:GetAttribute("EasterEggsFound")).toBe("")
		expect(data.Receipts).toEqual({ "purchase-7" })
		expect(data.Coins).toBe(0)
		rt:removePlayer(player)
		expect(#rt.errors).toBe(0)
	end)

	it("refuses an egg to someone who teleported to it (but not after a respawn)", function()
		local rt = server()
		local eggs = eggsIn(rt, rt.workspace.Hub)
		local player = rt:addPlayer({ Name = "Hopper" })
		rt:advance(1)
		local data = rt:require("ServerScriptService.Server.Services.DataService").Get(player)
		local shop = eggs.ShopPumpkin
		local V3 = rt.env.Vector3
		-- Standing far away for a while, then at the egg in an instant: refused.
		player.Character:PivotTo(rt.env.CFrame.new(shop.Position + V3.new(200, 2, 200)))
		rt:advance(3)
		player.Character:PivotTo(rt.env.CFrame.new(shop.Position + V3.new(3, 2, 0)))
		rt:triggerPrompt(shop:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(data.EasterEggs.ShopPumpkin).toBeNil()
		-- Waiting a moment there doesn't help...
		rt:advance(2)
		rt:triggerPrompt(shop:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(data.EasterEggs.ShopPumpkin).toBeNil()
		-- ...only once the jump is older than WindowSeconds (as long as walking would take).
		rt:advance(cfg.AntiTeleport.WindowSeconds)
		rt:triggerPrompt(shop:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(data.EasterEggs.ShopPumpkin).toBe(true)
		-- A new character (a respawn, or back from a round) starts afresh.
		local grave = eggs.GraveCandy
		player.Character:PivotTo(rt.env.CFrame.new(grave.Position + V3.new(300, 2, 0)))
		rt:advance(3)
		rt:spawnCharacter(player, rt.env.CFrame.new(grave.Position + V3.new(2, 2, 0)))
		rt:advance(1)
		rt:triggerPrompt(grave:FindFirstChildOfClass("ProximityPrompt"), player)
		expect(data.EasterEggs.GraveCandy).toBe(true)
		expect(#rt.errors).toBe(0)
	end)

	it("hides the eggs of a hub saved before them, and none while switched off", function()
		-- A hub built with the eggs off, then the game starts with them on: they are added.
		local rt = Runtime.new()
		local C = rt:require("ReplicatedStorage.Shared.Config")
		C.Features.EasterEggs = false
		rt:require("ServerScriptService.Server.Hub.HubBuilder").Build()
		rt:flush()
		C.Features.EasterEggs = true
		expect(next(eggsIn(rt, rt.workspace))).toBeNil()
		rt:require("ServerScriptService.Server.Services.EasterEggService").Start()
		rt:flush()
		expect(eggsIn(rt, rt.workspace).ShopPumpkin).toBeTruthy()

		local off = Runtime.new()
		local O = off:require("ReplicatedStorage.Shared.Config")
		O.Features.EasterEggs = false
		off:require("ServerScriptService.Server.Services.HubService").Start()
		off:require("ServerScriptService.Server.Services.EasterEggService").Start()
		off:flush()
		expect(off:find("ReplicatedStorage.Remotes.EasterEggFound")).toBeTruthy()
		expect(next(eggsIn(off, off.workspace))).toBeNil()
	end)
end)

describe("EasterEggUI", function()
	it("hides found eggs, counts progress, shows the toast and the list", function()
		local srv = server()
		local client = Runtime.new({ client = true })
		client:replicateFrom(srv)
		local ReplicatedStorage = client.game:GetService("ReplicatedStorage")
		local player = client.game:GetService("Players").LocalPlayer
		local active = srv.game:GetService("ReplicatedStorage"):GetAttribute("EasterEggsActive")
		ReplicatedStorage:SetAttribute("EasterEggsActive", active)
		local total = #EasterEggRules.ParseIds(active)
		local gui = client:create("ScreenGui", { Name = "GameUI" }, player.PlayerGui)
		local EasterEggUI = client:require("StarterPlayer.StarterPlayerScripts.Client.EasterEggUI")
		EasterEggUI.Mount(gui)
		client:advance(0.5)

		local found, all = EasterEggUI.Progress()
		expect(found).toBe(0)
		expect(all).toBe(total)

		local shop = eggsIn(client, client.workspace).ShopPumpkin
		expect(shop).toBeTruthy()
		expect(shop.LocalTransparencyModifier).toBe(0)
		player:SetAttribute("EasterEggsFound", "ShopPumpkin")
		client:flush()
		found = EasterEggUI.Progress()
		expect(found).toBe(1)
		expect(shop.LocalTransparencyModifier).toBe(1)
		expect(shop:FindFirstChildOfClass("ProximityPrompt").Enabled).toBe(false)
		for _, d in shop.Parent:GetDescendants() do
			if d:IsA("BasePart") then
				expect(d.LocalTransparencyModifier).toBe(1)
			end
		end

		client:fire(client:find("ReplicatedStorage.Remotes.EasterEggFound"), "OnClientEvent", {
			Id = "ShopPumpkin",
			Name = "Shy Shop Pumpkin",
			Coins = 50,
			Found = 1,
			Total = total,
		})
		expect(gui.EasterEggToast.Visible).toBe(true)
		-- Celebrations: sparkles burst at the egg, the coins count up to the real number.
		local fxFolder = client.workspace:FindFirstChild("MinigameFx")
		expect(fxFolder).toBeTruthy()
		local burst = fxFolder:FindFirstChild("Burst")
		expect(burst).toBeTruthy()
		expect((burst.Position - shop.Position).Magnitude).toBeLessThan(0.01)
		expect(burst.CanCollide).toBe(false)
		local emits = client:calls("ParticleEmitter", "Emit")
		expect(emits[#emits].args[1]).toBe(cfg.Effects.Sparkles) -- (not a phone)
		client:advance(cfg.Effects.CoinsCountSeconds + 0.05)
		expect(gui.EasterEggToast.Detail.Text).toBe(cfg.Text.Toast:format(50, "Coins", 1, total))
		client:advance(cfg.ToastSeconds + 1)
		expect(gui.EasterEggToast.Visible).toBe(false)
		expect(#fxFolder:GetChildren()).toBe(0) -- the sparkles cleaned up

		EasterEggUI.Open()
		expect(gui.EasterEggs.Visible).toBe(true)
		-- The found egg's row shines once, then the shine is gone.
		local shines = 0
		for _, d in gui.EasterEggs.List:GetDescendants() do
			if d.Name == "FxShine" then
				shines += 1
			end
		end
		expect(shines).toBe(1)
		client:advance(cfg.Effects.ShineSeconds + 0.1)
		for _, d in gui.EasterEggs.List:GetDescendants() do
			expect(d.Name).never.toBe("FxShine")
		end
		local rows = 0
		for _, child in gui.EasterEggs.List:GetChildren() do
			if child:IsA("Frame") then
				rows += 1
			end
		end
		expect(rows).toBe(total)
		expect(gui.EasterEggs.Progress.Text).toBe(cfg.Text.Progress:format(1, total))

		-- Reset (admin): the egg shows again.
		player:SetAttribute("EasterEggsFound", "")
		client:flush()
		expect(shop.LocalTransparencyModifier).toBe(0)
		expect(#client.errors).toBe(0)
	end)

	it("shows the plain toast with the exact coins at once when effects are off", function()
		local srv = server()
		for _, flag in { "Game", "All" } do
			local client = Runtime.new({ client = true })
			client:replicateFrom(srv)
			local C = client:require("ReplicatedStorage.Shared.Config")
			if flag == "Game" then
				C.EasterEggs.Effects.On = false
			else
				C.Minigames.Effects.On = false
			end
			local player = client.game:GetService("Players").LocalPlayer
			local gui = client:create("ScreenGui", { Name = "GameUI" }, player.PlayerGui)
			local EasterEggUI =
				client:require("StarterPlayer.StarterPlayerScripts.Client.EasterEggUI")
			EasterEggUI.Mount(gui)
			client:advance(0.5)
			player:SetAttribute("EasterEggsFound", "ShopPumpkin")
			client:flush()
			local home = gui.EasterEggToast.Position
			client:fire(client:find("ReplicatedStorage.Remotes.EasterEggFound"), "OnClientEvent", {
				Id = "ShopPumpkin",
				Name = "Shy Shop Pumpkin",
				Coins = 50,
				Found = 1,
				Total = 10,
			})
			expect(gui.EasterEggToast.Visible).toBe(true)
			expect(gui.EasterEggToast.Detail.Text).toBe(cfg.Text.Toast:format(50, "Coins", 1, 10))
			expect(gui.EasterEggToast.Position).toBe(home) -- no slide
			expect(client.workspace:FindFirstChild("MinigameFx")).toBeNil()
			EasterEggUI.Open()
			for _, d in gui.EasterEggs.List:GetDescendants() do
				expect(d.Name).never.toBe("FxShine")
			end
			expect(#client.errors).toBe(0)
		end
	end)
end)
