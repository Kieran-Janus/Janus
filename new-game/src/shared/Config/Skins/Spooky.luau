--!strict
--[[
	SPOOKY CRATE SKINS (20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY.
	Every Style option is explained at the top of Pumpkin.luau. Change Names and looks freely;
	NEVER change an Id (it is saved in players' data).
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "Spooky_MidnightCloak",
		Name = "Midnight Cloak",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(30, 25, 45),
			Accent = { Color = rgb(100, 45, 150), Pattern = { "Cape", "Collar" } },
		},
	},
	{
		Id = "Spooky_CobwebKid",
		Name = "Cobweb Kid",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(70, 70, 85),
			Accent = { Color = rgb(235, 235, 245), Pattern = "Web" },
		},
	},
	{
		Id = "Spooky_PurplePotion",
		Name = "Purple Potion",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(150, 80, 220),
			Material = M.Glass,
			Accent = { Color = rgb(60, 220, 120), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "Spooky_BatSuit",
		Name = "Bat Suit",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(45, 35, 60),
			Accent = { Color = rgb(115, 85, 155), Pattern = "Wings" },
		},
	},
	{
		Id = "Spooky_FoggyFriend",
		Name = "Foggy Friend",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(180, 200, 255),
			Material = M.ForceField,
			Accent = { Color = rgb(235, 240, 255), Pattern = "Collar" },
		},
	},
	{
		Id = "Spooky_CreakyFloorboard",
		Name = "Creaky Floorboard",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(120, 90, 70),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(60, 45, 40), Pattern = "Patches" },
		},
	},
	{
		Id = "Spooky_SpiderStripes",
		Name = "Spider Stripes",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(30, 25, 35),
			Accent = { Color = rgb(255, 120, 30), Pattern = "Stripes" },
		},
	},
	{
		Id = "Spooky_Ectoplasm",
		Name = "Ectoplasm",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(140, 255, 160),
			Material = M.Glass,
			Accent = { Color = rgb(220, 255, 230), Pattern = "Spots" },
		},
	},
	{
		Id = "Spooky_BlackCatSuit",
		Name = "Black Cat Suit",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(25, 22, 30),
			Accent = { Color = rgb(45, 40, 55), Pattern = { "Tail", "Belly" } },
		},
	},
	{
		Id = "Spooky_CrystalBall",
		Name = "Crystal Ball",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(190, 170, 255),
			Material = M.Glass,
			Accent = { Color = rgb(255, 255, 255), Material = M.Neon, Pattern = "Star" },
		},
	},
	{
		Id = "Spooky_Spellbook",
		Name = "Spellbook",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(130, 40, 45),
			ArmsColor = rgb(130, 40, 45),
			LegsColor = rgb(60, 40, 30),
			Material = M.Fabric,
			Accent = {
				Color = rgb(255, 210, 80),
				Material = M.Foil,
				Pattern = { "Belt", "Buttons" },
			},
		},
	},
	{
		Id = "Spooky_ShadowPuppet",
		Name = "Shadow Puppet",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(15, 12, 20),
			Accent = { Color = rgb(255, 255, 255), Pattern = "Gloves" },
		},
	},

	-- UNCOMMON (head pieces) ---------------------------------------------------------------
	{
		Id = "Spooky_BooBuddy",
		Name = "Boo Buddy",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(240, 240, 250),
			Accent = { Color = rgb(255, 200, 220), Pattern = "Belly" },
			Head = "GhostSheet",
			HeadColor = rgb(245, 245, 255),
		},
	},
	{
		Id = "Spooky_Batty",
		Name = "Batty",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(90, 65, 125),
			Accent = { Color = rgb(60, 42, 85), Pattern = "Wings" },
			Head = "BatHead",
			HeadColor = rgb(90, 65, 125),
			HeadColor2 = rgb(255, 150, 190),
		},
	},
	{
		Id = "Spooky_MidnightCat",
		Name = "Midnight Cat",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(40, 35, 50),
			Accent = { Color = rgb(110, 95, 140), Pattern = { "Tail", "Collar" } },
			Head = "CatHead",
			HeadColor = rgb(40, 35, 50),
			HeadColor2 = rgb(255, 150, 190),
			GlowColor = rgb(190, 255, 90),
		},
	},
	{
		Id = "Spooky_LittleWitch",
		Name = "Little Witch",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(70, 35, 100),
			ArmsColor = rgb(70, 35, 100),
			LegsColor = rgb(40, 30, 45),
			Accent = { Color = rgb(255, 140, 30), Pattern = "Stripes" },
			Head = "WitchHood",
			HeadColor = rgb(160, 215, 130),
			HeadColor2 = rgb(70, 35, 100),
			GlowColor = rgb(255, 140, 30),
		},
	},
	{
		Id = "Spooky_CauldronCook",
		Name = "Cauldron Cook",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(60, 50, 70),
			Accent = { Color = rgb(245, 245, 245), Pattern = "Belly" },
			Head = "CauldronHat",
			HeadColor = rgb(255, 205, 160),
			HeadColor2 = rgb(45, 42, 55),
			GlowColor = rgb(120, 255, 90),
		},
	},

	-- RARE (+ glow and particles) ----------------------------------------------------------
	{
		Id = "Spooky_SpiderRoyalty",
		Name = "Spider Royalty",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(35, 30, 45),
			Accent = { Color = rgb(210, 200, 240), Pattern = { "Web", "Cape" } },
			Head = "SpiderCrown",
			HeadColor = rgb(200, 190, 230),
			HeadColor2 = rgb(35, 30, 45),
			GlowColor = rgb(255, 80, 80),
			Glow = { Color = rgb(170, 90, 255) },
			Aura = { Kind = "Smoke", Color = rgb(130, 70, 190), Color2 = rgb(40, 20, 60) },
		},
	},
	{
		Id = "Spooky_PotionMaster",
		Name = "Potion Master",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(90, 50, 140),
			Accent = { Color = rgb(190, 90, 255), Material = M.Neon, Pattern = { "Sash", "Cuffs" } },
			Head = "PotionHead",
			HeadColor = rgb(200, 230, 255),
			HeadColor2 = rgb(240, 220, 170),
			GlowColor = rgb(190, 90, 255),
			Glow = { Color = rgb(190, 90, 255) },
			Aura = { Kind = "Bubbles", Color = rgb(190, 90, 255), Color2 = rgb(120, 255, 200) },
		},
	},

	-- CRAZY (0.1% in the Spooky Crate) -----------------------------------------------------
	{
		Id = "Spooky_PhantomPrism",
		Name = "Phantom Prism",
		Rarity = "Crazy",
		Style = {
			BodyColor = rgb(215, 230, 255),
			Material = M.Glass,
			Transparency = 0.25,
			Accent = { Material = M.Neon, Pattern = { "Cape", "Collar", "Cuffs" } },
			Head = "PhantomKing",
			HeadColor = rgb(230, 240, 255),
			GlowColor = rgb(60, 40, 120),
			Glow = { Color = rgb(180, 200, 255), Brightness = 2.2, Range = 14 },
			Aura = { Kind = "Sparkles", Color = rgb(200, 220, 255) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Ghosts", Count = 4 },
		},
	},
} :: { any }
