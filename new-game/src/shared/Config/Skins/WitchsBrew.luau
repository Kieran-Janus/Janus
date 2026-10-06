--!strict
--[[
	WITCH'S BREW CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (WitchsBrewCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "WitchsBrew_BroomRider",
		Name = "Broom Rider",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(100, 40, 140),
			ArmsColor = rgb(80, 80, 90),
			LegsColor = rgb(240, 230, 150),
			Material = M.Fabric,
			Accent = { Color = rgb(240, 90, 200), Pattern = "Sash" },
		},
	},
	{
		Id = "WitchsBrew_SpellBook",
		Name = "Spell Book",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 240, 90),
			ArmsColor = rgb(80, 80, 90),
			LegsColor = rgb(250, 140, 40),
			Accent = { Color = rgb(250, 140, 40), Pattern = "Tail" },
		},
	},
	{
		Id = "WitchsBrew_EyeofNewt",
		Name = "Eye of Newt",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 25, 35),
			ArmsColor = rgb(250, 140, 40),
			LegsColor = rgb(110, 240, 90),
			Material = M.Fabric,
			Accent = { Color = rgb(240, 230, 150), Pattern = { "Star", "Collar" } },
		},
	},
	{
		Id = "WitchsBrew_BubblingPot",
		Name = "Bubbling Pot",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(80, 80, 90),
			Material = M.Slate,
			Accent = { Color = rgb(100, 40, 140), Pattern = "Cuffs" },
		},
	},
	{
		Id = "WitchsBrew_HexHelper",
		Name = "Hex Helper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 90, 200),
			ArmsColor = rgb(100, 40, 140),
			LegsColor = rgb(80, 80, 90),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 240, 90), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "WitchsBrew_MoonHerb",
		Name = "Moon Herb",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(250, 140, 40),
			ArmsColor = rgb(100, 40, 140),
			LegsColor = rgb(30, 25, 35),
			Accent = { Color = rgb(30, 25, 35), Pattern = { "Belly", "Cuffs" } },
		},
	},
	{
		Id = "WitchsBrew_ToadTonic",
		Name = "Toad Tonic",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 230, 150),
			ArmsColor = rgb(30, 25, 35),
			LegsColor = rgb(250, 140, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(80, 80, 90), Pattern = "Stitches" },
		},
	},
	{
		Id = "WitchsBrew_WandWaver",
		Name = "Wand Waver",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(100, 40, 140),
			Material = M.Slate,
			Accent = { Color = rgb(240, 90, 200), Pattern = "Cape" },
		},
	},
	{
		Id = "WitchsBrew_BlackCandle",
		Name = "Black Candle",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 240, 90),
			ArmsColor = rgb(240, 90, 200),
			LegsColor = rgb(100, 40, 140),
			Material = M.Fabric,
			Accent = { Color = rgb(250, 140, 40), Pattern = { "Web", "Gloves" } },
		},
	},
	{
		Id = "WitchsBrew_PotionBottle",
		Name = "Potion Bottle",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 25, 35),
			ArmsColor = rgb(240, 90, 200),
			LegsColor = rgb(240, 230, 150),
			Accent = { Color = rgb(240, 230, 150), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "WitchsBrew_CauldronStirrer",
		Name = "Cauldron Stirrer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(80, 80, 90),
			ArmsColor = rgb(240, 230, 150),
			LegsColor = rgb(30, 25, 35),
			Material = M.Fabric,
			Accent = { Color = rgb(100, 40, 140), Pattern = "Gloves" },
		},
	},
	{
		Id = "WitchsBrew_StarCharm",
		Name = "Star Charm",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(240, 90, 200),
			Material = M.Slate,
			Accent = { Color = rgb(110, 240, 90), Pattern = { "Wraps", "Boots" } },
		},
	},
	{
		Id = "WitchsBrew_CrystalGazer",
		Name = "Crystal Gazer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(250, 140, 40),
			ArmsColor = rgb(110, 240, 90),
			LegsColor = rgb(240, 90, 200),
			Material = M.Fabric,
			Accent = { Color = rgb(30, 25, 35), Pattern = "Buttons" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "WitchsBrew_WitchApprentice",
		Name = "Witch Apprentice",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 230, 150),
			ArmsColor = rgb(30, 25, 35),
			LegsColor = rgb(250, 140, 40),
			Accent = { Color = rgb(80, 80, 90), Pattern = { "Patches", "Heart" } },
			Head = "WitchHood",
			HeadColor = rgb(30, 25, 35),
			HeadColor2 = rgb(250, 140, 40),
			GlowColor = rgb(100, 40, 140),
		},
	},
	{
		Id = "WitchsBrew_CauldronKeeper",
		Name = "Cauldron Keeper",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(100, 40, 140),
			ArmsColor = rgb(80, 80, 90),
			LegsColor = rgb(240, 230, 150),
			Accent = {
				Color = rgb(240, 90, 200),
				Material = M.Neon,
				Pattern = { "Wings", "Stripes" },
			},
			Head = "CauldronHat",
			HeadColor = rgb(240, 90, 200),
			HeadColor2 = rgb(100, 40, 140),
			GlowColor = rgb(30, 25, 35),
		},
	},
	{
		Id = "WitchsBrew_ElixirMaster",
		Name = "Elixir Master",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(110, 240, 90),
			Accent = { Color = rgb(250, 140, 40), Pattern = { "Heart", "Patches" } },
			Head = "PotionHead",
			HeadColor = rgb(240, 230, 150),
			HeadColor2 = rgb(30, 25, 35),
			GlowColor = rgb(240, 90, 200),
		},
	},
	{
		Id = "WitchsBrew_HexWitch",
		Name = "Hex Witch",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(30, 25, 35),
			ArmsColor = rgb(250, 140, 40),
			LegsColor = rgb(110, 240, 90),
			Accent = { Color = rgb(240, 230, 150), Pattern = { "Collar", "Star" } },
			Head = "WitchHood",
			HeadColor = rgb(110, 240, 90),
			HeadColor2 = rgb(240, 90, 200),
			GlowColor = rgb(240, 230, 150),
		},
	},
	{
		Id = "WitchsBrew_MoonWitch",
		Name = "Moon Witch",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(80, 80, 90),
			ArmsColor = rgb(240, 230, 150),
			LegsColor = rgb(30, 25, 35),
			Accent = { Color = rgb(100, 40, 140), Pattern = { "Boots", "Wraps" } },
			Head = "CauldronHat",
			HeadColor = rgb(80, 80, 90),
			HeadColor2 = rgb(240, 230, 150),
			GlowColor = rgb(110, 240, 90),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "WitchsBrew_GrandWitch",
		Name = "Grand Witch",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(240, 230, 150),
			ArmsColor = rgb(80, 80, 90),
			LegsColor = rgb(100, 40, 140),
			Accent = { Color = rgb(80, 80, 90), Pattern = { "Sash", "Spots" } },
			Head = "WitchHood",
			HeadColor = rgb(250, 140, 40),
			HeadColor2 = rgb(100, 40, 140),
			GlowColor = rgb(240, 90, 200),
			Glow = { Color = rgb(240, 90, 200), Brightness = 1.6 },
			Aura = { Kind = "Sparkles", Color = rgb(240, 90, 200), Color2 = rgb(110, 240, 90) },
		},
	},
	{
		Id = "WitchsBrew_BrewMistress",
		Name = "Brew Mistress",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(100, 40, 140),
			ArmsColor = rgb(240, 90, 200),
			LegsColor = rgb(110, 240, 90),
			Accent = { Color = rgb(240, 90, 200), Pattern = { "Tail", "Cape" } },
			Head = "CauldronHat",
			HeadColor = rgb(110, 240, 90),
			HeadColor2 = rgb(80, 80, 90),
			GlowColor = rgb(100, 40, 140),
			Glow = { Color = rgb(100, 40, 140), Brightness = 1.8 },
			Aura = { Kind = "Bubbles", Color = rgb(100, 40, 140), Color2 = rgb(240, 90, 200) },
		},
	},
	{
		Id = "WitchsBrew_CovenQueen",
		Name = "Coven Queen",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(110, 240, 90),
			ArmsColor = rgb(250, 140, 40),
			LegsColor = rgb(30, 25, 35),
			Accent = { Color = rgb(250, 140, 40), Pattern = { "Star", "Collar" } },
			Head = "PotionHead",
			HeadColor = rgb(240, 90, 200),
			HeadColor2 = rgb(240, 230, 150),
			GlowColor = rgb(80, 80, 90),
			Glow = { Color = rgb(80, 80, 90), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(80, 80, 90), Color2 = rgb(100, 40, 140) },
		},
	},
} :: { any }
