--!strict
-- v2 foundation: Config loads and is consistent, rarity prices, Items helpers, Lobby zones, Tags.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

return function(t: any)
	local Config = require(ReplicatedStorage.Shared.Config) :: any
	local Items = require(ReplicatedStorage.Shared.Items) :: any
	local Lobby = require(ReplicatedStorage.Shared.Lobby) :: any
	local Tags = require(ReplicatedStorage.Shared.Tags) :: any
	local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics) :: any

	t.test("every feature switch is true or false", function()
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
			t.eq(type(Config.Features[name]), "boolean", "Features." .. name)
		end
		for name, value in Config.Features do
			t.eq(type(value), "boolean", "Features." .. name)
		end
		t.eq(Config.Features.Tutorial, false, "the tutorial is off in v2")
	end)

	t.test("every map is complete and has a builder", function()
		local ids = {}
		local builders = ServerScriptService.Server.Maps
		for _, def in Config.Maps.List do
			t.ok(type(def.Id) == "string" and not ids[def.Id], "unique map Id " .. tostring(def.Id))
			ids[def.Id] = true
			for _, key in { "Name", "SpawnFolder", "Builder" } do
				t.eq(type(def[key]), "string", def.Id .. "." .. key)
			end
			for _, key in { "Thumbnail", "Seed", "WallHeight", "Spawns", "SpawnRadius" } do
				t.eq(type(def[key]), "number", def.Id .. "." .. key)
			end
			t.eq(typeof(def.Size), "Vector3", def.Id .. ".Size")
			t.eq(type(def.Colors), "table", def.Id .. ".Colors")
			t.eq(type(def.Layout), "table", def.Id .. ".Layout")
			t.eq(type(def.Particles), "table", def.Id .. ".Particles")
			t.eq(type(def.AmbientSound.SoundId), "string", def.Id .. ".AmbientSound")
			t.ok(type(def.Modes) == "table" and #def.Modes > 0, def.Id .. ".Modes")
			for _, key in { "ClockTime", "Brightness" } do
				t.eq(type(def.Lighting[key]), "number", def.Id .. ".Lighting." .. key)
			end
			for _, group in { "Atmosphere", "ColorCorrection", "Bloom" } do
				t.eq(type(def.Lighting[group]), "table", def.Id .. ".Lighting." .. group)
			end
			local builder = builders:FindFirstChild(def.Builder)
			t.ok(
				builder and builder:IsA("ModuleScript"),
				"src/server/Maps/" .. def.Builder .. ".luau"
			)
		end
		t.ok(ids.PumpkinPatch and ids.SpookyMansion, "the King Hunt maps are still there")
		t.ok(ids.PumpkinFarm and ids.HedgeMaze and ids.ScareMaze, "the v2 maps are listed")
	end)

	t.test("playlists point at real modes and maps made for them", function()
		local maps = {}
		for _, def in Config.Maps.List do
			maps[def.Id] = def
		end
		local ids = {}
		for _, playlist in Config.Modes.Playlists do
			t.ok(not ids[playlist.Id], "unique playlist Id " .. playlist.Id)
			ids[playlist.Id] = true
			t.ok(
				Config.Modes.List[playlist.Mode],
				playlist.Id .. ": unknown mode " .. playlist.Mode
			)
			t.ok(
				Config.Features[Config.Modes.List[playlist.Mode].Feature] ~= nil,
				playlist.Mode .. " feature"
			)
			local map = maps[playlist.Map]
			t.ok(map, playlist.Id .. ": unknown map " .. playlist.Map)
			t.ok(
				table.find(map.Modes, playlist.Mode),
				playlist.Map .. " isn't made for " .. playlist.Mode
			)
			t.eq(type(playlist.MinPlayers), "number", playlist.Id .. ".MinPlayers")
		end
		t.eq(#Config.Modes.Playlists, 5)
	end)

	t.test("rarities have the v2 prices", function()
		local expected = { Common = 125, Uncommon = 500, Rare = 1000, Crazy = 100000 }
		t.eq(#Config.Rarity.Order, 4)
		for _, id in Config.Rarity.Order do
			local level = Config.Rarity.Levels[id]
			t.ok(level, "Rarity.Levels." .. id)
			t.eq(level.Price, expected[id], id .. " price")
			t.eq(typeof(level.Color), "Color3", id .. " colour")
			t.eq(type(level.DuplicateRefund), "number", id .. " refund")
			t.ok(level.DuplicateRefund < level.Price, id .. " refund is less than the price")
		end
		t.eq(Config.Rarity.Levels.Crazy.Name, "CRAZY")
		t.eq(Config.Rewards.CoinsPerPumpkin, 5)
	end)

	t.test("every shop item has a valid rarity and a sensible price", function()
		local ids = {}
		for _, item in Config.Shop.Items do
			t.ok(not ids[item.Id], "unique item Id " .. item.Id)
			ids[item.Id] = true
			t.ok(
				Config.Rarity.Levels[item.Rarity],
				item.Id .. " has Rarity " .. tostring(item.Rarity)
			)
			t.ok(table.find(Config.Shop.Slots, item.Slot), item.Id .. " slot")
			local price = Items.Price(item)
			if item.VipOnly or item.CrateOnly then
				t.eq(price, nil, item.Id .. " is not sold for coins")
			else
				t.eq(
					price,
					item.Price or Config.Rarity.Levels[item.Rarity].Price,
					item.Id .. " price"
				)
			end
		end
		t.eq(Items.Price(Items.Get("Zombie")), 125)
		t.eq(Items.Price(Items.Get("Skeleton")), 500)
		t.eq(Items.Price(Items.Get("Ghost")), 1000)
		t.eq(Items.Price(Items.Get("KingSkin")), nil, "VIP items can't be bought")
	end)

	t.test("Items helpers", function()
		t.eq(Items.Get("NoSuchItem"), nil)
		t.eq(Items.Get(42), nil)
		t.eq(Items.Get(nil), nil)
		t.eq(Cosmetics.Find("PumpkinCap"), Items.Get("PumpkinCap"), "Cosmetics.Find still works")
		t.eq(Items.Price({ Id = "X", Rarity = "Rare", CrateOnly = true }), nil, "CrateOnly")
		t.eq(Items.Price({ Id = "X", Rarity = "Rare", Price = 7 }), 7, "own Price wins")
		t.eq(Items.Price({ Id = "X" }), 125, "no Rarity = Common")
		t.eq(Items.Rarity({ Id = "X", Rarity = "Legendary" }), "Common", "misspelled rarity")
		t.eq(Items.RarityInfo({ Id = "X", Rarity = "Crazy" }).Price, 100000)
		t.ok(Items.CanBuyDirect(Items.Get("Zombie")))
		t.ok(not Items.CanBuyDirect(Items.Get("KingCrown")))
		local skins = Items.ForSlot("Skin")
		t.ok(#skins >= 6, "skins")
		for _, item in skins do
			t.eq(item.Slot, "Skin")
		end
		t.eq(#Items.ByCrate("NoSuchCrate"), 0)
		-- An item added after the first lookup is still found.
		table.insert(
			Config.Shop.Items,
			{ Id = "LateItem", Name = "Late", Slot = "Hat", Rarity = "Rare", Crate = "TestCrate" }
		)
		t.eq(Items.Get("LateItem").Name, "Late")
		t.eq(#Items.ByCrate("TestCrate"), 1)
		table.remove(Config.Shop.Items)
	end)

	t.test("codes give items that exist", function()
		for _, code in Config.Codes.List do
			if code.Item then
				t.ok(Items.Get(code.Item), code.Code .. " gives unknown item " .. code.Item)
			end
		end
	end)

	t.test("the witch and Boo Guide are gone; the Pumpkin Shop opens the shop", function()
		local vendor
		for _, def in Config.Npcs.List do
			t.ok(def.Id ~= "WitchWanda" and def.Id ~= "BooGuide", def.Id .. " should be removed")
			if def.OpensShop then
				t.ok(
					def.OpensShop == "Packs" or table.find(Config.Shop.Slots, def.OpensShop),
					def.Id .. " opens an unknown tab"
				)
			end
			if def.Id == "PumpkinVendor" then
				vendor = def
			end
		end
		t.ok(vendor, "PumpkinVendor is still in the list")
		t.eq(vendor.DisplayName, "Pumpkin Shop")
		t.eq(vendor.OpensShop, "Skin")
		t.eq(Config.Shop.Title, "Pumpkin Shop")
		t.eq(Config.Custom.Heights.WitchWanda, nil)
		t.eq(Config.Custom.Heights.BooGuide, nil)
	end)

	t.test("save template has the v2 fields", function()
		local template = Config.Data.Template
		t.eq(type(template.EasterEggs), "table")
		t.eq(next(template.EasterEggs), nil, "EasterEggs starts empty")
		t.eq(template.Parkour.Best, 0)
		t.eq(template.Parkour.LastReward, 0)
		t.eq(template.Parkour.Runs, 0)
		t.eq(template.Minigames.CandyRushWins, 0)
		t.eq(template.Minigames.WebScourBest, 0)
		t.eq(template.Crates.Opened, 0)
		t.eq(template.Stats.HideSeekTags, 0)
		t.eq(template.Stats.HideSeekWins, 0)
		t.eq(template.Stats.ScareMazeEscapes, 0)
	end)

	t.test("lobby zones sit on the plaza and face the middle", function()
		local ground = Config.Hub.Center.Y + 1
		for name, zone in Config.Lobby.Zones do
			local cf = Lobby.ZoneCFrame(name)
			t.near(cf.Position, Config.Hub.Center + Vector3.new(zone.Offset.X, 1, zone.Offset.Z))
			t.near(cf.Position.Y, ground)
			local toCenter = Vector3.new(Config.Hub.Center.X, ground, Config.Hub.Center.Z)
				- cf.Position
			t.near(cf.LookVector, toCenter.Unit, 1e-3, name .. " faces the middle")
			t.ok(Lobby.InZone(cf.Position, name), name .. " contains its own centre")
		end
		-- ReadyArea: centre (0, 1, 48), 22 wide, 18 deep, facing -Z.
		t.ok(Lobby.InZone(Vector3.new(10, 1, 48), "ReadyArea"))
		t.ok(not Lobby.InZone(Vector3.new(12, 1, 48), "ReadyArea"))
		t.ok(Lobby.InZone(Vector3.new(12, 1, 48), "ReadyArea", 2), "margin")
		t.ok(not Lobby.InZone(Vector3.new(0, 1, 58), "ReadyArea"))
		t.ok(Lobby.InZone(Vector3.new(0, 200, 48), "ReadyArea"), "no Height = any height")
		-- Parkour has a Height of 60.
		t.ok(Lobby.InZone(Vector3.new(0, 30, -80), "Parkour"))
		t.ok(not Lobby.InZone(Vector3.new(0, 70, -80), "Parkour"))
		t.near(Lobby.ZoneSize("Parkour"), Vector3.new(60, 60, 44))
		t.near(Lobby.ZoneSize("Shop"), Vector3.new(22, 0, 18))
		t.errors(function()
			Lobby.ZoneCFrame("NoSuchZone")
		end)
	end)

	t.test("tags are plain strings named after themselves", function()
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
			t.eq(Tags[name], name)
		end
		for key, value in Tags do
			t.eq(value, key)
		end
	end)
end
