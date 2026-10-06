--!strict
--[[
	CURSED TOYS CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (CursedToysCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "CursedToys_WindUpWalker",
		Name = "Wind-Up Walker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(170, 120, 80),
			ArmsColor = rgb(255, 210, 60),
			LegsColor = rgb(200, 50, 50),
			Material = M.Fabric,
			Accent = { Color = rgb(245, 235, 230), Pattern = "Heart" },
		},
	},
	{
		Id = "CursedToys_RagDoll",
		Name = "Rag Doll",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 140, 180),
			ArmsColor = rgb(255, 210, 60),
			LegsColor = rgb(120, 180, 90),
			Material = M.Plastic,
			Accent = { Color = rgb(120, 180, 90), Pattern = "Collar" },
		},
	},
	{
		Id = "CursedToys_ToySoldier",
		Name = "Toy Soldier",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(80, 150, 240),
			ArmsColor = rgb(120, 180, 90),
			LegsColor = rgb(240, 140, 180),
			Material = M.Wood,
			Accent = { Color = rgb(200, 50, 50), Pattern = { "Boots", "Spots" } },
		},
	},
	{
		Id = "CursedToys_JackintheBox",
		Name = "Jack-in-the-Box",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 210, 60),
			Material = M.Carpet,
			Accent = { Color = rgb(170, 120, 80), Pattern = "Spots" },
		},
	},
	{
		Id = "CursedToys_BlockBuilder",
		Name = "Block Builder",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(245, 235, 230),
			ArmsColor = rgb(170, 120, 80),
			LegsColor = rgb(255, 210, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(240, 140, 180), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "CursedToys_MarbleKid",
		Name = "Marble Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 180, 90),
			ArmsColor = rgb(170, 120, 80),
			LegsColor = rgb(80, 150, 240),
			Material = M.Plastic,
			Accent = { Color = rgb(80, 150, 240), Pattern = { "Sash", "Belly" } },
		},
	},
	{
		Id = "CursedToys_PaperPlane",
		Name = "Paper Plane",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 50, 50),
			ArmsColor = rgb(80, 150, 240),
			LegsColor = rgb(120, 180, 90),
			Material = M.Wood,
			Accent = { Color = rgb(255, 210, 60), Pattern = "Tail" },
		},
	},
	{
		Id = "CursedToys_YoYoSpinner",
		Name = "Yo-Yo Spinner",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(170, 120, 80),
			Material = M.Carpet,
			Accent = { Color = rgb(245, 235, 230), Pattern = "Star" },
		},
	},
	{
		Id = "CursedToys_SpinningTop",
		Name = "Spinning Top",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 140, 180),
			ArmsColor = rgb(245, 235, 230),
			LegsColor = rgb(170, 120, 80),
			Material = M.Fabric,
			Accent = { Color = rgb(120, 180, 90), Pattern = { "Cuffs", "Buttons" } },
		},
	},
	{
		Id = "CursedToys_ButtonEyes",
		Name = "Button Eyes",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(80, 150, 240),
			ArmsColor = rgb(245, 235, 230),
			LegsColor = rgb(200, 50, 50),
			Material = M.Plastic,
			Accent = { Color = rgb(200, 50, 50), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "CursedToys_PuppetStrings",
		Name = "Puppet Strings",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 210, 60),
			ArmsColor = rgb(200, 50, 50),
			LegsColor = rgb(80, 150, 240),
			Material = M.Wood,
			Accent = { Color = rgb(170, 120, 80), Pattern = "Belly" },
		},
	},
	{
		Id = "CursedToys_TinRobot",
		Name = "Tin Robot",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(245, 235, 230),
			Material = M.Carpet,
			Accent = { Color = rgb(240, 140, 180), Pattern = { "Stitches", "Bones" } },
		},
	},
	{
		Id = "CursedToys_RockingHorse",
		Name = "Rocking Horse",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 180, 90),
			ArmsColor = rgb(240, 140, 180),
			LegsColor = rgb(245, 235, 230),
			Material = M.Fabric,
			Accent = { Color = rgb(80, 150, 240), Pattern = "Cape" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "CursedToys_CursedTeddy",
		Name = "Cursed Teddy",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(200, 50, 50),
			ArmsColor = rgb(80, 150, 240),
			LegsColor = rgb(120, 180, 90),
			Accent = { Color = rgb(255, 210, 60), Pattern = { "Web", "Boots" } },
			Head = "TeddyHead",
			HeadColor = rgb(80, 150, 240),
			HeadColor2 = rgb(120, 180, 90),
			GlowColor = rgb(170, 120, 80),
		},
	},
	{
		Id = "CursedToys_FuzzyMonsterPlush",
		Name = "Fuzzy Monster Plush",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(170, 120, 80),
			ArmsColor = rgb(255, 210, 60),
			LegsColor = rgb(200, 50, 50),
			Accent = {
				Color = rgb(245, 235, 230),
				Material = M.Neon,
				Pattern = { "Belt", "Stitches" },
			},
			Head = "FuzzyHead",
			HeadColor = rgb(245, 235, 230),
			HeadColor2 = rgb(170, 120, 80),
			GlowColor = rgb(80, 150, 240),
		},
	},
	{
		Id = "CursedToys_HauntedDoll",
		Name = "Haunted Doll",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(240, 140, 180),
			Accent = { Color = rgb(120, 180, 90), Pattern = { "Gloves", "Heart" } },
			Head = "TeddyHead",
			HeadColor = rgb(200, 50, 50),
			HeadColor2 = rgb(80, 150, 240),
			GlowColor = rgb(245, 235, 230),
		},
	},
	{
		Id = "CursedToys_PossessedPuppet",
		Name = "Possessed Puppet",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(80, 150, 240),
			ArmsColor = rgb(120, 180, 90),
			LegsColor = rgb(240, 140, 180),
			Accent = { Color = rgb(200, 50, 50), Pattern = { "Wraps", "Stripes" } },
			Head = "FuzzyHead",
			HeadColor = rgb(240, 140, 180),
			HeadColor2 = rgb(245, 235, 230),
			GlowColor = rgb(200, 50, 50),
		},
	},
	{
		Id = "CursedToys_ShadowBear",
		Name = "Shadow Bear",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(255, 210, 60),
			ArmsColor = rgb(200, 50, 50),
			LegsColor = rgb(80, 150, 240),
			Accent = { Color = rgb(170, 120, 80), Pattern = { "Buttons", "Patches" } },
			Head = "TeddyHead",
			HeadColor = rgb(255, 210, 60),
			HeadColor2 = rgb(200, 50, 50),
			GlowColor = rgb(240, 140, 180),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "CursedToys_ToyBoxTerror",
		Name = "Toy Box Terror",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(200, 50, 50),
			ArmsColor = rgb(255, 210, 60),
			LegsColor = rgb(170, 120, 80),
			Accent = { Color = rgb(255, 210, 60), Pattern = { "Heart", "Sash" } },
			Head = "TeddyHead",
			HeadColor = rgb(120, 180, 90),
			HeadColor2 = rgb(170, 120, 80),
			GlowColor = rgb(245, 235, 230),
			Glow = { Color = rgb(245, 235, 230), Brightness = 1.6 },
			Aura = { Kind = "Hearts", Color = rgb(245, 235, 230), Color2 = rgb(240, 140, 180) },
		},
	},
	{
		Id = "CursedToys_NightmarePlush",
		Name = "Nightmare Plush",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(170, 120, 80),
			ArmsColor = rgb(245, 235, 230),
			LegsColor = rgb(240, 140, 180),
			Accent = { Color = rgb(245, 235, 230), Pattern = { "Collar", "Belt" } },
			Head = "FuzzyHead",
			HeadColor = rgb(240, 140, 180),
			HeadColor2 = rgb(255, 210, 60),
			GlowColor = rgb(170, 120, 80),
			Glow = { Color = rgb(170, 120, 80), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(170, 120, 80), Color2 = rgb(245, 235, 230) },
		},
	},
	{
		Id = "CursedToys_ClockworkCurse",
		Name = "Clockwork Curse",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(240, 140, 180),
			ArmsColor = rgb(120, 180, 90),
			LegsColor = rgb(80, 150, 240),
			Accent = { Color = rgb(120, 180, 90), Pattern = { "Boots", "Spots" } },
			Head = "TeddyHead",
			HeadColor = rgb(245, 235, 230),
			HeadColor2 = rgb(200, 50, 50),
			GlowColor = rgb(255, 210, 60),
			Glow = { Color = rgb(255, 210, 60), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(255, 210, 60), Color2 = rgb(170, 120, 80) },
		},
	},
} :: { any }
