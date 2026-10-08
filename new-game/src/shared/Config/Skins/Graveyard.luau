--!strict
--[[
	GRAVEYARD CRATE SKINS (20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY.
	Every Style option is explained at the top of Pumpkin.luau. Change Names and looks freely;
	NEVER change an Id (it is saved in players' data).
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "Graveyard_SkellySuit",
		Name = "Skelly Suit",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(30, 28, 35),
			Accent = { Color = rgb(245, 240, 225), Pattern = "Bones" },
		},
	},
	{
		Id = "Graveyard_Gravedigger",
		Name = "Gravedigger",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(95, 85, 70),
			ArmsColor = rgb(95, 85, 70),
			LegsColor = rgb(60, 55, 50),
			Material = M.Fabric,
			Accent = { Color = rgb(50, 40, 35), Pattern = { "Belt", "Boots" } },
		},
	},
	{
		Id = "Graveyard_MossyStone",
		Name = "Mossy Stone",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(140, 140, 150),
			Material = M.Cobblestone,
			Accent = { Color = rgb(110, 170, 80), Pattern = "Spots" },
		},
	},
	{
		Id = "Graveyard_CrackedSlate",
		Name = "Cracked Slate",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(150, 150, 165),
			Material = M.Slate,
			Accent = { Color = rgb(80, 80, 95), Pattern = "Stitches" },
		},
	},
	{
		Id = "Graveyard_MummyWrapJr",
		Name = "Mummy Wrap Jr.",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(215, 205, 180),
			Material = M.Fabric,
			Accent = { Color = rgb(240, 232, 210), Material = M.Fabric, Pattern = "Wraps" },
		},
	},
	{
		Id = "Graveyard_CrowCloak",
		Name = "Crow Cloak",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(35, 35, 45),
			Material = M.Fabric,
			Accent = {
				Color = rgb(60, 60, 85),
				Material = M.Fabric,
				Pattern = { "Cape", "Collar" },
			},
		},
	},
	{
		Id = "Graveyard_ZombieStroll",
		Name = "Zombie Stroll",
		Rarity = "Common",
		Style = {
			HeadColor = rgb(140, 190, 110),
			ArmsColor = rgb(140, 190, 110),
			TorsoColor = rgb(90, 110, 150),
			LegsColor = rgb(80, 70, 60),
			TorsoMaterial = M.Fabric,
			LegsMaterial = M.Fabric,
			Accent = { Color = rgb(180, 160, 120), Material = M.Fabric, Pattern = "Patches" },
		},
	},
	{
		Id = "Graveyard_Lamplighter",
		Name = "Lamplighter",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(60, 55, 70),
			Accent = {
				Color = rgb(255, 200, 90),
				Material = M.Neon,
				Pattern = { "Gloves", "Collar" },
			},
		},
	},
	{
		Id = "Graveyard_MarbleStatue",
		Name = "Marble Statue",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(235, 235, 240),
			Material = M.Marble,
			Accent = { Color = rgb(200, 200, 210), Material = M.Marble, Pattern = "Sash" },
		},
	},
	{
		Id = "Graveyard_RustyGate",
		Name = "Rusty Gate",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(130, 80, 55),
			Material = M.CorrodedMetal,
			Accent = { Color = rgb(60, 50, 45), Material = M.Metal, Pattern = "Stripes" },
		},
	},
	{
		Id = "Graveyard_FogWalker",
		Name = "Fog Walker",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(170, 180, 190),
			Transparency = 0.35,
			Accent = { Color = rgb(220, 225, 230), Pattern = "Cuffs" },
		},
	},
	{
		Id = "Graveyard_BoneWhite",
		Name = "Bone White",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(245, 240, 225),
			Accent = { Color = rgb(30, 28, 35), Pattern = "Bones" },
		},
	},

	-- UNCOMMON (head pieces) ---------------------------------------------------------------
	{
		Id = "Graveyard_BonyTony",
		Name = "Bony Tony",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(30, 28, 35),
			Accent = { Color = rgb(245, 240, 225), Pattern = { "Bones", "Belt" } },
			Head = "SkinSkull",
			HeadColor = rgb(245, 240, 225),
			GlowColor = rgb(110, 200, 255),
		},
	},
	{
		Id = "Graveyard_MummyMax",
		Name = "Mummy Max",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(215, 205, 180),
			Material = M.Fabric,
			Accent = { Color = rgb(235, 228, 205), Material = M.Fabric, Pattern = "Wraps" },
			Head = "MummyHead",
			HeadColor = rgb(228, 218, 192),
			GlowColor = rgb(120, 255, 140),
		},
	},
	{
		Id = "Graveyard_ZombieZack",
		Name = "Zombie Zack",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(90, 110, 150),
			ArmsColor = rgb(140, 195, 110),
			LegsColor = rgb(80, 70, 60),
			TorsoMaterial = M.Fabric,
			LegsMaterial = M.Fabric,
			Accent = { Color = rgb(180, 160, 120), Material = M.Fabric, Pattern = "Patches" },
			Head = "ZombieHead",
			HeadColor = rgb(140, 195, 110),
			HeadColor2 = rgb(60, 45, 70),
			GlowColor = rgb(255, 240, 150),
		},
	},
	{
		Id = "Graveyard_TombBuddy",
		Name = "Tomb Buddy",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(120, 120, 135),
			Material = M.Slate,
			Accent = { Color = rgb(110, 170, 80), Pattern = "Spots" },
			Head = "TombstoneHead",
			HeadColor = rgb(150, 150, 165),
			HeadColor2 = rgb(110, 170, 80),
			GlowColor = rgb(150, 255, 220),
		},
	},
	{
		Id = "Graveyard_CountCuddles",
		Name = "Count Cuddles",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(35, 25, 45),
			ArmsColor = rgb(35, 25, 45),
			LegsColor = rgb(25, 20, 30),
			Accent = { Color = rgb(200, 30, 60), Pattern = { "Cape", "Buttons" } },
			Head = "VampireHead",
			HeadColor = rgb(225, 225, 240),
			HeadColor2 = rgb(35, 25, 45),
			GlowColor = rgb(200, 30, 60),
		},
	},

	-- RARE (+ glow and particles) ----------------------------------------------------------
	{
		Id = "Graveyard_LanternKeeper",
		Name = "Lantern Keeper",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(60, 55, 70),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 80, 55), Material = M.Fabric, Pattern = { "Cape", "Belt" } },
			Head = "LanternHead",
			HeadColor = rgb(45, 40, 50),
			GlowColor = rgb(255, 200, 90),
			Glow = { Color = rgb(255, 190, 90), Brightness = 2 },
			Aura = { Kind = "Embers", Color = rgb(255, 220, 130), Color2 = rgb(255, 150, 60) },
		},
	},
	{
		Id = "Graveyard_GlowBones",
		Name = "Glow Bones",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(20, 30, 25),
			Accent = { Color = rgb(140, 255, 160), Material = M.Neon, Pattern = "Bones" },
			Head = "SkinSkull",
			HeadColor = rgb(235, 245, 235),
			GlowColor = rgb(120, 255, 140),
			Glow = { Color = rgb(120, 255, 140), Brightness = 1.8 },
			Aura = { Kind = "Smoke", Color = rgb(120, 200, 140), Color2 = rgb(30, 60, 40) },
		},
	},

	-- CRAZY (0.1% in the Graveyard Crate) --------------------------------------------------
	{
		Id = "Graveyard_SkellySuperstar",
		Name = "Skelly Superstar",
		Rarity = "Crazy",
		Style = {
			BodyColor = rgb(30, 25, 40),
			Material = M.Foil,
			Accent = { Material = M.Neon, Pattern = { "Bones", "Gloves", "Boots" } },
			Head = "StarSkull",
			HeadColor = rgb(245, 240, 225),
			HeadColor2 = rgb(30, 25, 40),
			Glow = { Color = rgb(255, 220, 120), Brightness = 2.2, Range = 14 },
			Aura = { Kind = "Stars", Color = rgb(255, 230, 140) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Bones", Count = 4 },
			Animate = {
				{ Effect = "Wobble", Target = "Head", Speed = 1.6, Amount = 1.2 },
				{ Effect = "Shimmer", Target = "Head", Speed = 0.7 },
				{ Effect = "SparkleBurst", Every = 3, Count = 20 },
			} :: { any }, -- (effects differ in shape)
			Motion = "Proud",
		},
	},
} :: { any }
