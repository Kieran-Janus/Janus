--!strict
--[[
	WEREWOLF WOODS CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (WerewolfWoodsCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "WerewolfWoods_LumberjackPup",
		Name = "Lumberjack Pup",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 85, 60),
			ArmsColor = rgb(210, 215, 230),
			LegsColor = rgb(230, 160, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(160, 40, 40), Pattern = "Belly" },
		},
	},
	{
		Id = "WerewolfWoods_MoonlitHiker",
		Name = "Moonlit Hiker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(130, 130, 135),
			ArmsColor = rgb(210, 215, 230),
			LegsColor = rgb(80, 60, 45),
			Material = M.Wood,
			Accent = { Color = rgb(80, 60, 45), Pattern = "Stitches" },
		},
	},
	{
		Id = "WerewolfWoods_PineProwler",
		Name = "Pine Prowler",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 90, 50),
			ArmsColor = rgb(80, 60, 45),
			LegsColor = rgb(130, 130, 135),
			Accent = { Color = rgb(230, 160, 40), Pattern = { "Cape", "Wings" } },
		},
	},
	{
		Id = "WerewolfWoods_FlannelHowler",
		Name = "Flannel Howler",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(210, 215, 230),
			Material = M.Grass,
			Accent = { Color = rgb(120, 85, 60), Pattern = "Web" },
		},
	},
	{
		Id = "WerewolfWoods_CampfireScout",
		Name = "Campfire Scout",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(160, 40, 40),
			ArmsColor = rgb(120, 85, 60),
			LegsColor = rgb(210, 215, 230),
			Material = M.Fabric,
			Accent = { Color = rgb(130, 130, 135), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "WerewolfWoods_BarkBiter",
		Name = "Bark Biter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(80, 60, 45),
			ArmsColor = rgb(120, 85, 60),
			LegsColor = rgb(40, 90, 50),
			Material = M.Wood,
			Accent = { Color = rgb(40, 90, 50), Pattern = { "Gloves", "Tail" } },
		},
	},
	{
		Id = "WerewolfWoods_TrailTracker",
		Name = "Trail Tracker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 160, 40),
			ArmsColor = rgb(40, 90, 50),
			LegsColor = rgb(80, 60, 45),
			Accent = { Color = rgb(210, 215, 230), Pattern = "Wraps" },
		},
	},
	{
		Id = "WerewolfWoods_MossyRanger",
		Name = "Mossy Ranger",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(120, 85, 60),
			Material = M.Grass,
			Accent = { Color = rgb(160, 40, 40), Pattern = "Buttons" },
		},
	},
	{
		Id = "WerewolfWoods_BerryForager",
		Name = "Berry Forager",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(130, 130, 135),
			ArmsColor = rgb(160, 40, 40),
			LegsColor = rgb(120, 85, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(80, 60, 45), Pattern = { "Patches", "Web" } },
		},
	},
	{
		Id = "WerewolfWoods_MidnightCamper",
		Name = "Midnight Camper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 90, 50),
			ArmsColor = rgb(160, 40, 40),
			LegsColor = rgb(230, 160, 40),
			Material = M.Wood,
			Accent = { Color = rgb(230, 160, 40), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "WerewolfWoods_SilverFang",
		Name = "Silver Fang",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(210, 215, 230),
			ArmsColor = rgb(230, 160, 40),
			LegsColor = rgb(40, 90, 50),
			Accent = { Color = rgb(120, 85, 60), Pattern = "Heart" },
		},
	},
	{
		Id = "WerewolfWoods_HollowLog",
		Name = "Hollow Log",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(160, 40, 40),
			Material = M.Grass,
			Accent = { Color = rgb(130, 130, 135), Pattern = { "Collar", "Heart" } },
		},
	},
	{
		Id = "WerewolfWoods_OwlSpotter",
		Name = "Owl Spotter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(80, 60, 45),
			ArmsColor = rgb(130, 130, 135),
			LegsColor = rgb(160, 40, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(40, 90, 50), Pattern = "Boots" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "WerewolfWoods_FullMoonHowler",
		Name = "Full Moon Howler",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(230, 160, 40),
			ArmsColor = rgb(40, 90, 50),
			LegsColor = rgb(80, 60, 45),
			Accent = { Color = rgb(210, 215, 230), Pattern = { "Spots", "Patches" } },
			Head = "WolfHead",
			HeadColor = rgb(40, 90, 50),
			HeadColor2 = rgb(80, 60, 45),
			GlowColor = rgb(120, 85, 60),
		},
	},
	{
		Id = "WerewolfWoods_WiseWoodsOwl",
		Name = "Wise Woods Owl",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(120, 85, 60),
			ArmsColor = rgb(210, 215, 230),
			LegsColor = rgb(230, 160, 40),
			Accent = { Color = rgb(160, 40, 40), Material = M.Neon, Pattern = { "Bones", "Star" } },
			Head = "OwlHead",
			HeadColor = rgb(160, 40, 40),
			HeadColor2 = rgb(120, 85, 60),
			GlowColor = rgb(40, 90, 50),
		},
	},
	{
		Id = "WerewolfWoods_AlphaWolf",
		Name = "Alpha Wolf",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(130, 130, 135),
			Accent = { Color = rgb(80, 60, 45), Pattern = { "Sash", "Wraps" } },
			Head = "WolfHead",
			HeadColor = rgb(230, 160, 40),
			HeadColor2 = rgb(40, 90, 50),
			GlowColor = rgb(160, 40, 40),
		},
	},
	{
		Id = "WerewolfWoods_FeralRanger",
		Name = "Feral Ranger",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(40, 90, 50),
			ArmsColor = rgb(80, 60, 45),
			LegsColor = rgb(130, 130, 135),
			Accent = { Color = rgb(230, 160, 40), Pattern = { "Tail", "Sash" } },
			Head = "WolfHead",
			HeadColor = rgb(130, 130, 135),
			HeadColor2 = rgb(160, 40, 40),
			GlowColor = rgb(230, 160, 40),
		},
	},
	{
		Id = "WerewolfWoods_LunarStalker",
		Name = "Lunar Stalker",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(210, 215, 230),
			ArmsColor = rgb(230, 160, 40),
			LegsColor = rgb(40, 90, 50),
			Accent = { Color = rgb(120, 85, 60), Pattern = { "Star", "Belt" } },
			Head = "OwlHead",
			HeadColor = rgb(210, 215, 230),
			HeadColor2 = rgb(230, 160, 40),
			GlowColor = rgb(130, 130, 135),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "WerewolfWoods_Moonbeast",
		Name = "Moonbeast",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(230, 160, 40),
			ArmsColor = rgb(210, 215, 230),
			LegsColor = rgb(120, 85, 60),
			Accent = { Color = rgb(210, 215, 230), Pattern = { "Belly", "Collar" } },
			Head = "WolfHead",
			HeadColor = rgb(80, 60, 45),
			HeadColor2 = rgb(120, 85, 60),
			GlowColor = rgb(160, 40, 40),
			Glow = { Color = rgb(160, 40, 40), Brightness = 1.6 },
			Aura = { Kind = "Stars", Color = rgb(160, 40, 40), Color2 = rgb(130, 130, 135) },
		},
	},
	{
		Id = "WerewolfWoods_SilverAlpha",
		Name = "Silver Alpha",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(120, 85, 60),
			ArmsColor = rgb(160, 40, 40),
			LegsColor = rgb(130, 130, 135),
			Accent = { Color = rgb(160, 40, 40), Pattern = { "Stitches", "Belly" } },
			Head = "WolfHead",
			HeadColor = rgb(130, 130, 135),
			HeadColor2 = rgb(210, 215, 230),
			GlowColor = rgb(120, 85, 60),
			Glow = { Color = rgb(120, 85, 60), Brightness = 1.8 },
			Aura = { Kind = "Smoke", Color = rgb(120, 85, 60), Color2 = rgb(160, 40, 40) },
		},
	},
	{
		Id = "WerewolfWoods_EclipseOwl",
		Name = "Eclipse Owl",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(130, 130, 135),
			ArmsColor = rgb(80, 60, 45),
			LegsColor = rgb(40, 90, 50),
			Accent = { Color = rgb(80, 60, 45), Pattern = { "Cape", "Wings" } },
			Head = "OwlHead",
			HeadColor = rgb(160, 40, 40),
			HeadColor2 = rgb(230, 160, 40),
			GlowColor = rgb(210, 215, 230),
			Glow = { Color = rgb(210, 215, 230), Brightness = 2.0 },
			Aura = { Kind = "Sparkles", Color = rgb(210, 215, 230), Color2 = rgb(120, 85, 60) },
		},
	},
} :: { any }
