-- A lobby saved in the place (baked or Locked) and edited by hand: what HubService and the lobby
-- services keep, put back or take out on start. Your own HubSpawn SpawnLocation stays on;
-- pieces dragged out of the hub are cleaned up before the required ones are checked; a tagged
-- Ready pad Model and a shopkeeper anywhere in Workspace count; a Lighting typo doesn't stop
-- the hub; switched-off areas leave the running game; Candy Rush and Web Scour repair a saved
-- hub without throwing hand edits away; Config words and coins reach a saved hub; the Voting
-- Board client finds its board wherever it stands.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local SERVICES = "ServerScriptService.Server.Services."

local function world(): any
	local rt = Runtime.new({ studio = true })
	local w = {
		rt = rt,
		CS = rt.game:GetService("CollectionService"),
		Config = rt:require("ReplicatedStorage.Shared.Config"),
		Tags = rt:require("ReplicatedStorage.Shared.Tags"),
		HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder"),
		HubService = rt:require(SERVICES .. "HubService"),
	}
	-- Everything tagged `tag` in Workspace (or under `root`).
	function w.tagged(tag: string, root: any?): { any }
		local list = {}
		for _, instance in w.CS:GetTagged(tag) do
			if instance:IsDescendantOf(root or rt.workspace) then
				table.insert(list, instance)
			end
		end
		return list
	end
	-- Warnings the game printed since `from` that contain `text`.
	function w.warned(text: string, from: number?): boolean
		for i = (from or 0) + 1, #rt.warnings do
			if string.find(rt.warnings[i], text, 1, true) then
				return true
			end
		end
		return false
	end
	-- A saved, Locked hub built with the current Config (like Bake.Hub() + Bake.Lock()).
	function w.savedHub(): any
		local hub = w.HubBuilder.Build()
		hub:SetAttribute("Locked", true)
		return hub
	end
	return w
end

local function npcCount(root: any, id: string): number
	local count = 0
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("NpcId") == id then
			count += 1
		end
	end
	return count
end

