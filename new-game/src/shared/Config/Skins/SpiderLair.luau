--!strict
--[[
	SPIDER LAIR CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (SpiderLairCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "SpiderLair_WebWeaver",
		Name = "Web Weaver",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 230, 240),
			ArmsColor = rgb(210, 30, 40),
			LegsColor = rgb(220, 150, 40),
			Accent = { Color = rgb(120, 60, 170), Pattern = "Belly" },
		},
	},
	{
		Id = "SpiderLair_SilkSpinner",
		Name = "Silk Spinner",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(25, 20, 30),
			ArmsColor = rgb(210, 30, 40),
			LegsColor = rgb(190, 190, 200),
			Material = M.Fabric,
			Accent = { Color = rgb(190, 190, 200), Pattern = "Stitches" },
		},
	},
	{
		Id = "SpiderLair_DewDrop",
		Name = "Dew Drop",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(130, 220, 60),
			ArmsColor = rgb(190, 190, 200),
			LegsColor = rgb(25, 20, 30),
			Material = M.Foil,
			Accent = { Color = rgb(220, 150, 40), Pattern = { "Cape", "Gloves" } },
		},
	},
	{
		Id = "SpiderLair_EightLegs",
		Name = "Eight Legs",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(210, 30, 40),
			Material = M.Basalt,
			Accent = { Color = rgb(230, 230, 240), Pattern = "Web" },
		},
	},
	{
		Id = "SpiderLair_CocoonKid",
		Name = "Cocoon Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 60, 170),
			ArmsColor = rgb(230, 230, 240),
			LegsColor = rgb(210, 30, 40),
			Accent = { Color = rgb(25, 20, 30), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "SpiderLair_FlyCatcher",
		Name = "Fly Catcher",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 190, 200),
			ArmsColor = rgb(230, 230, 240),
			LegsColor = rgb(130, 220, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(130, 220, 60), Pattern = { "Gloves", "Boots" } },
		},
	},
	{
		Id = "SpiderLair_TarantulaFan",
		Name = "Tarantula Fan",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(220, 150, 40),
			ArmsColor = rgb(130, 220, 60),
			LegsColor = rgb(190, 190, 200),
			Material = M.Foil,
			Accent = { Color = rgb(210, 30, 40), Pattern = "Wraps" },
		},
	},
	{
		Id = "SpiderLair_DaddyLonglegs",
		Name = "Daddy Longlegs",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(230, 230, 240),
			Material = M.Basalt,
			Accent = { Color = rgb(120, 60, 170), Pattern = "Buttons" },
		},
	},
	{
		Id = "SpiderLair_WebWalker",
		Name = "Web Walker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(25, 20, 30),
			ArmsColor = rgb(120, 60, 170),
			LegsColor = rgb(230, 230, 240),
			Accent = { Color = rgb(190, 190, 200), Pattern = { "Patches", "Stripes" } },
		},
	},
	{
		Id = "SpiderLair_VenomSipper",
		Name = "Venom Sipper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(130, 220, 60),
			ArmsColor = rgb(120, 60, 170),
			LegsColor = rgb(220, 150, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(220, 150, 40), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "SpiderLair_ThreadKnotter",
		Name = "Thread Knotter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(210, 30, 40),
			ArmsColor = rgb(220, 150, 40),
			LegsColor = rgb(130, 220, 60),
			Material = M.Foil,
			Accent = { Color = rgb(230, 230, 240), Pattern = "Heart" },
		},
	},
	{
		Id = "SpiderLair_SpiderNanny",
		Name = "Spider Nanny",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(120, 60, 170),
			Material = M.Basalt,
			Accent = { Color = rgb(25, 20, 30), Pattern = { "Collar", "Wraps" } },
		},
	},
	{
		Id = "SpiderLair_CrawlyCutie",
		Name = "Crawly Cutie",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 190, 200),
			ArmsColor = rgb(25, 20, 30),
			LegsColor = rgb(120, 60, 170),
			Accent = { Color = rgb(130, 220, 60), Pattern = "Boots" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "SpiderLair_WidowQueen",
		Name = "Widow Queen",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(220, 150, 40),
			ArmsColor = rgb(130, 220, 60),
			LegsColor = rgb(190, 190, 200),
			Accent = { Color = rgb(210, 30, 40), Pattern = { "Spots", "Belt" } },
			Head = "SpiderCrown",
			HeadColor = rgb(130, 220, 60),
			HeadColor2 = rgb(190, 190, 200),
			GlowColor = rgb(230, 230, 240),
		},
	},
	{
		Id = "SpiderLair_VenomSpider",
		Name = "Venom Spider",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(230, 230, 240),
			ArmsColor = rgb(210, 30, 40),
			LegsColor = rgb(220, 150, 40),
			Accent = {
				Color = rgb(120, 60, 170),
				Material = M.Neon,
				Pattern = { "Bones", "Spots" },
			},
			Head = "EyeballHead",
			HeadColor = rgb(120, 60, 170),
			HeadColor2 = rgb(230, 230, 240),
			GlowColor = rgb(130, 220, 60),
		},
	},
	{
		Id = "SpiderLair_WebWitch",
		Name = "Web Witch",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(25, 20, 30),
			Accent = { Color = rgb(190, 190, 200), Pattern = { "Sash", "Cape" } },
			Head = "SpiderCrown",
			HeadColor = rgb(220, 150, 40),
			HeadColor2 = rgb(130, 220, 60),
			GlowColor = rgb(120, 60, 170),
		},
	},
	{
		Id = "SpiderLair_ArachnoKnight",
		Name = "Arachno Knight",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(130, 220, 60),
			ArmsColor = rgb(190, 190, 200),
			LegsColor = rgb(25, 20, 30),
			Accent = { Color = rgb(220, 150, 40), Pattern = { "Tail", "Collar" } },
			Head = "EyeballHead",
			HeadColor = rgb(25, 20, 30),
			HeadColor2 = rgb(120, 60, 170),
			GlowColor = rgb(220, 150, 40),
		},
	},
	{
		Id = "SpiderLair_SilkShadow",
		Name = "Silk Shadow",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(210, 30, 40),
			ArmsColor = rgb(220, 150, 40),
			LegsColor = rgb(130, 220, 60),
			Accent = { Color = rgb(230, 230, 240), Pattern = { "Star", "Belly" } },
			Head = "SpiderCrown",
			HeadColor = rgb(210, 30, 40),
			HeadColor2 = rgb(220, 150, 40),
			GlowColor = rgb(25, 20, 30),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "SpiderLair_SpiderEmpress",
		Name = "Spider Empress",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(220, 150, 40),
			ArmsColor = rgb(210, 30, 40),
			LegsColor = rgb(230, 230, 240),
			Accent = { Color = rgb(210, 30, 40), Pattern = { "Belly", "Buttons" } },
			Head = "SpiderCrown",
			HeadColor = rgb(190, 190, 200),
			HeadColor2 = rgb(230, 230, 240),
			GlowColor = rgb(120, 60, 170),
			Glow = { Color = rgb(120, 60, 170), Brightness = 1.6 },
			Aura = { Kind = "Smoke", Color = rgb(120, 60, 170), Color2 = rgb(25, 20, 30) },
		},
	},
	{
		Id = "SpiderLair_VenomLord",
		Name = "Venom Lord",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(230, 230, 240),
			ArmsColor = rgb(120, 60, 170),
			LegsColor = rgb(25, 20, 30),
			Accent = { Color = rgb(120, 60, 170), Pattern = { "Stitches", "Tail" } },
			Head = "EyeballHead",
			HeadColor = rgb(25, 20, 30),
			HeadColor2 = rgb(210, 30, 40),
			GlowColor = rgb(230, 230, 240),
			Glow = { Color = rgb(230, 230, 240), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(230, 230, 240), Color2 = rgb(120, 60, 170) },
		},
	},
	{
		Id = "SpiderLair_WebTitan",
		Name = "Web Titan",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(25, 20, 30),
			ArmsColor = rgb(190, 190, 200),
			LegsColor = rgb(130, 220, 60),
			Accent = { Color = rgb(190, 190, 200), Pattern = { "Cape", "Gloves" } },
			Head = "SpiderCrown",
			HeadColor = rgb(120, 60, 170),
			HeadColor2 = rgb(220, 150, 40),
			GlowColor = rgb(210, 30, 40),
			Glow = { Color = rgb(210, 30, 40), Brightness = 2.0 },
			Aura = { Kind = "Embers", Color = rgb(210, 30, 40), Color2 = rgb(230, 230, 240) },
		},
	},
} :: { any }
