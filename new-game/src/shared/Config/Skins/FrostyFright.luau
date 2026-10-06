--!strict
--[[
	FROSTY FRIGHT CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (FrostyFrightCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "FrostyFright_SnowAngel",
		Name = "Snow Angel",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 245, 255),
			ArmsColor = rgb(210, 40, 50),
			LegsColor = rgb(200, 210, 220),
			Material = M.Snow,
			Accent = { Color = rgb(40, 100, 60), Pattern = "Gloves" },
		},
	},
	{
		Id = "FrostyFright_IcicleIke",
		Name = "Icicle Ike",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(140, 200, 255),
			ArmsColor = rgb(210, 40, 50),
			LegsColor = rgb(30, 40, 80),
			Material = M.Ice,
			Accent = { Color = rgb(30, 40, 80), Pattern = "Wraps" },
		},
	},
	{
		Id = "FrostyFright_FrostBite",
		Name = "Frost Bite",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(170, 240, 245),
			ArmsColor = rgb(30, 40, 80),
			LegsColor = rgb(140, 200, 255),
			Material = M.Fabric,
			Accent = { Color = rgb(200, 210, 220), Pattern = { "Buttons", "Stripes" } },
		},
	},
	{
		Id = "FrostyFright_SnowballThrower",
		Name = "Snowball Thrower",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(210, 40, 50),
			Material = M.Glacier,
			Accent = { Color = rgb(240, 245, 255), Pattern = "Patches" },
		},
	},
	{
		Id = "FrostyFright_MittenKid",
		Name = "Mitten Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 100, 60),
			ArmsColor = rgb(240, 245, 255),
			LegsColor = rgb(210, 40, 50),
			Material = M.Snow,
			Accent = { Color = rgb(140, 200, 255), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "FrostyFright_IceSkater",
		Name = "Ice Skater",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 40, 80),
			ArmsColor = rgb(240, 245, 255),
			LegsColor = rgb(170, 240, 245),
			Material = M.Ice,
			Accent = { Color = rgb(170, 240, 245), Pattern = { "Heart", "Wraps" } },
		},
	},
	{
		Id = "FrostyFright_BlizzardBuddy",
		Name = "Blizzard Buddy",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 210, 220),
			ArmsColor = rgb(170, 240, 245),
			LegsColor = rgb(30, 40, 80),
			Material = M.Fabric,
			Accent = { Color = rgb(210, 40, 50), Pattern = "Collar" },
		},
	},
	{
		Id = "FrostyFright_SledRider",
		Name = "Sled Rider",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(240, 245, 255),
			Material = M.Glacier,
			Accent = { Color = rgb(40, 100, 60), Pattern = "Boots" },
		},
	},
	{
		Id = "FrostyFright_FrozenToes",
		Name = "Frozen Toes",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(140, 200, 255),
			ArmsColor = rgb(40, 100, 60),
			LegsColor = rgb(240, 245, 255),
			Material = M.Snow,
			Accent = { Color = rgb(30, 40, 80), Pattern = "Spots" },
		},
	},
	{
		Id = "FrostyFright_PenguinPal",
		Name = "Penguin Pal",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(170, 240, 245),
			ArmsColor = rgb(40, 100, 60),
			LegsColor = rgb(200, 210, 220),
			Material = M.Ice,
			Accent = { Color = rgb(200, 210, 220), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "FrostyFright_SleetStorm",
		Name = "Sleet Storm",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(210, 40, 50),
			ArmsColor = rgb(200, 210, 220),
			LegsColor = rgb(170, 240, 245),
			Material = M.Fabric,
			Accent = { Color = rgb(240, 245, 255), Pattern = "Sash" },
		},
	},
	{
		Id = "FrostyFright_FrostyBreath",
		Name = "Frosty Breath",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(40, 100, 60),
			Material = M.Glacier,
			Accent = { Color = rgb(140, 200, 255), Pattern = { "Tail", "Belly" } },
		},
	},
	{
		Id = "FrostyFright_IceFisher",
		Name = "Ice Fisher",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 40, 80),
			ArmsColor = rgb(140, 200, 255),
			LegsColor = rgb(40, 100, 60),
			Material = M.Snow,
			Accent = { Color = rgb(170, 240, 245), Pattern = "Star" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "FrostyFright_CreepySnowman",
		Name = "Creepy Snowman",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(200, 210, 220),
			ArmsColor = rgb(170, 240, 245),
			LegsColor = rgb(30, 40, 80),
			Accent = { Color = rgb(210, 40, 50), Pattern = "Cuffs" },
			Head = "SnowmanHead",
			HeadColor = rgb(170, 240, 245),
			HeadColor2 = rgb(30, 40, 80),
			GlowColor = rgb(240, 245, 255),
		},
	},
	{
		Id = "FrostyFright_FrozenMoon",
		Name = "Frozen Moon",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 245, 255),
			ArmsColor = rgb(210, 40, 50),
			LegsColor = rgb(200, 210, 220),
			Accent = {
				Color = rgb(40, 100, 60),
				Material = M.Neon,
				Pattern = { "Stripes", "Buttons" },
			},
			Head = "MoonHead",
			HeadColor = rgb(40, 100, 60),
			HeadColor2 = rgb(240, 245, 255),
			GlowColor = rgb(170, 240, 245),
		},
	},
	{
		Id = "FrostyFright_FrostStar",
		Name = "Frost Star",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(140, 200, 255),
			Accent = { Color = rgb(30, 40, 80), Pattern = { "Belly", "Tail" } },
			Head = "StarHead",
			HeadColor = rgb(200, 210, 220),
			HeadColor2 = rgb(170, 240, 245),
			GlowColor = rgb(40, 100, 60),
		},
	},
	{
		Id = "FrostyFright_SnowGhoul",
		Name = "Snow Ghoul",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(170, 240, 245),
			ArmsColor = rgb(30, 40, 80),
			LegsColor = rgb(140, 200, 255),
			Accent = { Color = rgb(200, 210, 220), Pattern = { "Stitches", "Gloves" } },
			Head = "SnowmanHead",
			HeadColor = rgb(140, 200, 255),
			HeadColor2 = rgb(40, 100, 60),
			GlowColor = rgb(200, 210, 220),
		},
	},
	{
		Id = "FrostyFright_IceSpirit",
		Name = "Ice Spirit",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(210, 40, 50),
			ArmsColor = rgb(200, 210, 220),
			LegsColor = rgb(170, 240, 245),
			Accent = { Color = rgb(240, 245, 255), Pattern = { "Cape", "Bones" } },
			Head = "MoonHead",
			HeadColor = rgb(210, 40, 50),
			HeadColor2 = rgb(200, 210, 220),
			GlowColor = rgb(140, 200, 255),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "FrostyFright_IceMonarch",
		Name = "Ice Monarch",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(200, 210, 220),
			ArmsColor = rgb(210, 40, 50),
			LegsColor = rgb(240, 245, 255),
			Accent = { Color = rgb(210, 40, 50), Pattern = { "Gloves", "Stitches" } },
			Head = "SnowmanHead",
			HeadColor = rgb(30, 40, 80),
			HeadColor2 = rgb(240, 245, 255),
			GlowColor = rgb(40, 100, 60),
			Glow = { Color = rgb(40, 100, 60), Brightness = 1.6 },
			Aura = { Kind = "Snow", Color = rgb(40, 100, 60), Color2 = rgb(140, 200, 255) },
		},
	},
	{
		Id = "FrostyFright_WinterMoon",
		Name = "Winter Moon",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(240, 245, 255),
			ArmsColor = rgb(40, 100, 60),
			LegsColor = rgb(140, 200, 255),
			Accent = { Color = rgb(40, 100, 60), Pattern = { "Wraps", "Heart" } },
			Head = "MoonHead",
			HeadColor = rgb(140, 200, 255),
			HeadColor2 = rgb(210, 40, 50),
			GlowColor = rgb(240, 245, 255),
			Glow = { Color = rgb(240, 245, 255), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(240, 245, 255), Color2 = rgb(40, 100, 60) },
		},
	},
	{
		Id = "FrostyFright_PolarStar",
		Name = "Polar Star",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(140, 200, 255),
			ArmsColor = rgb(30, 40, 80),
			LegsColor = rgb(170, 240, 245),
			Accent = { Color = rgb(30, 40, 80), Pattern = { "Buttons", "Stripes" } },
			Head = "StarHead",
			HeadColor = rgb(40, 100, 60),
			HeadColor2 = rgb(200, 210, 220),
			GlowColor = rgb(210, 40, 50),
			Glow = { Color = rgb(210, 40, 50), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(210, 40, 50), Color2 = rgb(240, 245, 255) },
		},
	},
} :: { any }
