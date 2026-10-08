--!strict
--[[
	MONSTER CRATE SKINS (20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY.
	Friendly monsters only. Every Style option is explained at the top of Pumpkin.luau.
	Change Names and looks freely; NEVER change an Id (it is saved in players' data).
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "Monster_SwampSuit",
		Name = "Swamp Suit",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(80, 120, 70),
			Material = M.Mud,
			Accent = { Color = rgb(130, 180, 90), Pattern = "Spots" },
		},
	},
	{
		Id = "Monster_Furball",
		Name = "Furball",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(130, 100, 210),
			Material = M.Fabric,
			Accent = { Color = rgb(195, 175, 245), Material = M.Fabric, Pattern = "Belly" },
		},
	},
	{
		Id = "Monster_LizardLad",
		Name = "Lizard Lad",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(70, 150, 110),
			Material = M.Pebble,
			Accent = { Color = rgb(230, 220, 140), Pattern = { "Belly", "Tail" } },
		},
	},
	{
		Id = "Monster_SlimeTime",
		Name = "Slime Time",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(120, 240, 120),
			Material = M.Glass,
			Accent = { Color = rgb(70, 180, 80), Material = M.Glass, Pattern = "Gloves" },
		},
	},
	{
		Id = "Monster_BoltBuddy",
		Name = "Bolt Buddy",
		Rarity = "Common",
		Style = {
			HeadColor = rgb(125, 185, 105),
			ArmsColor = rgb(125, 185, 105),
			TorsoColor = rgb(60, 60, 70),
			LegsColor = rgb(45, 45, 55),
			TorsoMaterial = M.Fabric,
			Accent = { Color = rgb(30, 28, 35), Pattern = "Stitches" },
		},
	},
	{
		Id = "Monster_LittleYeti",
		Name = "Little Yeti",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(240, 245, 255),
			Material = M.Snow,
			Accent = { Color = rgb(170, 200, 230), Pattern = "Belly" },
		},
	},
	{
		Id = "Monster_PolkaMonster",
		Name = "Polka Monster",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 120, 60),
			Accent = { Color = rgb(255, 230, 90), Pattern = "Spots" },
		},
	},
	{
		Id = "Monster_ClawHands",
		Name = "Claw Hands",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(90, 70, 140),
			Accent = { Color = rgb(30, 25, 40), Pattern = { "Gloves", "Boots" } },
		},
	},
	{
		Id = "Monster_DeepSea",
		Name = "Deep Sea",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(60, 130, 180),
			Material = M.Glass,
			Accent = { Color = rgb(40, 85, 135), Pattern = "Stripes" },
		},
	},
	{
		Id = "Monster_Rocky",
		Name = "Rocky",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(125, 115, 105),
			Material = M.Rock,
			Accent = { Color = rgb(95, 150, 80), Pattern = "Patches" },
		},
	},
	{
		Id = "Monster_PurpleGoo",
		Name = "Purple Goo",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(170, 90, 230),
			Material = M.Glass,
			Accent = { Color = rgb(230, 180, 255), Pattern = "Cuffs" },
		},
	},
	{
		Id = "Monster_FuzzyWuzzy",
		Name = "Fuzzy Wuzzy",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(240, 170, 60),
			Material = M.Fabric,
			Accent = {
				Color = rgb(190, 120, 40),
				Material = M.Fabric,
				Pattern = { "Tail", "Spots" },
			},
		},
	},

	-- UNCOMMON (head pieces) ---------------------------------------------------------------
	{
		Id = "Monster_Franky",
		Name = "Franky",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(60, 60, 70),
			ArmsColor = rgb(125, 185, 105),
			LegsColor = rgb(45, 45, 55),
			TorsoMaterial = M.Fabric,
			Accent = { Color = rgb(35, 30, 40), Pattern = "Boots" },
			Head = "FrankenHead",
			HeadColor = rgb(125, 185, 105),
			HeadColor2 = rgb(30, 28, 35),
			GlowColor = rgb(150, 255, 120),
		},
	},
	{
		Id = "Monster_EyeSpy",
		Name = "Eye Spy",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(90, 60, 140),
			Accent = { Color = rgb(80, 200, 120), Pattern = "Spots" },
			Head = "EyeballHead",
			HeadColor = rgb(248, 246, 240),
			HeadColor2 = rgb(80, 200, 120),
		},
	},
	{
		Id = "Monster_Wolfie",
		Name = "Wolfie",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(125, 115, 130),
			Material = M.Fabric,
			Accent = {
				Color = rgb(215, 205, 210),
				Material = M.Fabric,
				Pattern = { "Belly", "Tail" },
			},
			Head = "WolfHead",
			HeadColor = rgb(125, 115, 130),
			HeadColor2 = rgb(215, 205, 210),
			GlowColor = rgb(255, 220, 80),
		},
	},
	{
		Id = "Monster_Fuzzball",
		Name = "Fuzzball",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(110, 90, 200),
			Material = M.Fabric,
			Accent = { Color = rgb(170, 150, 240), Material = M.Fabric, Pattern = "Belly" },
			Head = "FuzzyHead",
			HeadColor = rgb(110, 90, 200),
			HeadColor2 = rgb(250, 235, 200),
			GlowColor = rgb(120, 220, 255),
		},
	},
	{
		Id = "Monster_Blobby",
		Name = "Blobby",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(120, 230, 120),
			Material = M.Glass,
			Accent = { Color = rgb(80, 190, 80), Material = M.Glass, Pattern = "Boots" },
			Head = "BlobHead",
			HeadColor = rgb(120, 230, 120),
		},
	},

	-- RARE (+ glow and particles) ----------------------------------------------------------
	{
		Id = "Monster_FrostYeti",
		Name = "Frost Yeti",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(235, 245, 255),
			Material = M.Snow,
			Accent = {
				Color = rgb(150, 200, 255),
				Material = M.Ice,
				Pattern = { "Gloves", "Boots" },
			},
			Head = "FuzzyHead",
			HeadColor = rgb(235, 245, 255),
			HeadColor2 = rgb(150, 200, 255),
			GlowColor = rgb(90, 180, 255),
			Glow = { Color = rgb(150, 210, 255), Brightness = 1.6 },
			Aura = { Kind = "Snow", Color = rgb(255, 255, 255), Color2 = rgb(170, 220, 255) },
		},
	},
	{
		Id = "Monster_Sparky",
		Name = "Sparky",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(50, 50, 60),
			ArmsColor = rgb(125, 185, 105),
			LegsColor = rgb(40, 40, 50),
			Accent = {
				Color = rgb(255, 230, 80),
				Material = M.Neon,
				Pattern = { "Stitches", "Belt" },
			},
			Head = "FrankenHead",
			HeadColor = rgb(125, 185, 105),
			HeadColor2 = rgb(30, 28, 35),
			GlowColor = rgb(255, 240, 90),
			Glow = { Color = rgb(255, 240, 120), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(255, 240, 120), Color2 = rgb(150, 220, 255) },
		},
	},

	-- CRAZY (0.1% in the Monster Crate) ----------------------------------------------------
	{
		Id = "Monster_GloopGalaxy",
		Name = "Gloop Galaxy",
		Rarity = "Crazy",
		Style = {
			BodyColor = rgb(110, 240, 120),
			Material = M.Glass,
			Accent = { Material = M.Neon, Pattern = { "Spots", "Boots", "Gloves" } },
			Head = "GloopMonster",
			HeadColor = rgb(110, 240, 120),
			Glow = { Color = rgb(120, 255, 140), Brightness = 2.2, Range = 14 },
			Aura = { Kind = "Bubbles", Color = rgb(140, 255, 160) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Eyes", Count = 3 },
			Animate = {
				{ Effect = "Breathe", Target = "Head", Speed = 1.5, Amount = 3 },
				{ Effect = "Wobble", Target = "Head", Speed = 0.8, Axis = "X" },
				{ Effect = "SparkleBurst", Every = 3.5, Count = 12 },
			} :: { any }, -- (effects differ in shape)
			Motion = "Zombie",
		},
	},
} :: { any }
