--!strict
--[[
	GOBLIN MARKET CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (GoblinMarketCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "GoblinMarket_CoinCounter",
		Name = "Coin Counter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 170, 60),
			ArmsColor = rgb(200, 60, 50),
			LegsColor = rgb(150, 90, 50),
			Material = M.Fabric,
			Accent = { Color = rgb(120, 70, 140), Pattern = "Gloves" },
		},
	},
	{
		Id = "GoblinMarket_TrinketSeller",
		Name = "Trinket Seller",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 80, 50),
			ArmsColor = rgb(200, 60, 50),
			LegsColor = rgb(90, 120, 60),
			Material = M.Leather,
			Accent = { Color = rgb(90, 120, 60), Pattern = "Wraps" },
		},
	},
	{
		Id = "GoblinMarket_MushroomMonger",
		Name = "Mushroom Monger",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 190, 60),
			ArmsColor = rgb(90, 120, 60),
			LegsColor = rgb(120, 80, 50),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(150, 90, 50), Pattern = { "Buttons", "Web" } },
		},
	},
	{
		Id = "GoblinMarket_PotionPeddler",
		Name = "Potion Peddler",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(200, 60, 50),
			Material = M.Cobblestone,
			Accent = { Color = rgb(110, 170, 60), Pattern = "Patches" },
		},
	},
	{
		Id = "GoblinMarket_RugMerchant",
		Name = "Rug Merchant",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 70, 140),
			ArmsColor = rgb(110, 170, 60),
			LegsColor = rgb(200, 60, 50),
			Material = M.Fabric,
			Accent = { Color = rgb(120, 80, 50), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "GoblinMarket_BagCarrier",
		Name = "Bag Carrier",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 120, 60),
			ArmsColor = rgb(110, 170, 60),
			LegsColor = rgb(230, 190, 60),
			Material = M.Leather,
			Accent = { Color = rgb(230, 190, 60), Pattern = "Heart" },
		},
	},
	{
		Id = "GoblinMarket_LanternHawker",
		Name = "Lantern Hawker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 90, 50),
			ArmsColor = rgb(230, 190, 60),
			LegsColor = rgb(90, 120, 60),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(200, 60, 50), Pattern = "Collar" },
		},
	},
	{
		Id = "GoblinMarket_JunkTrader",
		Name = "Junk Trader",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(110, 170, 60),
			Material = M.Cobblestone,
			Accent = { Color = rgb(120, 70, 140), Pattern = "Boots" },
		},
	},
	{
		Id = "GoblinMarket_MapSeller",
		Name = "Map Seller",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 80, 50),
			ArmsColor = rgb(120, 70, 140),
			LegsColor = rgb(110, 170, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(90, 120, 60), Pattern = { "Spots", "Star" } },
		},
	},
	{
		Id = "GoblinMarket_Haggler",
		Name = "Haggler",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 190, 60),
			ArmsColor = rgb(120, 70, 140),
			LegsColor = rgb(150, 90, 50),
			Material = M.Leather,
			Accent = { Color = rgb(150, 90, 50), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "GoblinMarket_SpiceGoblin",
		Name = "Spice Goblin",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 60, 50),
			ArmsColor = rgb(150, 90, 50),
			LegsColor = rgb(230, 190, 60),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(110, 170, 60), Pattern = "Sash" },
		},
	},
	{
		Id = "GoblinMarket_BellRinger",
		Name = "Bell Ringer",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(120, 70, 140),
			Material = M.Cobblestone,
			Accent = { Color = rgb(120, 80, 50), Pattern = { "Tail", "Belt" } },
		},
	},
	{
		Id = "GoblinMarket_StallKeeper",
		Name = "Stall Keeper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 120, 60),
			ArmsColor = rgb(120, 80, 50),
			LegsColor = rgb(120, 70, 140),
			Material = M.Fabric,
			Accent = { Color = rgb(230, 190, 60), Pattern = "Star" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "GoblinMarket_GoblinMerchant",
		Name = "Goblin Merchant",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(150, 90, 50),
			ArmsColor = rgb(230, 190, 60),
			LegsColor = rgb(90, 120, 60),
			Accent = { Color = rgb(200, 60, 50), Pattern = { "Cuffs", "Cape" } },
			Head = "GoblinHead",
			HeadColor = rgb(230, 190, 60),
			HeadColor2 = rgb(90, 120, 60),
			GlowColor = rgb(110, 170, 60),
		},
	},
	{
		Id = "GoblinMarket_ToadstoolTrader",
		Name = "Toadstool Trader",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(110, 170, 60),
			ArmsColor = rgb(200, 60, 50),
			LegsColor = rgb(150, 90, 50),
			Accent = {
				Color = rgb(120, 70, 140),
				Material = M.Neon,
				Pattern = { "Stripes", "Collar" },
			},
			Head = "ToadstoolHead",
			HeadColor = rgb(120, 70, 140),
			HeadColor2 = rgb(110, 170, 60),
			GlowColor = rgb(230, 190, 60),
		},
	},
	{
		Id = "GoblinMarket_GoblinThief",
		Name = "Goblin Thief",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(120, 80, 50),
			Accent = { Color = rgb(90, 120, 60), Pattern = "Belly" },
			Head = "GoblinHead",
			HeadColor = rgb(150, 90, 50),
			HeadColor2 = rgb(230, 190, 60),
			GlowColor = rgb(120, 70, 140),
		},
	},
	{
		Id = "GoblinMarket_MushroomGoblin",
		Name = "Mushroom Goblin",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(230, 190, 60),
			ArmsColor = rgb(90, 120, 60),
			LegsColor = rgb(120, 80, 50),
			Accent = { Color = rgb(150, 90, 50), Pattern = { "Stitches", "Wings" } },
			Head = "ToadstoolHead",
			HeadColor = rgb(120, 80, 50),
			HeadColor2 = rgb(120, 70, 140),
			GlowColor = rgb(150, 90, 50),
		},
	},
	{
		Id = "GoblinMarket_MarketBoss",
		Name = "Market Boss",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(200, 60, 50),
			ArmsColor = rgb(150, 90, 50),
			LegsColor = rgb(230, 190, 60),
			Accent = { Color = rgb(110, 170, 60), Pattern = { "Cape", "Cuffs" } },
			Head = "GoblinHead",
			HeadColor = rgb(200, 60, 50),
			HeadColor2 = rgb(150, 90, 50),
			GlowColor = rgb(120, 80, 50),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "GoblinMarket_GoblinKing",
		Name = "Goblin King",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(150, 90, 50),
			ArmsColor = rgb(200, 60, 50),
			LegsColor = rgb(110, 170, 60),
			Accent = { Color = rgb(200, 60, 50), Pattern = "Gloves" },
			Head = "GoblinHead",
			HeadColor = rgb(90, 120, 60),
			HeadColor2 = rgb(110, 170, 60),
			GlowColor = rgb(120, 70, 140),
			Glow = { Color = rgb(120, 70, 140), Brightness = 1.6 },
			Aura = { Kind = "Sparkles", Color = rgb(120, 70, 140), Color2 = rgb(120, 80, 50) },
		},
	},
	{
		Id = "GoblinMarket_ToadstoolSage",
		Name = "Toadstool Sage",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(110, 170, 60),
			ArmsColor = rgb(120, 70, 140),
			LegsColor = rgb(120, 80, 50),
			Accent = { Color = rgb(120, 70, 140), Pattern = { "Wraps", "Bones" } },
			Head = "ToadstoolHead",
			HeadColor = rgb(120, 80, 50),
			HeadColor2 = rgb(200, 60, 50),
			GlowColor = rgb(110, 170, 60),
			Glow = { Color = rgb(110, 170, 60), Brightness = 1.8 },
			Aura = { Kind = "Embers", Color = rgb(110, 170, 60), Color2 = rgb(120, 70, 140) },
		},
	},
	{
		Id = "GoblinMarket_NightMarketMaster",
		Name = "Night Market Master",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(120, 80, 50),
			ArmsColor = rgb(90, 120, 60),
			LegsColor = rgb(230, 190, 60),
			Accent = { Color = rgb(90, 120, 60), Pattern = { "Buttons", "Web" } },
			Head = "GoblinHead",
			HeadColor = rgb(120, 70, 140),
			HeadColor2 = rgb(150, 90, 50),
			GlowColor = rgb(200, 60, 50),
			Glow = { Color = rgb(200, 60, 50), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(200, 60, 50), Color2 = rgb(110, 170, 60) },
		},
	},
} :: { any }
