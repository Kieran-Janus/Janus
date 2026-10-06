--!strict
--[[
	MUMMY TOMB CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (MummyTombCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "MummyTomb_TombSweeper",
		Name = "Tomb Sweeper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(225, 210, 170),
			ArmsColor = rgb(60, 190, 180),
			LegsColor = rgb(190, 100, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(210, 180, 120), Pattern = "Gloves" },
		},
	},
	{
		Id = "MummyTomb_SandWanderer",
		Name = "Sand Wanderer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 180, 60),
			ArmsColor = rgb(60, 190, 180),
			LegsColor = rgb(30, 25, 30),
			Material = M.Sandstone,
			Accent = { Color = rgb(30, 25, 30), Pattern = "Wraps" },
		},
	},
	{
		Id = "MummyTomb_ScarabKeeper",
		Name = "Scarab Keeper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 70, 170),
			ArmsColor = rgb(30, 25, 30),
			LegsColor = rgb(230, 180, 60),
			Material = M.Foil,
			Accent = { Color = rgb(190, 100, 60), Pattern = { "Buttons", "Sash" } },
		},
	},
	{
		Id = "MummyTomb_LinenWrap",
		Name = "Linen Wrap",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(60, 190, 180),
			Material = M.Limestone,
			Accent = { Color = rgb(225, 210, 170), Pattern = "Patches" },
		},
	},
	{
		Id = "MummyTomb_PyramidPorter",
		Name = "Pyramid Porter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(210, 180, 120),
			ArmsColor = rgb(225, 210, 170),
			LegsColor = rgb(60, 190, 180),
			Material = M.Fabric,
			Accent = { Color = rgb(230, 180, 60), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "MummyTomb_DustyScribe",
		Name = "Dusty Scribe",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 25, 30),
			ArmsColor = rgb(225, 210, 170),
			LegsColor = rgb(40, 70, 170),
			Material = M.Sandstone,
			Accent = { Color = rgb(40, 70, 170), Pattern = { "Heart", "Cape" } },
		},
	},
	{
		Id = "MummyTomb_TorchBearer",
		Name = "Torch Bearer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 100, 60),
			ArmsColor = rgb(40, 70, 170),
			LegsColor = rgb(30, 25, 30),
			Material = M.Foil,
			Accent = { Color = rgb(60, 190, 180), Pattern = "Collar" },
		},
	},
	{
		Id = "MummyTomb_GoldenScarab",
		Name = "Golden Scarab",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(225, 210, 170),
			Material = M.Limestone,
			Accent = { Color = rgb(210, 180, 120), Pattern = "Boots" },
		},
	},
	{
		Id = "MummyTomb_LotusDancer",
		Name = "Lotus Dancer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 180, 60),
			ArmsColor = rgb(210, 180, 120),
			LegsColor = rgb(225, 210, 170),
			Material = M.Fabric,
			Accent = { Color = rgb(30, 25, 30), Pattern = { "Spots", "Wings" } },
		},
	},
	{
		Id = "MummyTomb_SphinxGuard",
		Name = "Sphinx Guard",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 70, 170),
			ArmsColor = rgb(210, 180, 120),
			LegsColor = rgb(190, 100, 60),
			Material = M.Sandstone,
			Accent = { Color = rgb(190, 100, 60), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "MummyTomb_HieroglyphKid",
		Name = "Hieroglyph Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(60, 190, 180),
			ArmsColor = rgb(190, 100, 60),
			LegsColor = rgb(40, 70, 170),
			Material = M.Foil,
			Accent = { Color = rgb(225, 210, 170), Pattern = "Sash" },
		},
	},
	{
		Id = "MummyTomb_CanopicCollector",
		Name = "Canopic Collector",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(210, 180, 120),
			Material = M.Limestone,
			Accent = { Color = rgb(230, 180, 60), Pattern = "Tail" },
		},
	},
	{
		Id = "MummyTomb_DesertNomad",
		Name = "Desert Nomad",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 25, 30),
			ArmsColor = rgb(230, 180, 60),
			LegsColor = rgb(210, 180, 120),
			Material = M.Fabric,
			Accent = { Color = rgb(40, 70, 170), Pattern = "Star" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "MummyTomb_PharaohsHeir",
		Name = "Pharaoh's Heir",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(190, 100, 60),
			ArmsColor = rgb(40, 70, 170),
			LegsColor = rgb(30, 25, 30),
			Accent = { Color = rgb(60, 190, 180), Pattern = { "Cuffs", "Bones" } },
			Head = "MummyHead",
			HeadColor = rgb(40, 70, 170),
			HeadColor2 = rgb(30, 25, 30),
			GlowColor = rgb(225, 210, 170),
		},
	},
	{
		Id = "MummyTomb_WrappedWanderer",
		Name = "Wrapped Wanderer",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(225, 210, 170),
			ArmsColor = rgb(60, 190, 180),
			LegsColor = rgb(190, 100, 60),
			Accent = {
				Color = rgb(210, 180, 120),
				Material = M.Neon,
				Pattern = { "Stripes", "Web" },
			},
			Head = "PharaohHead",
			HeadColor = rgb(210, 180, 120),
			HeadColor2 = rgb(225, 210, 170),
			GlowColor = rgb(40, 70, 170),
		},
	},
	{
		Id = "MummyTomb_TombRaiderGhost",
		Name = "Tomb Raider Ghost",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(230, 180, 60),
			Accent = { Color = rgb(30, 25, 30), Pattern = { "Belly", "Boots" } },
			Head = "MummyHead",
			HeadColor = rgb(190, 100, 60),
			HeadColor2 = rgb(40, 70, 170),
			GlowColor = rgb(210, 180, 120),
		},
	},
	{
		Id = "MummyTomb_CursedPriestess",
		Name = "Cursed Priestess",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(40, 70, 170),
			ArmsColor = rgb(30, 25, 30),
			LegsColor = rgb(230, 180, 60),
			Accent = { Color = rgb(190, 100, 60), Pattern = "Stitches" },
			Head = "PharaohHead",
			HeadColor = rgb(230, 180, 60),
			HeadColor2 = rgb(210, 180, 120),
			GlowColor = rgb(190, 100, 60),
		},
	},
	{
		Id = "MummyTomb_SandSorcerer",
		Name = "Sand Sorcerer",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(60, 190, 180),
			ArmsColor = rgb(190, 100, 60),
			LegsColor = rgb(40, 70, 170),
			Accent = { Color = rgb(225, 210, 170), Pattern = { "Cape", "Heart" } },
			Head = "MummyHead",
			HeadColor = rgb(60, 190, 180),
			HeadColor2 = rgb(190, 100, 60),
			GlowColor = rgb(230, 180, 60),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "MummyTomb_GoldenPharaoh",
		Name = "Golden Pharaoh",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(190, 100, 60),
			ArmsColor = rgb(60, 190, 180),
			LegsColor = rgb(225, 210, 170),
			Accent = { Color = rgb(60, 190, 180), Pattern = { "Gloves", "Star" } },
			Head = "PharaohHead",
			HeadColor = rgb(30, 25, 30),
			HeadColor2 = rgb(225, 210, 170),
			GlowColor = rgb(210, 180, 120),
			Glow = { Color = rgb(210, 180, 120), Brightness = 1.6 },
			Aura = { Kind = "Sparkles", Color = rgb(210, 180, 120), Color2 = rgb(230, 180, 60) },
		},
	},
	{
		Id = "MummyTomb_MummyEmperor",
		Name = "Mummy Emperor",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(225, 210, 170),
			ArmsColor = rgb(210, 180, 120),
			LegsColor = rgb(230, 180, 60),
			Accent = { Color = rgb(210, 180, 120), Pattern = "Wraps" },
			Head = "MummyHead",
			HeadColor = rgb(230, 180, 60),
			HeadColor2 = rgb(60, 190, 180),
			GlowColor = rgb(225, 210, 170),
			Glow = { Color = rgb(225, 210, 170), Brightness = 1.8 },
			Aura = { Kind = "Smoke", Color = rgb(225, 210, 170), Color2 = rgb(210, 180, 120) },
		},
	},
	{
		Id = "MummyTomb_SunGodsWrath",
		Name = "Sun God's Wrath",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(230, 180, 60),
			ArmsColor = rgb(30, 25, 30),
			LegsColor = rgb(40, 70, 170),
			Accent = { Color = rgb(30, 25, 30), Pattern = { "Buttons", "Sash" } },
			Head = "PharaohHead",
			HeadColor = rgb(210, 180, 120),
			HeadColor2 = rgb(190, 100, 60),
			GlowColor = rgb(60, 190, 180),
			Glow = { Color = rgb(60, 190, 180), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(60, 190, 180), Color2 = rgb(225, 210, 170) },
		},
	},
} :: { any }