describe("HubService on a hand-edited saved hub", function()
	it("keeps your own SpawnLocation tagged HubSpawn switched on", function()
		local w = world()
		local hub = w.savedHub()
		hub.Spawn:Destroy() -- replaced by a Model > Spawn SpawnLocation straight in Workspace
		local mine = w.rt:create("SpawnLocation", { Name = "SpawnLocation" }, w.rt.workspace)
		mine:AddTag(w.Tags.HubSpawn)
		local baseplateSpawn =
			w.rt:create("SpawnLocation", { Name = "BaseplateSpawn" }, w.rt.workspace)
		w.HubService.Start()
		expect(mine.Parent).toBe(w.rt.workspace)
		expect(mine.Enabled).toBe(true)
		expect(mine.CanCollide).toBe(true)
		expect(baseplateSpawn.Enabled).toBe(false) -- an untagged one still competes: off
		expect(#w.tagged(w.Tags.HubSpawn)).toBe(1) -- no second spawn was built
		expect(hub:FindFirstChild("Spawn")).toBeNil()
	end)

	it("puts back the Ready pad and spawn after removing copies dragged out of the hub", function()
		local w = world()
		local hub = w.savedHub()
		hub.ReadyArea.Parent = w.rt.workspace -- still tagged and marked HubPiece
		hub.Spawn.Parent = w.rt.workspace
		w.HubService.Start()
		expect(w.rt.workspace:FindFirstChild("ReadyArea")).toBeNil()
		expect(w.rt.workspace:FindFirstChild("Spawn")).toBeNil()
		local pads = w.tagged(w.Tags.ReadyPad)
		expect(#pads).toBe(1)
		expect(pads[1]:IsDescendantOf(hub)).toBe(true)
		local spawns = w.tagged(w.Tags.HubSpawn)
		expect(#spawns).toBe(1)
		expect(spawns[1]:IsDescendantOf(hub)).toBe(true)
	end)

	it("counts a Ready pad Model and builds no second pad", function()
		local w = world()
		local hub = w.savedHub()
		w.tagged(w.Tags.ReadyPad, hub)[1]:Destroy()
		local pad = w.rt:create("Model", { Name = "MyToolboxPad" }, hub)
		w.rt:create("Part", { Name = "Stone", Size = w.rt.env.Vector3.new(12, 1, 12) }, pad)
		pad:AddTag(w.Tags.ReadyPad)
		local before = #w.rt.warnings
		w.HubService.Start()
		local pads = w.tagged(w.Tags.ReadyPad)
		expect(#pads).toBe(1)
		expect(pads[1]).toBe(pad)
		expect(w.warned("Ready pad", before)).toBe(false)
	end)

	it("finds the shopkeeper dragged out of the hub and builds no second one", function()
		local w = world()
		local hub = w.savedHub()
		local vendor = hub.Shop.PumpkinVendor
		vendor.Parent = w.rt.workspace
		local before = #w.rt.warnings
		w.HubService.Start()
		expect(vendor.Parent).toBe(w.rt.workspace) -- not a loose hub piece: kept
		expect(npcCount(w.rt.workspace, "PumpkinVendor")).toBe(1)
		expect(w.warned("shopkeeper", before)).toBe(false)
	end)

	it("gives a ShopKeeper part or model anywhere in Workspace a shop prompt", function()
		local w = world()
		local hub = w.savedHub()
		hub.Shop.PumpkinVendor:Destroy()
		local booth = w.rt:create("Model", { Name = "MyShopBooth" }, w.rt.workspace)
		local counter = w.rt:create("Part", { Name = "Counter" }, booth)
		booth.PrimaryPart = counter
		booth:AddTag(w.Tags.ShopKeeper)
		local sign = w.rt:create("Part", { Name = "ShopSign" }, w.rt.workspace)
		sign:AddTag(w.Tags.ShopKeeper)
		w.HubService.Start()
		for _, holder in { counter, sign } do
			local prompt = holder:FindFirstChildWhichIsA("ProximityPrompt")
			expect(prompt).toBeInstanceOf("ProximityPrompt")
			expect(prompt:GetAttribute("NpcId")).toBe("PumpkinVendor")
		end
		expect(npcCount(w.rt.workspace, "PumpkinVendor")).toBe(0) -- no default keeper built
	end)

	it("still builds the hub when Config.Hub.Lighting has a typo", function()
		local w = world()
		local lighting = w.Config.Hub.Lighting :: any
		lighting.Sky.MoonSize = 30 -- not a Sky property (MoonAngularSize is)
		local before = #w.rt.warnings
		local ok, err = pcall(w.HubService.Start)
		lighting.Sky.MoonSize = nil
		if not ok then
			error(err)
		end
		expect(w.warned("MoonSize", before)).toBe(true)
		local hub = w.rt.workspace:FindFirstChild("Hub")
		expect(hub).toBeInstanceOf("Folder")
		expect(#w.tagged(w.Tags.HubSpawn)).toBe(1)
		-- The good settings next to the typo were still applied.
		local sky = w.rt.game:GetService("Lighting"):FindFirstChild("HubSky")
		expect(sky.MoonAngularSize).toBe(w.Config.Hub.Lighting.Sky.MoonAngularSize)
	end)
end)

describe("Switched-off lobby areas in a saved hub", function()
	it(
		"takes the Ready pad, Parkour, Candy Rush and crate stand out of the running game",
		function()
			local w = world()
			local Tags, Features = w.Tags, w.Config.Features
			local hub = w.savedHub() -- baked with everything on
			-- Things that must stay: an NPC standing in an area, and a pad copy outside the hub.
			local board = hub.Npcs.VotingBoard
			board.Parent = hub.ReadyArea
			local copy = w.tagged(Tags.ReadyPad, hub)[1]:Clone()
			copy.Parent = w.rt.workspace
			-- Easter eggs: the one up on the parkour trophy would float in the air without it.
			local function eggIds(): { [string]: boolean }
				local ids = {}
				for _, egg in w.tagged(Tags.EasterEgg) do
					ids[egg:GetAttribute("EggId")] = true
				end
				return ids
			end
			local skyEgg, groundEgg
			for _, egg in w.Config.EasterEggs.List do
				if egg.Anchor == "ParkourFinish" then
					skyEgg = egg.Id
				elseif egg.Anchor == "HubSpawn" then
					groundEgg = egg.Id
				end
			end
			expect(eggIds()[skyEgg]).toBe(true)
			local saved = table.clone(Features)
			Features.ReadyPad, Features.Parkour, Features.CandyRush, Features.Crates =
				false, false, false, false
			local ok, err = pcall(function()
				w.HubService.Start()
				for _, name in
					{ "ReadyService", "ParkourService", "CandyRushService", "CrateService" }
				do
					w.rt:require(SERVICES .. name).Start()
				end
			end)
			for key, value in saved do
				Features[key] = value
			end
			if not ok then
				error(err)
			end
			for _, tag in
				{
					Tags.ReadyPad,
					Tags.ReadySign,
					Tags.ParkourStart,
					Tags.ParkourCheckpoint,
					Tags.ParkourFinish,
					Tags.ParkourBoard,
					Tags.CandyRushStation,
					Tags.CandyRushPad,
					Tags.CrateDisplay,
				}
			do
				if #w.tagged(tag) > 0 then
					error(("something tagged %s is still in Workspace"):format(tag))
				end
			end
			for _, name in { "Parkour", "CandyRush", "CrateStand" } do
				expect(#hub[name]:GetChildren()).toBe(0) -- the empty model stays, like a fresh build
			end
			expect(board.Parent).toBe(hub.ReadyArea) -- the NPC in the emptied area stays
			expect(#hub.ReadyArea:GetChildren()).toBe(1)
			expect(copy.Parent).toBeNil()
			expect(eggIds()[skyEgg]).toBeNil()
			expect(eggIds()[groundEgg]).toBe(true)
			-- Areas that are on are left alone.
			expect(#w.tagged(Tags.WebScourStart)).toBeGreaterThan(0)
			expect(#w.tagged(Tags.ShopKeeper)).toBeGreaterThan(0)
		end
	)

	it("leaves every area of a saved hub alone while the switches are on", function()
		local w = world()
		local hub = w.savedHub()
		local counts = {}
		for _, name in { "ReadyArea", "Parkour", "CandyRush", "CrateStand" } do
			counts[name] = #hub[name]:GetDescendants()
		end
		expect(#w.HubBuilder.RemoveSwitchedOff(hub)).toBe(0)
		for name, count in counts do
			expect(#hub[name]:GetDescendants()).toBe(count)
		end
	end)
end)

describe("Candy Rush on a saved hub without a stand", function()
	it("builds the whole area when the hub was baked with Candy Rush off", function()
		local w = world()
		local Features = w.Config.Features
		Features.CandyRush = false
		local hub = w.savedHub()
		Features.CandyRush = true
		expect(#hub.CandyRush:GetChildren()).toBe(0)
		w.HubService.Start()
		local before = #w.rt.warnings
		w.rt:require(SERVICES .. "CandyRushService").Start()
		local stands = w.tagged(w.Tags.CandyRushStation)
		expect(#stands).toBe(1)
		expect(stands[1]:IsDescendantOf(hub.CandyRush)).toBe(true)
		expect(hub.CandyRush:FindFirstChild("Floor")).toBeTruthy()
		expect(#w.tagged(w.Tags.CandyRushPad)).toBe(
			math.clamp(w.Config.Minigames.CandyRush.Stand.Lanes, 2, 6)
		)
		expect(w.warned("no Candy Rush stand", before)).toBe(true)
		local count = 0
		for _, child in hub:GetChildren() do
			if child.Name == "CandyRush" then
				count += 1
			end
		end
		expect(count).toBe(1)
		w.rt:advance(2) -- the race loop runs on the new stand without errors
		expect(#w.rt.errors).toBe(0)
	end)

	it("only puts the stand back in an area edited by hand", function()
		local w = world()
		local hub = w.savedHub()
		hub.CandyRush.CandyStand:Destroy()
		local marker = w.rt:create("Part", { Name = "MyGumdrop" }, hub.CandyRush)
		local floors = #hub.CandyRush.Floor:GetChildren()
		w.HubService.Start()
		w.rt:require(SERVICES .. "CandyRushService").Start()
		expect(#w.tagged(w.Tags.CandyRushStation)).toBe(1)
		expect(marker.Parent).toBe(hub.CandyRush)
		expect(#hub.CandyRush.Floor:GetChildren()).toBe(floors)
		local floorModels = 0
		for _, child in hub.CandyRush:GetChildren() do
			if child.Name == "Floor" then
				floorModels += 1
			end
		end
		expect(floorModels).toBe(1)
	end)
end)

describe("Web Scour on a saved hub without a lantern", function()
	it("keeps a hand-edited grove and only puts a lantern back", function()
		local w = world()
		local hub = w.savedHub()
		local grove = hub.WebScour
		w.tagged(w.Tags.WebScourStart, grove)[1]:Destroy()
		local marker = w.rt:create("Part", { Name = "MyExtraWeb" }, grove)
		local spots = #w.tagged(w.Tags.WebScourSpot)
		w.HubService.Start()
		w.rt:require(SERVICES .. "WebScourService").Start()
		expect(hub.WebScour).toBe(grove)
		expect(marker.Parent).toBe(grove)
		expect(#w.tagged(w.Tags.WebScourSpot)).toBe(spots)
		local starts = w.tagged(w.Tags.WebScourStart)
		expect(#starts).toBe(1)
		expect(starts[1]:IsDescendantOf(grove)).toBe(true)
		expect(starts[1]:FindFirstChildOfClass("ProximityPrompt")).toBeTruthy()
	end)

	it("builds the whole grove when the area is empty", function()
		local w = world()
		local Features = w.Config.Features
		Features.WebScour = false
		local hub = w.savedHub()
		Features.WebScour = true
		w.HubService.Start()
		w.rt:require(SERVICES .. "WebScourService").Start()
		expect(#w.tagged(w.Tags.WebScourStart)).toBe(1)
		expect(#w.tagged(w.Tags.WebScourSpot)).toBeGreaterThan(0)
		expect(#w.tagged(w.Tags.WebScourSpot, hub.WebScour)).toBe(#w.tagged(w.Tags.WebScourSpot))
	end)

	it("puts the button on a lantern Model and starts a hunt from it", function()
		local w = world()
		local rt = w.rt
		local hub = w.savedHub()
		local old = w.tagged(w.Tags.WebScourStart, hub)[1]
		local spot = old.CFrame
		old:Destroy()
		local lantern = rt:create("Model", { Name = "ToolboxLantern" }, hub.WebScour)
		local glass = rt:create("Part", { Name = "Glass", CFrame = spot }, lantern)
		lantern:AddTag(w.Tags.WebScourStart)
		local spots = #w.tagged(w.Tags.WebScourSpot)
		for _, name in
			{ "HubService", "DataService", "ShopService", "AdminService", "WebScourService" }
		do
			rt:require(SERVICES .. name).Start()
		end
		expect(#w.tagged(w.Tags.WebScourStart)).toBe(1) -- not rebuilt
		expect(#w.tagged(w.Tags.WebScourSpot)).toBe(spots)
		local prompt = glass:FindFirstChildOfClass("ProximityPrompt")
		expect(prompt).toBeTruthy()
		local player = rt:addPlayer({ Name = "Hunter" })
		rt:advance(1)
		local look = spot.LookVector
		player.Character:PivotTo(
			rt.env.CFrame.new(spot.Position + look * 3 - rt.env.Vector3.new(0, 3.5, 0))
		)
		rt:triggerPrompt(prompt, player)
		expect(rt:require(SERVICES .. "WebScourService").IsHunting(player)).toBe(true)
	end)
end)

describe("Config reaches a saved hub", function()
	it("writes the parkour board's reward line from Config again", function()
		local w = world()
		local hub = w.savedHub()
		local cfg = w.Config.Parkour
		local screen = w.tagged(w.Tags.ParkourBoard, hub)[1]
		local Parkour = w.rt:require("ServerScriptService.Server.Hub.Sections.Parkour")
		local gui = Parkour.BoardGui(screen)
		local coins = cfg.Reward.Coins
		cfg.Reward.Coins = coins + 25
		local again = Parkour.BoardGui(screen)
		local footer = again.Footer.Text
		cfg.Reward.Coins = coins
		expect(again).toBe(gui) -- the saved sign is kept...
		expect(footer).toBe(cfg.Text.BoardReward:format(coins + 25, w.Config.Economy.CurrencyName))
	end)

	it("pays an egg's Coins from Config.EasterEggs.List, not the saved attribute", function()
		local w = world()
		local rt = w.rt
		local hub = w.savedHub()
		for _, name in { "HubService", "DataService", "ShopService", "EasterEggService" } do
			rt:require(SERVICES .. name).Start()
		end
		local egg = w.Config.EasterEggs.List[1]
		local part
		for _, instance in w.tagged(w.Tags.EasterEgg, hub) do
			if instance:GetAttribute("EggId") == egg.Id then
				part = instance
			end
		end
		expect(part).toBeTruthy()
		part:SetAttribute("Coins", 1) -- an old value saved in the place
		local player = rt:addPlayer({ Name = "Finder" })
		rt:advance(1)
		player.Character:PivotTo(rt.env.CFrame.new(part.Position + rt.env.Vector3.new(0, 2, 0)))
		rt:advance(w.Config.EasterEggs.AntiTeleport.WindowSeconds + 0.5) -- (standing there, not teleporting)
		local data = rt:require(SERVICES .. "DataService").Get(player)
		local before = data.Coins
		expect(rt:require(SERVICES .. "EasterEggService").Collect(player, part)).toBe(true)
		expect(data.Coins).toBe(before + egg.Coins)
	end)
end)

describe("VoteBoardUI", function()
	it("finds the Voting Board wherever it stands in the hub", function()
		local w = world()
		local hub = w.HubBuilder.Build()
		local VoteBoardUI = w.rt:require("StarterPlayer.StarterPlayerScripts.Client.VoteBoardUI")
		local board = hub.Npcs.VotingBoard
		expect(VoteBoardUI.FindScreen(hub, "VotingBoard")).toBe(board.Screen)
		board.Parent = hub.ReadyArea -- an NPC with Zone = "ReadyArea" is built there
		expect(VoteBoardUI.FindScreen(hub, "VotingBoard")).toBe(board.Screen)
		board:Destroy()
		expect(VoteBoardUI.FindScreen(hub, "VotingBoard")).toBeNil()
	end)
end)
