--!strict
--[[
	MAD SCIENTIST LAB CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (MadScientistLabCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "MadScientistLab_LabAssistant",
		Name = "Lab Assistant",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(235, 240, 245),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(255, 220, 40),
			Accent = { Color = rgb(190, 110, 60), Pattern = "Sash" },
		},
	},
	{
		Id = "MadScientistLab_BeakerBoy",
		Name = "Beaker Boy",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 255, 80),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(150, 80, 220),
			Material = M.Metal,
			Accent = { Color = rgb(150, 80, 220), Pattern = "Tail" },
		},
	},
	{
		Id = "MadScientistLab_TestTubeTina",
		Name = "Test Tube Tina",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(60, 170, 255),
			ArmsColor = rgb(150, 80, 220),
			LegsColor = rgb(120, 255, 80),
			Material = M.Rubber,
			Accent = { Color = rgb(255, 220, 40), Pattern = { "Star", "Web" } },
		},
	},
	{
		Id = "MadScientistLab_SparkPlug",
		Name = "Spark Plug",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(30, 30, 35),
			Material = M.Glass,
			Accent = { Color = rgb(235, 240, 245), Pattern = "Cuffs" },
		},
	},
	{
		Id = "MadScientistLab_GooMopper",
		Name = "Goo Mopper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 110, 60),
			ArmsColor = rgb(235, 240, 245),
			LegsColor = rgb(30, 30, 35),
			Accent = { Color = rgb(120, 255, 80), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "MadScientistLab_CoilTinkerer",
		Name = "Coil Tinkerer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 80, 220),
			ArmsColor = rgb(235, 240, 245),
			LegsColor = rgb(60, 170, 255),
			Material = M.Metal,
			Accent = { Color = rgb(60, 170, 255), Pattern = { "Belly", "Heart" } },
		},
	},
	{
		Id = "MadScientistLab_BubbleChemist",
		Name = "Bubble Chemist",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 220, 40),
			ArmsColor = rgb(60, 170, 255),
			LegsColor = rgb(150, 80, 220),
			Material = M.Rubber,
			Accent = { Color = rgb(30, 30, 35), Pattern = "Stitches" },
		},
	},
	{
		Id = "MadScientistLab_GaugeWatcher",
		Name = "Gauge Watcher",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(235, 240, 245),
			Material = M.Glass,
			Accent = { Color = rgb(190, 110, 60), Pattern = "Cape" },
		},
	},
	{
		Id = "MadScientistLab_GoggleIntern",
		Name = "Goggle Intern",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 255, 80),
			ArmsColor = rgb(190, 110, 60),
			LegsColor = rgb(235, 240, 245),
			Accent = { Color = rgb(150, 80, 220), Pattern = { "Web", "Star" } },
		},
	},
	{
		Id = "MadScientistLab_VoltRunner",
		Name = "Volt Runner",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(60, 170, 255),
			ArmsColor = rgb(190, 110, 60),
			LegsColor = rgb(255, 220, 40),
			Material = M.Metal,
			Accent = { Color = rgb(255, 220, 40), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "MadScientistLab_SpecimenJar",
		Name = "Specimen Jar",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(255, 220, 40),
			LegsColor = rgb(60, 170, 255),
			Material = M.Rubber,
			Accent = { Color = rgb(235, 240, 245), Pattern = "Gloves" },
		},
	},
	{
		Id = "MadScientistLab_PetriPal",
		Name = "Petri Pal",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(190, 110, 60),
			Material = M.Glass,
			Accent = { Color = rgb(120, 255, 80), Pattern = { "Wraps", "Belt" } },
		},
	},
	{
		Id = "MadScientistLab_RubberGlove",
		Name = "Rubber Glove",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 80, 220),
			ArmsColor = rgb(120, 255, 80),
			LegsColor = rgb(190, 110, 60),
			Accent = { Color = rgb(60, 170, 255), Pattern = "Buttons" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "MadScientistLab_MadProfessor",
		Name = "Mad Professor",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(255, 220, 40),
			ArmsColor = rgb(60, 170, 255),
			LegsColor = rgb(150, 80, 220),
			Accent = { Color = rgb(30, 30, 35), Pattern = { "Patches", "Cape" } },
			Head = "MadHair",
			HeadColor = rgb(60, 170, 255),
			HeadColor2 = rgb(150, 80, 220),
			GlowColor = rgb(235, 240, 245),
		},
	},
	{
		Id = "MadScientistLab_Frankenfriend",
		Name = "Frankenfriend",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(235, 240, 245),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(255, 220, 40),
			Accent = {
				Color = rgb(190, 110, 60),
				Material = M.Neon,
				Pattern = { "Wings", "Collar" },
			},
			Head = "FrankenHead",
			HeadColor = rgb(190, 110, 60),
			HeadColor2 = rgb(235, 240, 245),
			GlowColor = rgb(60, 170, 255),
		},
	},
	{
		Id = "MadScientistLab_PotionMixer",
		Name = "Potion Mixer",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(120, 255, 80),
			Accent = { Color = rgb(150, 80, 220), Pattern = { "Heart", "Belly" } },
			Head = "PotionHead",
			HeadColor = rgb(255, 220, 40),
			HeadColor2 = rgb(60, 170, 255),
			GlowColor = rgb(190, 110, 60),
		},
	},
	{
		Id = "MadScientistLab_LightningBrain",
		Name = "Lightning Brain",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(60, 170, 255),
			ArmsColor = rgb(150, 80, 220),
			LegsColor = rgb(120, 255, 80),
			Accent = { Color = rgb(255, 220, 40), Pattern = { "Collar", "Wings" } },
			Head = "MadHair",
			HeadColor = rgb(120, 255, 80),
			HeadColor2 = rgb(190, 110, 60),
			GlowColor = rgb(255, 220, 40),
		},
	},
	{
		Id = "MadScientistLab_BubblingGenius",
		Name = "Bubbling Genius",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(255, 220, 40),
			LegsColor = rgb(60, 170, 255),
			Accent = { Color = rgb(235, 240, 245), Pattern = { "Boots", "Cuffs" } },
			Head = "FrankenHead",
			HeadColor = rgb(30, 30, 35),
			HeadColor2 = rgb(255, 220, 40),
			GlowColor = rgb(120, 255, 80),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "MadScientistLab_DoctorVolt",
		Name = "Doctor Volt",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(255, 220, 40),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(235, 240, 245),
			Accent = { Color = rgb(30, 30, 35), Pattern = { "Sash", "Gloves" } },
			Head = "MadHair",
			HeadColor = rgb(150, 80, 220),
			HeadColor2 = rgb(235, 240, 245),
			GlowColor = rgb(190, 110, 60),
			Glow = { Color = rgb(190, 110, 60), Brightness = 1.6 },
			Aura = { Kind = "Bubbles", Color = rgb(190, 110, 60), Color2 = rgb(120, 255, 80) },
		},
	},
	{
		Id = "MadScientistLab_ToxicTitan",
		Name = "Toxic Titan",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(235, 240, 245),
			ArmsColor = rgb(190, 110, 60),
			LegsColor = rgb(120, 255, 80),
			Accent = { Color = rgb(190, 110, 60), Pattern = { "Tail", "Bones" } },
			Head = "PotionHead",
			HeadColor = rgb(120, 255, 80),
			HeadColor2 = rgb(30, 30, 35),
			GlowColor = rgb(235, 240, 245),
			Glow = { Color = rgb(235, 240, 245), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(235, 240, 245), Color2 = rgb(190, 110, 60) },
		},
	},
	{
		Id = "MadScientistLab_ExperimentX",
		Name = "Experiment X",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(120, 255, 80),
			ArmsColor = rgb(150, 80, 220),
			LegsColor = rgb(60, 170, 255),
			Accent = { Color = rgb(150, 80, 220), Pattern = { "Star", "Web" } },
			Head = "FrankenHead",
			HeadColor = rgb(190, 110, 60),
			HeadColor2 = rgb(255, 220, 40),
			GlowColor = rgb(30, 30, 35),
			Glow = { Color = rgb(30, 30, 35), Brightness = 2.0 },
			Aura = { Kind = "Embers", Color = rgb(30, 30, 35), Color2 = rgb(235, 240, 245) },
		},
	},
} :: { any }
