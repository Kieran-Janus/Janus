-- v2 foundation: feature switches, maps and playlists, rarity prices, Items helpers, the
-- Pumpkin Shop, the save template, Lobby zone maths and Tags.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Vector3 = rt.env.Vector3
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Items = rt:require("ReplicatedStorage.Shared.Items")
local Lobby = rt:require("ReplicatedStorage.Shared.Lobby")
local Tags = rt:require("ReplicatedStorage.Shared.Tags")
local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")

describe("Config.Features", function()
	it("has a true/false switch for every v2 feature", function()
		for _, name in
			{
				"ReadyPad",
				"LobbySpectate",
				"Menu",
				"KingHunt",
				"HideSeek",
				"ScareMaze",
				"Parkour",
				"CandyRush",
				"WebScour",
				"EasterEggs",
				"Crates",
				"RobuxCrates",
				"Tutorial",
			}
		do
			expect(Config.Features[name]).toBeA("boolean")
		end
		for name, value in Config.Features do
			if type(value) ~= "boolean" then
				error(("Features.%s is %s"):format(name, tostring(value)))
			end
		end
		expect(Config.Features.Tutorial).toBe(false) -- the tutorial is off in v2
	end)
end)

describe("Config.Maps", function()
	it("lists the King Hunt maps and the v2 maps", function()
		local ids = {}
		for _, def in Config.Maps.List do
			ids[def.Id] = true
		end
		for _, id in { "PumpkinPatch", "SpookyMansion", "PumpkinFarm", "HedgeMaze", "ScareMaze" } do
			expect(ids[id]).toBe(true)
		end
	end)

	it("gives every map every setting the game reads", function()
		for _, def in Config.Maps.List do
			for _, key in { "Name", "SpawnFolder", "Builder" } do
				expect(def[key]).toBeA("string")
			end
			for _, key in { "Thumbnail", "Seed", "WallHeight", "Spawns", "SpawnRadius" } do
				expect(def[key]).toBeA("number")
			end
			expect(def.Colors).toBeA("table")
			expect(def.Layout).toBeA("table")
			expect(def.Particles).toBeA("table")
			expect(def.AmbientSound.SoundId).toBeA("string")
			expect(def.Lighting.ClockTime).toBeA("number")
			expect(def.Lighting.Brightness).toBeA("number")
		end
	end)

	it("has six playlists", function()
		expect(#Config.Modes.Playlists).toBe(6)
		local ids = {}
		for _, playlist in Config.Modes.Playlists do
			if ids[playlist.Id] then
				error("duplicate playlist Id " .. playlist.Id)
			end
			ids[playlist.Id] = true
			expect(playlist.MinPlayers).toBeA("number")
			local mode = Config.Modes.List[playlist.Mode]
			expect(Config.Features[mode.Feature]).toBeA("boolean")
		end
	end)
end)

describe("Rarity and prices", function()
	it("has the v2 prices", function()
		local expected = { Common = 125, Uncommon = 500, Rare = 1000, Crazy = 100000 }
		expect(#Config.Rarity.Order).toBe(4)
		for _, id in Config.Rarity.Order do
			local level = Config.Rarity.Levels[id]
			expect(level).toBeA("table")
			expect(level.Price).toBe(expected[id])
			expect(level.Color).toBeA("Color3")
			expect(level.DuplicateRefund).toBeA("number")
			expect(level.DuplicateRefund).toBeLessThan(level.Price)
		end
		expect(Config.Rarity.Levels.Crazy.Name).toBe("CRAZY")
		expect(Config.Rewards.CoinsPerPumpkin).toBe(5)
	end)

	it("prices the shop by rarity, and VIP / crate-only items not at all", function()
		for _, item in Config.Shop.Items do
			local price = Items.Price(item)
			if item.VipOnly or item.CrateOnly or item.Exclusive then
				expect(price).toBeNil()
			else
				expect(price).toBe(item.Price or Config.Rarity.Levels[item.Rarity].Price)
			end
		end
		expect(Items.Price(Items.Get("Zombie"))).toBe(125)
		expect(Items.Price(Items.Get("Skeleton"))).toBe(500)
		expect(Items.Price(Items.Get("Ghost"))).toBe(1000)
		expect(Items.Price(Items.Get("KingSkin"))).toBeNil() -- VIP items can't be bought
	end)
end)

describe("Items", function()
	it("looks items up safely", function()
		expect(Items.Get("NoSuchItem")).toBeNil()
		expect(Items.Get(42)).toBeNil()
		expect(Items.Get(nil)).toBeNil()
		expect(Cosmetics.Find("PumpkinCap")).toBe(Items.Get("PumpkinCap"))
	end)

	it("works out price and rarity for odd items", function()
		expect(Items.Price({ Id = "X", Rarity = "Rare", CrateOnly = true })).toBeNil()
		expect(Items.Price({ Id = "X", Rarity = "Rare", Price = 7 })).toBe(7) -- own Price wins
		expect(Items.Price({ Id = "X" })).toBe(125) -- no Rarity = Common
		expect(Items.Rarity({ Id = "X", Rarity = "Legendary" })).toBe("Common") -- misspelled
		expect(Items.RarityInfo({ Id = "X", Rarity = "Crazy" }).Price).toBe(100000)
		expect(Items.CanBuyDirect(Items.Get("Zombie"))).toBe(true)
		expect(Items.CanBuyDirect(Items.Get("KingCrown"))).toBe(false)
	end)

	it("lists items by slot and crate, including items added later", function()
		local skins = Items.ForSlot("Skin")
		expect(#skins).toBeGreaterThanOrEqual(6)
		for _, item in skins do
			expect(item.Slot).toBe("Skin")
		end
		expect(#Items.ByCrate("NoSuchCrate")).toBe(0)
		table.insert(
			Config.Shop.Items,
			{ Id = "LateItem", Name = "Late", Slot = "Hat", Rarity = "Rare", Crate = "TestCrate" }
		)
		local ok, err = pcall(function()
			expect(Items.Get("LateItem").Name).toBe("Late")
			expect(#Items.ByCrate("TestCrate")).toBe(1)
		end)
		table.remove(Config.Shop.Items)
		if not ok then
			error(err, 0)
		end
	end)
end)

describe("Pumpkin Shop", function()
	it("replaces the witch; Boo Guide is gone", function()
		local vendor
		for _, def in Config.Npcs.List do
			expect(def.Id).never.toBe("WitchWanda")
			expect(def.Id).never.toBe("BooGuide")
			if def.OpensShop then
				if
					not (def.OpensShop == "Packs" or table.find(Config.Shop.Slots, def.OpensShop))
				then
					error(("%s opens an unknown tab %s"):format(def.Id, def.OpensShop))
				end
			end
			if def.Id == "PumpkinVendor" then
				vendor = def
			end
		end
		expect(vendor).toBeTruthy()
		expect(vendor.DisplayName).toBe("Pumpkin Shop")
		expect(vendor.OpensShop).toBe("Skin")
		expect(Config.Shop.Title).toBe("Pumpkin Shop")
		expect(Config.Custom.Heights.WitchWanda).toBeNil()
		expect(Config.Custom.Heights.BooGuide).toBeNil()
	end)
end)

describe("Config.Data.Template", function()
	it("has the v2 save fields", function()
		local template = Config.Data.Template
		expect(template.EasterEggs).toEqual({})
		expect(template.Parkour).toEqual({ Best = 0, LastReward = 0, Runs = 0 })
		expect(template.Minigames.CandyRushWins).toBe(0)
		expect(template.Minigames.WebScourBest).toBe(0)
		expect(template.Crates.Opened).toBe(0)
		expect(template.Stats.HideSeekTags).toBe(0)
		expect(template.Stats.HideSeekWins).toBe(0)
		expect(template.Stats.ScareMazeEscapes).toBe(0)
	end)
end)

describe("Lobby", function()
	it("puts every zone on the plaza, facing the middle", function()
		local ground = Config.Hub.Center.Y + 1
		for name, zone in Config.Lobby.Zones do
			local cf = Lobby.ZoneCFrame(name)
			expect(cf.Position).toBeNear(
				Config.Hub.Center + Vector3.new(zone.Offset.X, 1, zone.Offset.Z)
			)
			expect(cf.Position.Y).toBeNear(ground)
			local toCenter = Vector3.new(Config.Hub.Center.X, ground, Config.Hub.Center.Z)
				- cf.Position
			expect(cf.LookVector).toBeNear(toCenter.Unit, 1e-3)
			expect(Lobby.InZone(cf.Position, name)).toBe(true)
		end
	end)

	it("tests positions against zones", function()
		-- ReadyArea: centre (0, 1, 48), 22 wide, 18 deep, facing -Z.
		expect(Lobby.InZone(Vector3.new(10, 1, 48), "ReadyArea")).toBe(true)
		expect(Lobby.InZone(Vector3.new(12, 1, 48), "ReadyArea")).toBe(false)
		expect(Lobby.InZone(Vector3.new(12, 1, 48), "ReadyArea", 2)).toBe(true) -- margin
		expect(Lobby.InZone(Vector3.new(0, 1, 58), "ReadyArea")).toBe(false)
		expect(Lobby.InZone(Vector3.new(0, 200, 48), "ReadyArea")).toBe(true) -- no Height
		-- Parkour has a Height of 120.
		expect(Lobby.InZone(Vector3.new(0, 30, -80), "Parkour")).toBe(true)
		expect(Lobby.InZone(Vector3.new(0, 130, -80), "Parkour")).toBe(false)
		expect(Lobby.ZoneSize("Parkour")).toBeNear(Vector3.new(76, 120, 48))
		expect(Lobby.ZoneSize("Shop")).toBeNear(Vector3.new(22, 0, 18))
		expect(function()
			Lobby.ZoneCFrame("NoSuchZone")
		end).toThrow("NoSuchZone")
	end)
end)

describe("Tags", function()
	it("are plain strings named after themselves", function()
		for _, name in
			{
				"ReadyPad",
				"HubSpawn",
				"ShopKeeper",
				"ParkourStart",
				"ParkourCheckpoint",
				"ParkourFinish",
				"ParkourHazard",
				"CandyRushStation",
				"CandyRushPad",
				"CandyRushBoard",
				"WebScourStart",
				"WebScourSpot",
				"EasterEgg",
				"HidingDecoy",
				"ScareTrigger",
				"MazeExit",
				"HauntSpawn",
				"SurvivorSpawn",
				"SeekerSpawn",
				"HiderSpawn",
			}
		do
			expect(Tags[name]).toBe(name)
		end
		for key, value in Tags do
			expect(value).toBe(key)
		end
	end)
end)
